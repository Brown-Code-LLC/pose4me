import Foundation

enum ExerciseCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case neck = "Neck"
    case shoulders = "Shoulders"
    case back = "Back & Core"
    case arms = "Arms & Wrists"
    case legs = "Legs & Hips"
    case fullBody = "Full Body"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .neck: "person.bust"
        case .shoulders: "figure.arms.open"
        case .back: "figure.core.training"
        case .arms: "hand.raised"
        case .legs: "figure.walk"
        case .fullBody: "figure.mixed.cardio"
        }
    }
}

enum Difficulty: Int, CaseIterable, Codable, Sendable {
    case gentle = 0, moderate = 1, energizing = 2

    var label: String {
        switch self {
        case .gentle: "Gentle"
        case .moderate: "Moderate"
        case .energizing: "Energizing"
        }
    }
}

/// How a stretch is verified during a session.
enum TrackingMode: String, Codable, Sendable {
    /// Camera + pose estimation confirm the user is holding the pose.
    case camera
    /// Timer only (moves the camera can't reliably see: wrists, calf raises...).
    case timer
}

/// One phase of a stretch: a target pose held for a duration.
struct PoseKeyframe: Identifiable, Sendable, Equatable {
    let id = UUID()
    var spec: PoseSpec
    var holdSeconds: Double
    var cue: String
}

struct Exercise: Identifiable, Sendable {
    let id: String
    var name: String
    var category: ExerciseCategory
    var difficulty: Difficulty
    var seatedFriendly: Bool
    var isPro: Bool
    var tracking: TrackingMode
    var benefit: String
    var instructions: String
    var keyframes: [PoseKeyframe]

    var totalSeconds: Double { keyframes.reduce(0) { $0 + $1.holdSeconds } }

    /// Keyframes with hold times scaled so the whole exercise fits `seconds`.
    func fitted(to seconds: Double) -> [PoseKeyframe] {
        let total = totalSeconds
        guard total > 0 else { return keyframes }
        let scale = seconds / total
        return keyframes.map { kf in
            var out = kf
            out.holdSeconds = max(3, kf.holdSeconds * scale)
            return out
        }
    }
}

// MARK: - Library

