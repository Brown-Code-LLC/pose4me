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
            VStack(alignment: .leading, spacing: 16) {
                Text("Library")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 8)

                categoryChips

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(exercises) { exercise in
                        exerciseCard(exercise)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "All", symbol: "square.grid.2x2", isOn: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(ExerciseCategory.allCases) { category in
                    chip(label: category.rawValue, symbol: category.symbol,
                         isOn: selectedCategory == category) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
        }
    }

    private func chip(label: String, symbol: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { action() }
            Haptics.tap()
        } label: {
            Label(label, systemImage: symbol)
                .font(.footnote.weight(.medium))
                .foregroundStyle(isOn ? Color.black.opacity(0.8) : Theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(isOn ? AnyShapeStyle(Theme.auroraGradient)
                                        : AnyShapeStyle(Theme.card))
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
                            .font(.caption)
                            .foregroundStyle(Theme.warning)
                            .padding(7)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(exercise.difficulty.label)
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                    if exercise.seatedFriendly {
                        Image(systemName: "chair")
                            .font(.caption2)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    if exercise.tracking == .camera {
                        Image(systemName: "camera.viewfinder")
                            .font(.caption2)
                            .foregroundStyle(Theme.aurora1)
                    }
                    Spacer()
                    Text("\(Int(exercise.totalSeconds))s")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .card(padding: 12)
        }
        .buttonStyle(.plain)
    }
}
