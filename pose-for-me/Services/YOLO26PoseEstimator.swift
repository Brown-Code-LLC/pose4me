import Foundation
import CoreML
import Vision
import CoreVideo

/// Pose estimation via an Ultralytics YOLO26-pose model exported to CoreML.
///
/// The model is not committed to the repo (weights are large). Export it with
/// `tools/export_yolo26_pose.py`, then drop `yolo26n-pose.mlpackage` into the app
/// folder in Xcode — this class finds the compiled model at launch and the factory
/// prefers it over the Vision fallback automatically.
///
/// Decoding supports the standard Ultralytics pose head layout: a float tensor of
/// shape (1, 56, N) — or its (1, N, 56) transpose — where each of the N candidates is
/// [cx, cy, w, h, conf, (x, y, conf) x 17 keypoints] in 640x640 letterboxed pixels.
/// YOLO26's end-to-end NMS-free export emits already-filtered candidates; taking the
/// highest-confidence one is all a single-user stretch session needs.
nonisolated final class YOLO26PoseEstimator: PoseEstimator {
    let backendName: String

    private let vnModel: VNCoreMLModel
    private let inputSide: Double = 640
    private let confidenceThreshold: Float = 0.35

    init?() {
        let candidates = ["yolo26n-pose", "yolo26s-pose", "yolo11n-pose", "yolov8n-pose"]
        var found: (MLModel, String)?
        for name in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc"),
               let model = try? MLModel(contentsOf: url) {
                found = (model, name)
                break
            }
        }
        guard let (model, name) = found, let vn = try? VNCoreMLModel(for: model) else {
            return nil
        }
        vnModel = vn
        backendName = name.hasPrefix("yolo26") ? "YOLO26-pose (CoreML)" : "\(name) (CoreML)"
    }

    func estimatePose(in pixelBuffer: CVPixelBuffer) -> BodyPose? {
        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .scaleFill
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let output = request.results?
            .compactMap({ $0 as? VNCoreMLFeatureValueObservation })
            .compactMap({ $0.featureValue.multiArrayValue })
            .first(where: { $0.count > 56 }) else { return nil }
        return decode(output)
    }

    private func decode(_ array: MLMultiArray) -> BodyPose? {
        let shape = array.shape.map(\.intValue)
        // Normalize to (channels: 56, anchors: N) regardless of layout.
        var channels = 0, anchors = 0, channelStride = 0, anchorStride = 0
        let dims = shape.filter { $0 > 1 }
        guard dims.count == 2 else { return nil }
        let strides = array.strides.map(\.intValue)
        let nonUnitAxes = shape.indices.filter { shape[$0] > 1 }
        let (a, b) = (nonUnitAxes[0], nonUnitAxes[1])
        if shape[a] == 56 || (shape[a] < shape[b] && shape[b] != 56) {
            channels = shape[a]; anchors = shape[b]
            channelStride = strides[a]; anchorStride = strides[b]
        } else {
            channels = shape[b]; anchors = shape[a]
            channelStride = strides[b]; anchorStride = strides[a]
        }
        guard channels >= 56, anchors > 0 else { return nil }

        let ptr = array.dataPointer.assumingMemoryBound(to: Float.self)
        @inline(__always) func value(_ channel: Int, _ anchor: Int) -> Float {
            ptr[channel * channelStride + anchor * anchorStride]
        }

        // Highest-confidence candidate (channel 4 = objectness/person confidence).
        var bestAnchor = -1
        var bestConf: Float = confidenceThreshold
        for i in 0..<anchors {
            let conf = value(4, i)
            if conf > bestConf {
                bestConf = conf
                bestAnchor = i
            }
        }
        guard bestAnchor >= 0 else { return nil }

        var joints: [BodyJoint: JointPoint] = [:]
        for joint in BodyJoint.allCases {
            let base = 5 + joint.rawValue * 3
            let kx = Double(value(base, bestAnchor)) / inputSide
            let ky = Double(value(base + 1, bestAnchor)) / inputSide
            let kc = Double(value(base + 2, bestAnchor))
            guard kc > 0.25, kx >= 0, kx <= 1, ky >= 0, ky <= 1 else { continue }
            joints[joint] = JointPoint(x: kx, y: ky, confidence: kc)
        }
        guard joints.count >= 4 else { return nil }
        return BodyPose(joints: joints)
    }
}
