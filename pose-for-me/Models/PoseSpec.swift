import Foundation
import CoreGraphics

/// A compact, human-authorable body pose described by limb angles.
///
/// Angles are in degrees in screen space: 0° points straight down, 180° straight up,
/// 90° toward the viewer's right, -90° toward the viewer's left. A small
/// forward-kinematics builder turns a spec into 17 normalized COCO keypoints, so one
/// literal drives the animated guide figure, the matcher target, and library thumbnails.
struct PoseSpec: Sendable, Equatable {
    var spine: Double = 180        // hips -> shoulder center
    var head: Double = 180         // shoulder center -> nose
    var leftUpperArm: Double = -15  // shoulder -> elbow ("left" = viewer's left)
    var leftForearm: Double = -10   // elbow -> wrist
    var rightUpperArm: Double = 15
    var rightForearm: Double = 10
    var leftThigh: Double = -4      // hip -> knee
    var leftShin: Double = -2       // knee -> ankle
    var rightThigh: Double = 4
    var rightShin: Double = 2

    // Segment lengths as fractions of the normalized canvas.
    private static let spineLength = 0.21
    private static let headLength = 0.10
    private static let shoulderHalfWidth = 0.085
    private static let hipHalfWidth = 0.055
    private static let upperArmLength = 0.13
    private static let forearmLength = 0.12
    private static let thighLength = 0.17
    private static let shinLength = 0.16

    private static func dir(_ degrees: Double) -> CGVector {
        let r = degrees * .pi / 180
        return CGVector(dx: sin(r), dy: cos(r)) // y grows downward in view space
    }

    private static func step(_ from: CGPoint, _ degrees: Double, _ length: Double) -> CGPoint {
        let d = dir(degrees)
        return CGPoint(x: from.x + d.dx * length, y: from.y + d.dy * length)
    }

    /// Builds the 17 keypoints in normalized (0...1) coordinates, standing centered.
    func keypoints() -> BodyPose {
        let hipCenter = CGPoint(x: 0.5, y: 0.58)
        let shoulderCenter = Self.step(hipCenter, spine, Self.spineLength)

        // Perpendicular to the spine so shoulders/hips tilt with side bends.
        let spineDir = Self.dir(spine)
        let perp = CGVector(dx: spineDir.dy, dy: -spineDir.dx)

        func offset(_ p: CGPoint, _ v: CGVector, _ s: Double) -> CGPoint {
            CGPoint(x: p.x + v.dx * s, y: p.y + v.dy * s)
        }

        let leftShoulder = offset(shoulderCenter, perp, -Self.shoulderHalfWidth)
        let rightShoulder = offset(shoulderCenter, perp, Self.shoulderHalfWidth)
        let leftHip = offset(hipCenter, perp, -Self.hipHalfWidth)
        let rightHip = offset(hipCenter, perp, Self.hipHalfWidth)

        let nose = Self.step(shoulderCenter, head, Self.headLength)
        let leftElbow = Self.step(leftShoulder, leftUpperArm, Self.upperArmLength)
        let leftWrist = Self.step(leftElbow, leftForearm, Self.forearmLength)
        let rightElbow = Self.step(rightShoulder, rightUpperArm, Self.upperArmLength)
        let rightWrist = Self.step(rightElbow, rightForearm, Self.forearmLength)
        let leftKnee = Self.step(leftHip, leftThigh, Self.thighLength)
        let leftAnkle = Self.step(leftKnee, leftShin, Self.shinLength)
        let rightKnee = Self.step(rightHip, rightThigh, Self.thighLength)
        let rightAnkle = Self.step(rightKnee, rightShin, Self.shinLength)

        // Eyes/ears hug the nose; they are decorative and carry zero match weight.
        let headDir = Self.dir(head)
        let headPerp = CGVector(dx: headDir.dy, dy: -headDir.dx)
        let leftEye = offset(Self.step(shoulderCenter, head, Self.headLength * 1.05), headPerp, -0.018)
        let rightEye = offset(Self.step(shoulderCenter, head, Self.headLength * 1.05), headPerp, 0.018)
        let leftEar = offset(Self.step(shoulderCenter, head, Self.headLength * 0.9), headPerp, -0.035)
        let rightEar = offset(Self.step(shoulderCenter, head, Self.headLength * 0.9), headPerp, 0.035)

        var joints: [BodyJoint: JointPoint] = [:]
        let all: [(BodyJoint, CGPoint)] = [
            (.nose, nose), (.leftEye, leftEye), (.rightEye, rightEye),
            (.leftEar, leftEar), (.rightEar, rightEar),
            (.leftShoulder, leftShoulder), (.rightShoulder, rightShoulder),
            (.leftElbow, leftElbow), (.rightElbow, rightElbow),
            (.leftWrist, leftWrist), (.rightWrist, rightWrist),
            (.leftHip, leftHip), (.rightHip, rightHip),
            (.leftKnee, leftKnee), (.rightKnee, rightKnee),
            (.leftAnkle, leftAnkle), (.rightAnkle, rightAnkle),
        ]
        for (joint, p) in all {
            joints[joint] = JointPoint(x: p.x, y: p.y, confidence: 1)
        }
        return BodyPose(joints: joints)
    }

    /// Limb angles the matcher scores, with per-limb weights.
    /// (joint pair defining the segment, target angle, weight)
    var matchTargets: [PoseMatchTarget] {
        [
            PoseMatchTarget(from: .leftShoulder, to: .leftElbow, angle: leftUpperArm, weight: 1.0),
            PoseMatchTarget(from: .leftElbow, to: .leftWrist, angle: leftForearm, weight: 0.8),
            PoseMatchTarget(from: .rightShoulder, to: .rightElbow, angle: rightUpperArm, weight: 1.0),
            PoseMatchTarget(from: .rightElbow, to: .rightWrist, angle: rightForearm, weight: 0.8),
            PoseMatchTarget(from: .leftHip, to: .leftKnee, angle: leftThigh, weight: 0.6),
            PoseMatchTarget(from: .leftKnee, to: .leftAnkle, angle: leftShin, weight: 0.5),
            PoseMatchTarget(from: .rightHip, to: .rightKnee, angle: rightThigh, weight: 0.6),
            PoseMatchTarget(from: .rightKnee, to: .rightAnkle, angle: rightShin, weight: 0.5),
        ]
    }
}

/// One limb segment the matcher compares against a detected pose.
struct PoseMatchTarget: Sendable, Equatable {
    var from: BodyJoint
    var to: BodyJoint
    var angle: Double
    var weight: Double
}
