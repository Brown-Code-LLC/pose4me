import Foundation
import CoreGraphics

/// The 17 COCO keypoints — the common vocabulary between YOLO26-pose, Apple Vision,
/// the animated guide figure, and the pose matcher.
enum BodyJoint: Int, CaseIterable, Sendable, Codable {
    case nose = 0
    case leftEye, rightEye, leftEar, rightEar
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle

    /// Mirrored counterpart (left <-> right), used to match selfie-mirrored poses.
    var mirrored: BodyJoint {
        switch self {
        case .leftEye: .rightEye
        case .rightEye: .leftEye
        case .leftEar: .rightEar
        case .rightEar: .leftEar
        case .leftShoulder: .rightShoulder
        case .rightShoulder: .leftShoulder
        case .leftElbow: .rightElbow
        case .rightElbow: .leftElbow
        case .leftWrist: .rightWrist
        case .rightWrist: .leftWrist
        case .leftHip: .rightHip
        case .rightHip: .leftHip
        case .leftKnee: .rightKnee
        case .rightKnee: .leftKnee
        case .leftAnkle: .rightAnkle
        case .rightAnkle: .leftAnkle
        case .nose: .nose
        }
    }
}

/// A detected/authored keypoint in normalized view coordinates (origin top-left, 0...1).
struct JointPoint: Sendable, Equatable {
    var x: Double
    var y: Double
    var confidence: Double

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

/// A full-body pose: keypoints keyed by joint.
struct BodyPose: Sendable, Equatable {
    var joints: [BodyJoint: JointPoint]

    subscript(_ joint: BodyJoint) -> JointPoint? { joints[joint] }

    var isEmpty: Bool { joints.isEmpty }

    /// Bones drawn between keypoints (skeleton edges shared by overlay + guide figure).
    static let bones: [(BodyJoint, BodyJoint)] = [
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
    ]

    /// Pose mirrored around the vertical center line.
    func mirrored() -> BodyPose {
        var out: [BodyJoint: JointPoint] = [:]
        for (joint, point) in joints {
            out[joint.mirrored] = JointPoint(x: 1 - point.x, y: point.y, confidence: point.confidence)
        }
        return BodyPose(joints: out)
    }

    /// Midpoint of two joints when both are present.
    func midpoint(_ a: BodyJoint, _ b: BodyJoint) -> CGPoint? {
        guard let pa = joints[a], let pb = joints[b] else { return nil }
        return CGPoint(x: (pa.x + pb.x) / 2, y: (pa.y + pb.y) / 2)
    }
}
