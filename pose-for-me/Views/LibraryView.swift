import Combine
import SwiftUI

/// Browsable stretch library with category filters and Pro locks.
struct LibraryView: View {
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var entitlements: Entitlements

    @Binding var activeExercise: Exercise?
    @Binding var showPaywall: Bool

    @State private var selectedCategory: ExerciseCategory?

    private var exercises: [Exercise] {
        Exercise.library.filter { ex in
            selectedCategory == nil || ex.category == selectedCategory
        }
    }

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Overline("\(exercises.count) stretches")
                    Text("Library")
                        .font(.appLargeTitle)
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(.top, 12)

                categoryChips

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(exercises) { exercise in
                        exerciseCard(exercise)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(label: "All", isOn: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(ExerciseCategory.allCases) { category in
                    chip(label: category.rawValue,
                         isOn: selectedCategory == category) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
        }
    }

    /// Text-only filter chips: selected = solid teal, unselected = quiet text.
    private func chip(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { action() }
            Haptics.tap()
        } label: {
            Text(label)
                .font(.body(13, isOn ? .semibold : .medium))
                .foregroundStyle(isOn ? .white : Theme.textSecondary)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isOn ? Theme.teal : Color.clear)
                )
        }
    }

    private func exerciseCard(_ exercise: Exercise) -> some View {
        let locked = exercise.isPro && !entitlements.isPro
        return Button {
            if locked {
                showPaywall = true
            } else {
                activeExercise = exercise
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    PoseThumbnail(spec: exercise.keyframes[0].spec)
                        .frame(height: 110)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                        .opacity(locked ? 0.4 : 1)
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.appCaption)
                            .foregroundStyle(Theme.warning)
                            .padding(7)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                Text(exercise.name)
                    .font(.body(15, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(exercise.difficulty.label)
                        .font(.appCaption2)
                        .foregroundStyle(Theme.textSecondary)
                    if exercise.seatedFriendly {
                        Image(systemName: "chair")
                            .font(.appCaption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    if exercise.tracking == .camera {
                        Image(systemName: "camera.viewfinder")
                            .font(.appCaption2)
                            .foregroundStyle(Theme.accent)
                    }
                    Spacer()
                    Text("\(Int(exercise.totalSeconds))s")
                        .font(.appCaption2.monospacedDigit())
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .card(padding: 12)
        }
        .buttonStyle(.plain)
    }
}
