import Combine
import SwiftUI

/// Runs a routine's stretches back-to-back: one SessionView per exercise,
/// recreated via .id() as the index advances. Each stretch records its own
/// session, so stats and streaks count them individually.
struct RoutineSessionView: View {
    @EnvironmentObject private var settings: UserSettings
    let routine: Routine
    @State private var index = 0

    var body: some View {
        // Respect the user's filters; fall back to the full routine so a
        // pathological config can never produce an empty session.
        let pool = settings.eligibleExercises(in: routine)
        let exercises = pool.isEmpty ? routine.exercises : pool
        let clamped = min(index, exercises.count - 1)
        SessionView(exercise: exercises[clamped],
                    settings: settings.data,
                    routinePosition: (clamped + 1, exercises.count),
                    onAdvance: clamped + 1 < exercises.count ? { index += 1 } : nil)
            .id(clamped)
    }
}
