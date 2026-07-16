import Combine
import SwiftUI
import UIKit
import UserNotifications

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
                    .font(.appTitle)
                    .foregroundStyle(Theme.textPrimary)
                Text("Little stretches, big difference.")
                    .font(.appSubheadline)
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
                    .font(.display(16, .bold))
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
                        .stroke(Theme.track, lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: countdownFraction(remaining: remaining))
                        .stroke(Theme.brandGradient,
                                style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: remaining ?? 0)
                    VStack(spacing: 4) {
                        if let remaining, remaining > 0 {
                            Text(timeString(remaining))
                                .font(.display(34, .bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textPrimary)
                            Text("until next stretch")
                                .font(.appCaption)
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            Text(settings.data.remindersEnabled ? "—" : "Off")
                                .font(.display(34, .bold))
                                .foregroundStyle(Theme.textPrimary)
                            // With overnight windows supported, a missing countdown
                            // means either paused reminders or no active days left on.
                            Text(settings.data.remindersEnabled
                                 ? "no active days selected" : "reminders paused")
                                .font(.appCaption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .frame(width: 210, height: 210)
            }

            if settings.data.remindersEnabled && !scheduler.authorizationGranted {
                Button {
                    Task {
                        if scheduler.authorizationStatus == .notDetermined {
                            // Never asked yet: show the system permission prompt here.
                            await scheduler.requestAuthorization()
                            await scheduler.reschedule(settings: settings.data)
                        } else if let url = URL(string: UIApplication.openSettingsURLString) {
                            // Previously denied: iOS only allows changing it in Settings.
                            await UIApplication.shared.open(url)
                        }
                    }
                } label: {
                    Label(scheduler.authorizationStatus == .notDetermined
                          ? "Tap to turn on notifications so we can ping you when it's time."
                          : "Notifications are off — the countdown works, but you won't get pinged. Tap to open iOS Settings.",
                          systemImage: "bell.slash.fill")
                        .font(.appCaption)
                        .foregroundStyle(Theme.warning)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(.plain)
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
                        .font(.body(12, .semibold))
                        .foregroundStyle(Theme.accent)
                    Text(exercise.name)
                        .font(.appHeadline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(exercise.benefit)
                        .font(.appCaption)
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
                      symbol: "clock.fill", color: Theme.accent)
            Divider().background(Theme.cardStroke).padding(.vertical, 6)
            todayStat(value: "\(settings.data.reminderIntervalMinutes)m", label: "interval",
                      symbol: "bell.fill", color: Theme.mintSoft)
        }
        .card(padding: 14)
    }

    private func todayStat(value: String, label: String, symbol: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.appSubheadline)
                .foregroundStyle(color)
            Text(value)
                .font(.appTitle3)
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.appCaption2)
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
