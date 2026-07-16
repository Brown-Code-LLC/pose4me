import Foundation
import Vision
import CoreVideo

/// Pose estimation via Apple's built-in body pose detector.
/// This is the zero-setup fallback backend; the pipeline prefers YOLO26 when its
/// CoreML model is bundled (see YOLO26PoseEstimator).
nonisolated final class VisionPoseEstimator: PoseEstimator {
    let backendName = "Apple Vision"

    private static let jointMap: [(VNHumanBodyPoseObservation.JointName, BodyJoint)] = [
        (.nose, .nose),
        (.leftEye, .leftEye), (.rightEye, .rightEye),
        (.leftEar, .leftEar), (.rightEar, .rightEar),
        (.leftShoulder, .leftShoulder), (.rightShoulder, .rightShoulder),
        (.leftElbow, .leftElbow), (.rightElbow, .rightElbow),
        (.leftWrist, .leftWrist), (.rightWrist, .rightWrist),
        (.leftHip, .leftHip), (.rightHip, .rightHip),
        (.leftKnee, .leftKnee), (.rightKnee, .rightKnee),
        (.leftAnkle, .leftAnkle), (.rightAnkle, .rightAnkle),
    ]

    func estimatePose(in pixelBuffer: CVPixelBuffer) -> BodyPose? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first,
              let points = try? observation.recognizedPoints(.all) else { return nil }

        var joints: [BodyJoint: JointPoint] = [:]
        for (vnName, joint) in Self.jointMap {
            guard let p = points[vnName], p.confidence > 0.25 else { continue }
            // Vision uses a lower-left origin; the app uses top-left.
            joints[joint] = JointPoint(x: p.location.x, y: 1 - p.location.y,
                                       confidence: Double(p.confidence))
        }
        guard joints.count >= 4 else { return nil }
        return BodyPose(joints: joints)
    }
}
