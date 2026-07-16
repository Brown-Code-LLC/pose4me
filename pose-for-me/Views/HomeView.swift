import Combine
import SwiftUI

/// Today screen: countdown to the next reminder, streak, and a one-tap stretch.
struct HomeView: View {
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var scheduler: ReminderScheduler
    @EnvironmentObject private var entitlements: Entitlements

    @Binding var activeExercise: Exercise?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                countdownCard
                suggestionCard
                todayCard
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.title.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text("Little stretches, big difference.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            // Streak flame
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(sessionStore.streakDays > 0 ? Theme.ember : Theme.textTertiary)
                    .symbolEffect(.pulse, isActive: sessionStore.streakDays > 0)
                Text("\(sessionStore.streakDays)")
                    .font(.headline.bold())
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.top, 8)
    }

    private var countdownCard: some View {
        VStack(spacing: 14) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = scheduler.nextFireDate?.timeIntervalSince(context.date)
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: countdownFraction(remaining: remaining))
                        .stroke(Theme.auroraGradient,
                                style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: remaining ?? 0)
                    VStack(spacing: 4) {
                        if let remaining, remaining > 0 {
                            Text(timeString(remaining))
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textPrimary)
                            Text("until next stretch")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            Text(settings.data.remindersEnabled ? "—" : "Off")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textPrimary)
                            Text(settings.data.remindersEnabled
                                 ? "outside active hours" : "reminders paused")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .frame(width: 210, height: 210)
            }

            Button {
                activeExercise = settings.suggestedExercise(isPro: entitlements.isPro)
            } label: {
                Label("Stretch now", systemImage: "figure.flexibility")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .card(padding: 24)
    }

    private var suggestionCard: some View {
        let exercise = settings.suggestedExercise(isPro: entitlements.isPro)
        return Button {
            activeExercise = exercise
        } label: {
            HStack(spacing: 16) {
                PoseThumbnail(spec: exercise.keyframes[0].spec)
                    .frame(width: 56, height: 76)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Up next for you")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.aurora1)
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(exercise.benefit)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .card()
    }

    private var todayCard: some View {
        HStack(spacing: 0) {
            todayStat(value: "\(sessionStore.todayCount)", label: "stretches",
                      symbol: "checkmark.circle.fill", color: Theme.success)
            Divider().background(Theme.cardStroke).padding(.vertical, 6)
            todayStat(value: String(format: "%.1f", sessionStore.todayMinutes), label: "minutes",
                      symbol: "clock.fill", color: Theme.aurora2)
            Divider().background(Theme.cardStroke).padding(.vertical, 6)
            todayStat(value: "\(settings.data.reminderIntervalMinutes)m", label: "interval",
                      symbol: "bell.fill", color: Theme.aurora3)
        }
        .card(padding: 14)
    }

    private func todayStat(value: String, label: String, symbol: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }

    private func countdownFraction(remaining: TimeInterval?) -> CGFloat {
        guard let remaining, remaining > 0 else { return 0 }
        let interval = TimeInterval(settings.data.reminderIntervalMinutes * 60)
        return CGFloat(max(0, min(1, remaining / interval)))
    }

    private func timeString(_ t: TimeInterval) -> String {
        let total = Int(t)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%02d:%02d", m, s)
    }
}
