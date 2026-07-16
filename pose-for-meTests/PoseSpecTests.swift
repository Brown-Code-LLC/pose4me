import XCTest
@testable import pose_for_me

final class PoseSpecTests: XCTestCase {

    func testKeypointsProducesAll17Joints() {
        let pose = PoseSpec().keypoints()
        XCTAssertEqual(pose.joints.count, BodyJoint.allCases.count)
        for joint in BodyJoint.allCases {
            XCTAssertNotNil(pose[joint], "missing \(joint)")
        }
    }

    func testNeutralStanceIsUprightAndSymmetric() {
        let pose = PoseSpec().keypoints()
        // Head above shoulders above hips above ankles (y grows downward).
        XCTAssertLessThan(pose[.nose]!.y, pose[.leftShoulder]!.y)
        XCTAssertLessThan(pose[.leftShoulder]!.y, pose[.leftHip]!.y)
        XCTAssertLessThan(pose[.leftHip]!.y, pose[.leftAnkle]!.y)
        // Left/right symmetry around x = 0.5.
        XCTAssertEqual(pose[.leftShoulder]!.x, 1 - pose[.rightShoulder]!.x, accuracy: 0.01)
        XCTAssertEqual(pose[.leftHip]!.x, 1 - pose[.rightHip]!.x, accuracy: 0.01)
    }

    func testArmsUpPutsWristsAboveShoulders() {
        let spec = PoseSpec(leftUpperArm: -172, leftForearm: -176,
                            rightUpperArm: 172, rightForearm: 176)
        let pose = spec.keypoints()
        XCTAssertLessThan(pose[.leftWrist]!.y, pose[.leftShoulder]!.y)
        XCTAssertLessThan(pose[.rightWrist]!.y, pose[.rightShoulder]!.y)
    }

    func testForwardFoldPutsShouldersNearHipHeight() {
        let fold = PoseSpec(spine: 96, head: 92,
                            leftUpperArm: -12, leftForearm: -6,
                            rightUpperArm: 12, rightForearm: 6)
        let pose = fold.keypoints()
        let shoulderMid = pose.midpoint(.leftShoulder, .rightShoulder)!
        let hipMid = pose.midpoint(.leftHip, .rightHip)!
        // Bent ~90°: vertical drop between hips and shoulders shrinks dramatically.
        XCTAssertLessThan(abs(hipMid.y - shoulderMid.y), 0.08)
    }

    func testAllKeypointsStayInsideUnitSpace() {
        for exercise in Exercise.library {
            for keyframe in exercise.keyframes {
                for (joint, p) in keyframe.spec.keypoints().joints {
                    XCTAssertTrue((0...1).contains(p.x) && (0...1).contains(p.y),
                        "\(exercise.name)/\(joint) out of bounds: (\(p.x), \(p.y))")
                }
            }
        }
    }

    func testMirroredPoseSwapsSides() {
        let spec = PoseSpec(leftUpperArm: -90, rightUpperArm: 15)
        let pose = spec.keypoints()
        let mirrored = pose.mirrored()
        XCTAssertEqual(mirrored[.rightWrist]!.x, 1 - pose[.leftWrist]!.x, accuracy: 0.001)
        XCTAssertEqual(mirrored[.rightWrist]!.y, pose[.leftWrist]!.y, accuracy: 0.001)
    }
}
