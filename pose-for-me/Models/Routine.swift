import Foundation

/// A short curated sequence of stretches run back-to-back as one break.
/// Each stretch keeps its own session (and its own SessionRecord), so stats
/// and streaks count every stretch in the chain individually.
struct Routine: Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var benefit: String
    var symbol: String
    var exerciseIDs: [String]

    @MainActor
    var exercises: [Exercise] { exerciseIDs.compactMap { Exercise.byID($0) } }

    static func == (lhs: Routine, rhs: Routine) -> Bool { lhs.id == rhs.id }

    static let library: [Routine] = [
        Routine(
            id: "desk-break",
            name: "Desk Break",
            benefit: "The full seated reset — neck to wrists without leaving the chair.",
            symbol: "laptopcomputer",
            exerciseIDs: ["neck-side-stretch", "shoulder-rolls", "cross-body-stretch",
                          "torso-twist", "wrist-relief"]
        ),
        Routine(
            id: "posture-reset",
            name: "Posture Reset",
            benefit: "Undo the hunch: open the chest and wake up the upper back.",
            symbol: "figure.stand",
            exerciseIDs: ["cactus-arms", "standing-cat-cow", "side-bend", "eagle-arms"]
        ),
        Routine(
            id: "energy-boost",
            name: "Energy Boost",
            benefit: "Get the blood moving when the afternoon slump hits.",
            symbol: "bolt.fill",
            exerciseIDs: ["arm-circles", "hip-march", "star-reach", "calf-raises"]
        ),
    ]

    static func byID(_ id: String) -> Routine? {
        library.first { $0.id == id }
    }
}