extension Exercise {
    /// The built-in stretch library. Every pose is authored as limb angles (PoseSpec);
    /// see PoseSpec for the angle convention (0° down, 180° up, +90° viewer-right).
    static let library: [Exercise] = [
        Exercise(
            id: "overhead-reach",
            name: "Overhead Reach",
            category: .fullBody, difficulty: .gentle, seatedFriendly: true, isPro: false,
            tracking: .camera,
            benefit: "Decompresses the spine and wakes up circulation after long sitting.",
            instructions: "Reach both arms straight overhead, palms up. Grow taller with every exhale.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -172, leftForearm: -176,
                                            rightUpperArm: 172, rightForearm: 176),
                             holdSeconds: 12, cue: "Reach for the ceiling"),
                PoseKeyframe(spec: PoseSpec(spine: 168, head: 168,
                                            leftUpperArm: -160, leftForearm: -164,
                                            rightUpperArm: -178, rightForearm: -178),
                             holdSeconds: 9, cue: "Lean gently to one side"),
                PoseKeyframe(spec: PoseSpec(spine: 192, head: 192,
                                            leftUpperArm: 178, leftForearm: 178,
                                            rightUpperArm: 160, rightForearm: 164),
                             holdSeconds: 9, cue: "Now the other side"),
            ]
        ),
        Exercise(
            id: "neck-side-stretch",
            name: "Neck Side Stretch",
            category: .neck, difficulty: .gentle, seatedFriendly: true, isPro: false,
            tracking: .camera,
            benefit: "Releases tension that builds in the neck from looking at screens.",
            instructions: "Drop one ear toward the shoulder. Keep both shoulders heavy and relaxed.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(head: 148), holdSeconds: 12, cue: "Ear to the right shoulder"),
                PoseKeyframe(spec: PoseSpec(head: 212), holdSeconds: 12, cue: "Ear to the left shoulder"),
            ]
        ),
        Exercise(
            id: "chest-opener",
            name: "T-Pose Chest Opener",
            category: .shoulders, difficulty: .gentle, seatedFriendly: true, isPro: false,
            tracking: .camera,
            benefit: "Counteracts hunched posture and opens the chest for deeper breathing.",
            instructions: "Stretch your arms out wide like a T. Squeeze the shoulder blades together.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -92, leftForearm: -90,
                                            rightUpperArm: 92, rightForearm: 90),
                             holdSeconds: 14, cue: "Arms wide, chest proud"),
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -120, leftForearm: -125,
                                            rightUpperArm: 120, rightForearm: 125),
                             holdSeconds: 10, cue: "Lift arms slightly higher"),
            ]
        ),
        Exercise(
            id: "side-bend",
            name: "Standing Side Bend",
            category: .back, difficulty: .moderate, seatedFriendly: true, isPro: false,
            tracking: .camera,
            benefit: "Stretches the obliques and the often-ignored side body.",
            instructions: "Arms overhead, then arc your whole torso to one side like a crescent moon.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(spine: 158, head: 150,
                                            leftUpperArm: -150, leftForearm: -155,
                                            rightUpperArm: -175, rightForearm: -170),
                             holdSeconds: 11, cue: "Crescent to the right"),
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -172, leftForearm: -176,
                                            rightUpperArm: 172, rightForearm: 176),
                             holdSeconds: 4, cue: "Back through center"),
                PoseKeyframe(spec: PoseSpec(spine: 202, head: 210,
                                            leftUpperArm: 175, leftForearm: 170,
                                            rightUpperArm: 150, rightForearm: 155),
                             holdSeconds: 11, cue: "Crescent to the left"),
            ]
        ),
        Exercise(
            id: "forward-fold",
            name: "Forward Fold",
            category: .back, difficulty: .moderate, seatedFriendly: false, isPro: false,
            tracking: .camera,
            benefit: "Lengthens hamstrings and lower back; flushes fresh blood to the brain.",
            instructions: "Hinge at the hips and let your upper body hang. Soft knees are welcome.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(spine: 135, head: 130,
                                            leftUpperArm: -35, leftForearm: -20,
                                            rightUpperArm: 35, rightForearm: 20),
                             holdSeconds: 8, cue: "Hinge halfway down"),
                PoseKeyframe(spec: PoseSpec(spine: 96, head: 92,
                                            leftUpperArm: -12, leftForearm: -6,
                                            rightUpperArm: 12, rightForearm: 6),
                             holdSeconds: 14, cue: "Hang heavy like a ragdoll"),
            ]
        ),
        Exercise(
            id: "torso-twist",
            name: "Torso Twist",
            category: .back, difficulty: .gentle, seatedFriendly: true, isPro: true,
            tracking: .camera,
            benefit: "Mobilizes the thoracic spine and massages the organs of digestion.",
            instructions: "Hands at shoulder height, rotate your ribcage side to side with control.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -95, leftForearm: -170,
                                            rightUpperArm: 95, rightForearm: 170),
                             holdSeconds: 6, cue: "Goal-post arms"),
                PoseKeyframe(spec: PoseSpec(spine: 172, head: 160,
                                            leftUpperArm: -100, leftForearm: -175,
                                            rightUpperArm: 88, rightForearm: 165),
                             holdSeconds: 9, cue: "Twist right, eyes follow"),
                PoseKeyframe(spec: PoseSpec(spine: 188, head: 200,
                                            leftUpperArm: -88, leftForearm: -165,
                                            rightUpperArm: 100, rightForearm: 175),
                             holdSeconds: 9, cue: "Twist left, eyes follow"),
            ]
        ),
        Exercise(
            id: "arm-circles",
            name: "Arm Circles",
            category: .shoulders, difficulty: .energizing, seatedFriendly: true, isPro: true,
            tracking: .camera,
            benefit: "Lubricates the shoulder joints and spikes circulation fast.",
            instructions: "Sweep both arms through big slow circles. Keep the movement smooth.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -92, leftForearm: -90,
                                            rightUpperArm: 92, rightForearm: 90),
                             holdSeconds: 5, cue: "Arms out wide"),
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -172, leftForearm: -176,
                                            rightUpperArm: 172, rightForearm: 176),
                             holdSeconds: 5, cue: "Sweep up high"),
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -92, leftForearm: -90,
                                            rightUpperArm: 92, rightForearm: 90),
                             holdSeconds: 5, cue: "Back out wide"),
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -14, leftForearm: -10,
                                            rightUpperArm: 14, rightForearm: 10),
                             holdSeconds: 5, cue: "Float all the way down"),
            ]
        ),
        Exercise(
            id: "quad-stretch",
            name: "Standing Quad Stretch",
            category: .legs, difficulty: .moderate, seatedFriendly: false, isPro: true,
            tracking: .camera,
            benefit: "Opens the front of the thigh and hip flexors shortened by sitting.",
            instructions: "Catch one ankle behind you and press the hip forward. Hold something if you wobble.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -20, leftForearm: -15,
                                            rightUpperArm: 40, rightForearm: 130,
                                            rightThigh: 8, rightShin: 175),
                             holdSeconds: 12, cue: "Heel to glute — right leg"),
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -40, leftForearm: -130,
                                            rightUpperArm: 20, rightForearm: 15,
                                            leftThigh: -8, leftShin: -175),
                             holdSeconds: 12, cue: "Switch — left leg"),
            ]
        ),
        Exercise(
            id: "hip-march",
            name: "Standing Hip Openers",
            category: .legs, difficulty: .energizing, seatedFriendly: false, isPro: true,
            tracking: .camera,
            benefit: "Fires up the hip flexors and gets blood moving through the legs.",
            instructions: "March one knee up to hip height at a time. Stand tall between lifts.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(rightThigh: 85, rightShin: 5),
                             holdSeconds: 7, cue: "Right knee up to hip height"),
                PoseKeyframe(spec: PoseSpec(), holdSeconds: 3, cue: "Stand tall"),
                PoseKeyframe(spec: PoseSpec(leftThigh: -85, leftShin: -5),
                             holdSeconds: 7, cue: "Left knee up to hip height"),
            ]
        ),
        Exercise(
            id: "wrist-relief",
            name: "Wrist Flexor Relief",
            category: .arms, difficulty: .gentle, seatedFriendly: true, isPro: true,
            tracking: .timer,
            benefit: "Essential for anyone typing all day — helps prevent RSI.",
            instructions: "Extend one arm, palm up. Gently pull the fingers down and back with the other hand. Switch halfway.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -88, leftForearm: -88,
                                            rightUpperArm: -20, rightForearm: -80),
                             holdSeconds: 15, cue: "Pull fingers back — left arm"),
                PoseKeyframe(spec: PoseSpec(leftUpperArm: 20, leftForearm: 80,
                                            rightUpperArm: 88, rightForearm: 88),
                             holdSeconds: 15, cue: "Switch — right arm"),
            ]
        ),
        Exercise(
            id: "calf-raises",
            name: "Calf Raise Pulses",
            category: .legs, difficulty: .energizing, seatedFriendly: false, isPro: true,
            tracking: .timer,
            benefit: "The calf is your 'second heart' — pulses pump blood back up the legs.",
            instructions: "Rise slowly onto your toes, pause, lower with control. Repeat until the timer ends.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -10, rightUpperArm: 10),
                             holdSeconds: 30, cue: "Slow pulses — up, pause, down"),
            ]
        ),
        Exercise(
            id: "shoulder-rolls",
            name: "Shoulder Rolls",
            category: .shoulders, difficulty: .gentle, seatedFriendly: true, isPro: true,
            tracking: .timer,
            benefit: "Melts the shrug tension that creeps in during deep-focus work.",
            instructions: "Roll the shoulders up, back and down in big slow circles. Reverse halfway.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(), holdSeconds: 15, cue: "Roll backwards, slow and big"),
                PoseKeyframe(spec: PoseSpec(), holdSeconds: 15, cue: "Reverse — roll forwards"),
            ]
        ),
        Exercise(
            id: "cactus-arms",
            name: "Cactus Arms Hold",
            category: .shoulders, difficulty: .gentle, seatedFriendly: true, isPro: false,
            tracking: .camera,
            benefit: "Opens the chest and wakes up the upper back after hunching forward.",
            instructions: "Elbows out at shoulder height, forearms up like a cactus. Squeeze the shoulder blades together.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -95, leftForearm: -178,
                                            rightUpperArm: 95, rightForearm: 178),
                             holdSeconds: 12, cue: "Cactus arms — forearms tall"),
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -105, leftForearm: -170,
                                            rightUpperArm: 105, rightForearm: 170),
                             holdSeconds: 10, cue: "Squeeze the blades, lift an inch"),
            ]
        ),
        Exercise(
            id: "star-reach",
            name: "Star Reach",
            category: .fullBody, difficulty: .energizing, seatedFriendly: false, isPro: false,
            tracking: .camera,
            benefit: "A full-body wake-up: long lines from fingertips to heels boost circulation fast.",
            instructions: "Step wide and stretch into a big X — arms high and wide, legs strong.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -140, leftForearm: -145,
                                            rightUpperArm: 140, rightForearm: 145,
                                            leftThigh: -22, leftShin: -20,
                                            rightThigh: 22, rightShin: 20),
                             holdSeconds: 12, cue: "Make yourself a big X"),
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -172, leftForearm: -176,
                                            rightUpperArm: 172, rightForearm: 176,
                                            leftThigh: -22, leftShin: -20,
                                            rightThigh: 22, rightShin: 20),
                             holdSeconds: 8, cue: "Now reach straight up, legs stay wide"),
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -140, leftForearm: -145,
                                            rightUpperArm: 140, rightForearm: 145,
                                            leftThigh: -22, leftShin: -20,
                                            rightThigh: 22, rightShin: 20),
                             holdSeconds: 8, cue: "Back to the X — breathe wide"),
            ]
        ),
        Exercise(
            id: "triceps-stretch",
            name: "Overhead Triceps Stretch",
            category: .arms, difficulty: .moderate, seatedFriendly: true, isPro: true,
            tracking: .camera,
            benefit: "Lengthens the triceps and lats — relief for arms that type and scroll all day.",
            instructions: "Reach one arm up, drop the hand behind your head, and press the elbow gently with the other hand.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -15, leftForearm: -10,
                                            rightUpperArm: 175, rightForearm: 35),
                             holdSeconds: 12, cue: "Right elbow to the sky, hand behind head"),
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -175, leftForearm: -35,
                                            rightUpperArm: 15, rightForearm: 10),
                             holdSeconds: 12, cue: "Switch — left elbow up"),
            ]
        ),
        Exercise(
            id: "side-lunge",
            name: "Side Lunge Stretch",
            category: .legs, difficulty: .moderate, seatedFriendly: false, isPro: true,
            tracking: .camera,
            benefit: "Opens the inner thighs and hips — the muscles chairs forget exist.",
            instructions: "Step wide, bend into one knee and keep the other leg long. Chest stays proud.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -30, leftForearm: -25,
                                            rightUpperArm: 30, rightForearm: 25,
                                            leftThigh: -38, leftShin: -8,
                                            rightThigh: 32, rightShin: 30),
                             holdSeconds: 12, cue: "Sink into the left side"),
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -30, leftForearm: -25,
                                            rightUpperArm: 30, rightForearm: 25,
                                            leftThigh: -32, leftShin: -30,
                                            rightThigh: 38, rightShin: 8),
                             holdSeconds: 12, cue: "Shift across — sink right"),
            ]
        ),
        Exercise(
            id: "gate-openers",
            name: "Gate Openers",
            category: .legs, difficulty: .energizing, seatedFriendly: false, isPro: true,
            tracking: .camera,
            benefit: "Circles the hip through its full range — instant relief for locked-up hips.",
            instructions: "Lift one knee to hip height, swing it out to the side like opening a gate, then set it down. Alternate.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(rightThigh: 80, rightShin: 10),
                             holdSeconds: 6, cue: "Right knee up"),
                PoseKeyframe(spec: PoseSpec(rightThigh: 128, rightShin: 55),
                             holdSeconds: 6, cue: "Open the gate — knee out wide"),
                PoseKeyframe(spec: PoseSpec(), holdSeconds: 3, cue: "Set it down softly"),
                PoseKeyframe(spec: PoseSpec(leftThigh: -80, leftShin: -10),
                             holdSeconds: 6, cue: "Left knee up"),
                PoseKeyframe(spec: PoseSpec(leftThigh: -128, leftShin: -55),
                             holdSeconds: 6, cue: "Open wide to the left"),
            ]
        ),
        Exercise(
            id: "standing-cat-cow",
            name: "Standing Cat-Cow",
            category: .back, difficulty: .gentle, seatedFriendly: true, isPro: true,
            tracking: .timer,
            benefit: "Waves the spine through flexion and extension, feeding the discs between vertebrae.",
            instructions: "Hands on thighs. Inhale: arch the back and look up. Exhale: round the spine and tuck the chin. Flow with your breath.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(head: 200,
                                            leftUpperArm: -28, leftForearm: -55,
                                            rightUpperArm: 28, rightForearm: 55),
                             holdSeconds: 10, cue: "Inhale — arch and look up"),
                PoseKeyframe(spec: PoseSpec(head: 160,
                                            leftUpperArm: -28, leftForearm: -55,
                                            rightUpperArm: 28, rightForearm: 55),
                             holdSeconds: 10, cue: "Exhale — round and tuck"),
                PoseKeyframe(spec: PoseSpec(leftUpperArm: -28, leftForearm: -55,
                                            rightUpperArm: 28, rightForearm: 55),
                             holdSeconds: 8, cue: "One more slow wave"),
            ]
        ),
        Exercise(
            id: "eagle-arms",
            name: "Eagle Arm Wrap",
            category: .shoulders, difficulty: .moderate, seatedFriendly: true, isPro: true,
            tracking: .timer,
            benefit: "Stretches the deep muscles between the shoulder blades that nothing else reaches.",
            instructions: "Cross one arm under the other, wrap the forearms and lift the elbows to shoulder height. Switch the cross halfway.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(leftUpperArm: 35, leftForearm: -160,
                                            rightUpperArm: -35, rightForearm: 160),
                             holdSeconds: 14, cue: "Wrap and lift the elbows"),
                PoseKeyframe(spec: PoseSpec(leftUpperArm: 30, leftForearm: -155,
                                            rightUpperArm: -30, rightForearm: 155),
                             holdSeconds: 14, cue: "Re-cross the other way"),
            ]
        ),
        Exercise(
            id: "ankle-mobility",
            name: "Ankle & Calf Mobility",
            category: .legs, difficulty: .gentle, seatedFriendly: true, isPro: false,
            tracking: .timer,
            benefit: "Pumps the calf and ankle — the return pumps that push blood back to your heart.",
            instructions: "Slow ankle circles each way, then gentle calf raises. Seated or standing both work.",
            keyframes: [
                PoseKeyframe(spec: PoseSpec(rightThigh: 20, rightShin: 15),
                             holdSeconds: 10, cue: "Circle the right ankle — both directions"),
                PoseKeyframe(spec: PoseSpec(leftThigh: -20, leftShin: -15),
                             holdSeconds: 10, cue: "Circle the left ankle"),
                PoseKeyframe(spec: PoseSpec(), holdSeconds: 10, cue: "Finish with slow calf raises"),
            ]
        ),
    ]

    static func byID(_ id: String) -> Exercise? {
        library.first { $0.id == id }
    }

    static var freeExercises: [Exercise] { library.filter { !$0.isPro } }
}
