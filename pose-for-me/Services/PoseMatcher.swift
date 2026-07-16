import Foundation
import CoreGraphics

/// Scores how closely a detected pose matches a target keyframe.
///
/// Matching is angle-based, not position-based: each limb segment's screen-space
/// direction is compared against the spec's authored angle, so body size, framing and
/// distance from the camera don't matter. Selfie mirroring is handled by scoring the
/// mirrored pose too and keeping the better result.
enum PoseMatcher {
    struct Result: Sendable, Equatable {
        var score: Double            // 0...1 weighted match quality (all limbs)
        /// Match quality over only the limbs that define this pose (1 when the
        /// pose has no defining limbs). The hold gate requires BOTH scores, so
        /// standing still can't pass on the strength of untargeted limbs.
        var definingScore: Double
        var worstLimb: BodyJoint?    // joint most out of position, for coaching cues
        static let none = Result(score: 0, definingScore: 0, worstLimb: nil)

        /// Whether this frame counts toward the hold.
        var passesGate: Bool { score >= 0.55 && definingScore >= 0.5 }
    }

    /// Angle tolerance in degrees at which a limb contributes zero score.
    /// Strictness 0 -> 75° (very forgiving), 1 -> 32° (form coach).
    static func tolerance(forStrictness strictness: Double) -> Double {
        75 - 43 * min(max(strictness, 0), 1)
    }

    static func match(pose: BodyPose, spec: PoseSpec, strictness: Double) -> Result {
        let direct = score(pose: pose, spec: spec, strictness: strictness)
        let flipped = score(pose: pose.mirrored(), spec: spec, strictness: strictness)
        if direct.passesGate != flipped.passesGate {
            return direct.passesGate ? direct : flipped
        }
        return (direct.definingScore + direct.score) >= (flipped.definingScore + flipped.score)
            ? direct : flipped
    }

    private static func score(pose: BodyPose, spec: PoseSpec, strictness: Double) -> Result {
        let tol = tolerance(forStrictness: strictness)
        var weightedSum = 0.0
        var totalWeight = 0.0
        var definingSum = 0.0
        var definingWeight = 0.0
        var worst: (joint: BodyJoint, error: Double)?

        func accumulate(score limbScore: Double, weight: Double, isDefining: Bool) {
            weightedSum += limbScore * weight
            totalWeight += weight
            if isDefining {
                definingSum += limbScore * weight
                definingWeight += weight
            }
        }

        for target in spec.matchTargets {
            guard let from = pose[target.from], let to = pose[target.to],
                  from.confidence > 0.25, to.confidence > 0.25 else { continue }
            let detected = segmentAngle(from: from.cgPoint, to: to.cgPoint)
            let error = angleDelta(detected, target.angle)
            let limbScore = max(0, 1 - error / tol)
            accumulate(score: limbScore, weight: target.weight, isDefining: target.isDefining)
            if error > (worst?.error ?? 0), limbScore < 0.6 {
                worst = (target.to, error)
            }
        }

        // Spine: hips midpoint -> shoulders midpoint (matters for bends and folds).
        if let hipMid = pose.midpoint(.leftHip, .rightHip),
           let shoulderMid = pose.midpoint(.leftShoulder, .rightShoulder) {
            let detected = segmentAngle(from: hipMid, to: shoulderMid)
            let error = angleDelta(detected, spec.spine)
            let defining = angleDelta(spec.spine, 180) > 12
            let spineWeight = defining ? 2.6 : 1.4
            accumulate(score: max(0, 1 - error / tol), weight: spineWeight, isDefining: defining)
            if error > (worst?.error ?? 0), error > tol * 0.4 {
                worst = (.leftHip, error)
            }
        }

        // Head: shoulders midpoint -> nose (neck stretches).
        if let shoulderMid = pose.midpoint(.leftShoulder, .rightShoulder),
           let nose = pose[.nose], nose.confidence > 0.25 {
            let detected = segmentAngle(from: shoulderMid, to: nose.cgPoint)
            let error = angleDelta(detected, spec.head)
            let defining = angleDelta(spec.head, 180) > 12
            let headWeight = defining ? 2.0 : 0.9
            accumulate(score: max(0, 1 - error / tol), weight: headWeight, isDefining: defining)
            if defining, error > (worst?.error ?? 0), error > tol * 0.4 {
                worst = (.nose, error)
            }
        }

        guard totalWeight > 0 else { return .none }
        return Result(score: weightedSum / totalWeight,
                      definingScore: definingWeight > 0 ? definingSum / definingWeight : 1,
                      worstLimb: worst?.joint)
    }

    /// Angle of the segment in the app's convention: 0° down, 180° up, +90° right.
    static func segmentAngle(from: CGPoint, to: CGPoint) -> Double {
        let dx = to.x - from.x
        let dy = to.y - from.y // y grows downward
        return atan2(dx, dy) * 180 / .pi
    }

    /// Smallest absolute difference between two angles in degrees (0...180).
    static func angleDelta(_ a: Double, _ b: Double) -> Double {
        var d = (a - b).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return abs(d)
    }
}
