import XCTest
@testable import pose_for_me

final class PoseMatcherTests: XCTestCase {

    // MARK: angleDelta

    func testAngleDeltaBasics() {
        XCTAssertEqual(PoseMatcher.angleDelta(0, 0), 0, accuracy: 0.001)
        XCTAssertEqual(PoseMatcher.angleDelta(90, 45), 45, accuracy: 0.001)
        XCTAssertEqual(PoseMatcher.angleDelta(45, 90), 45, accuracy: 0.001)
    }

    func testAngleDeltaWrapsAround() {
        // 179° and -179° are only 2° apart, not 358°.
        XCTAssertEqual(PoseMatcher.angleDelta(179, -179), 2, accuracy: 0.001)
        XCTAssertEqual(PoseMatcher.angleDelta(-170, 170), 20, accuracy: 0.001)
        // Angles authored beyond ±180 (e.g. 190 == -170) must still compare correctly.
        XCTAssertEqual(PoseMatcher.angleDelta(190, -170), 0, accuracy: 0.001)
    }

    // MARK: segmentAngle (0° down, 180° up, +90 viewer-right)

    func testSegmentAngleConvention() {
        let origin = CGPoint(x: 0.5, y: 0.5)
        XCTAssertEqual(PoseMatcher.segmentAngle(from: origin, to: CGPoint(x: 0.5, y: 0.8)), 0, accuracy: 0.001)
        XCTAssertEqual(PoseMatcher.segmentAngle(from: origin, to: CGPoint(x: 0.5, y: 0.2)), 180, accuracy: 0.001)
        XCTAssertEqual(PoseMatcher.segmentAngle(from: origin, to: CGPoint(x: 0.8, y: 0.5)), 90, accuracy: 0.001)
        XCTAssertEqual(PoseMatcher.segmentAngle(from: origin, to: CGPoint(x: 0.2, y: 0.5)), -90, accuracy: 0.001)
    }

    // MARK: matching

    func testPoseBuiltFromSpecMatchesItsOwnSpec() {
        for exercise in Exercise.library where exercise.tracking == .camera {
            for keyframe in exercise.keyframes {
                let pose = keyframe.spec.keypoints()
                let result = PoseMatcher.match(pose: pose, spec: keyframe.spec, strictness: 1.0)
                XCTAssertGreaterThan(result.score, 0.9,
                    "\(exercise.name) keyframe should match its own generated pose")
                XCTAssertTrue(result.passesGate,
                    "\(exercise.name) perfect pose must pass the hold gate")
            }
        }
    }

    func testMirroredPoseStillMatches() {
        let spec = PoseSpec(spine: 160, head: 152,
                            leftUpperArm: -150, leftForearm: -155,
                            rightUpperArm: -175, rightForearm: -170)
        let mirrored = spec.keypoints().mirrored()
        let result = PoseMatcher.match(pose: mirrored, spec: spec, strictness: 0.8)
        XCTAssertGreaterThan(result.score, 0.85, "selfie mirroring must not tank the score")
    }

    func testWrongPoseScoresLow() {
        // Body in neutral stance vs an overhead-reach target.
        let neutral = PoseSpec().keypoints()
        let overhead = PoseSpec(leftUpperArm: -172, leftForearm: -176,
                                rightUpperArm: 172, rightForearm: 176)
        let result = PoseMatcher.match(pose: neutral, spec: overhead, strictness: 0.8)
        XCTAssertLessThan(result.score, 0.55, "arms-down must not pass an arms-up gate")
        XCTAssertFalse(result.passesGate)
    }

    func testStandingStillFailsSubtlePoseGates() {
        // A pose defined by a single limb (neck tilt) must not be passable by
        // standing neutral: the many untargeted limbs can't carry the gate.
        let neutral = PoseSpec().keypoints()
        let neckTilt = PoseSpec(head: 148)
        let result = PoseMatcher.match(pose: neutral, spec: neckTilt, strictness: 0.5)
        XCTAssertFalse(result.passesGate,
                       "neutral stance passed a neck-stretch gate (defining=\(result.definingScore))")

        // And actually tilting the head passes.
        let tilted = PoseMatcher.match(pose: neckTilt.keypoints(), spec: neckTilt, strictness: 0.5)
        XCTAssertTrue(tilted.passesGate)
    }

    func testWorstLimbIdentifiesTheOffendingArm() {
        // Target: both arms up. Pose: left arm up, right arm down.
        var spec = PoseSpec(leftUpperArm: -172, leftForearm: -176,
                            rightUpperArm: 172, rightForearm: 176)
        spec.head = 180
        var wrongSpec = spec
        wrongSpec.rightUpperArm = 15
        wrongSpec.rightForearm = 10
        let pose = wrongSpec.keypoints()
        let result = PoseMatcher.match(pose: pose, spec: spec, strictness: 0.6)
        let armJoints: Set<BodyJoint> = [.leftElbow, .leftWrist, .rightElbow, .rightWrist]
        XCTAssertNotNil(result.worstLimb)
        if let worst = result.worstLimb {
            XCTAssertTrue(armJoints.contains(worst),
                          "worst limb should be an arm joint, got \(worst)")
        }
    }

    func testStrictnessWidensAndNarrowsTolerance() {
        XCTAssertGreaterThan(PoseMatcher.tolerance(forStrictness: 0),
                             PoseMatcher.tolerance(forStrictness: 1))
        // Slightly-off pose should pass relaxed but fail strict.
        let target = PoseSpec(leftUpperArm: -90, rightUpperArm: 90)
        var offBy25 = target
        offBy25.leftUpperArm = -65
        offBy25.rightUpperArm = 65
        let pose = offBy25.keypoints()
        let relaxed = PoseMatcher.match(pose: pose, spec: target, strictness: 0)
        let strict = PoseMatcher.match(pose: pose, spec: target, strictness: 1)
        XCTAssertGreaterThan(relaxed.score, strict.score)
    }
}
