import Combine
import SwiftUI
import UIKit
import UserNotifications

/// Today screen. One hero (the countdown), one action (Stretch now); everything
/// else stays quiet — hairlines and type, not boxes and icons.
struct HomeView: View {
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var scheduler: ReminderScheduler

    @Binding var activeExercise: Exercise?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 12)
                countdownHero
                    .padding(.top, 28)
                notificationsNudge
                stretchNowButton
                    .padding(.top, 24)
                todayStrip
                    .padding(.top, 28)
                upNextRow
                    .padding(.top, 28)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
    }

    // MARK: Header — greeting left, quiet streak right

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Overline(greeting)
                Text("Today")
                    .font(.appLargeTitle)
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            if sessionStore.streakDays > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.appCaption)
                        .foregroundStyle(Theme.ember)
                    Text("\(sessionStore.streakDays) day\(sessionStore.streakDays == 1 ? "" : "s")")
                        .font(.body(13, .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Theme.tintFill, in: Capsule())
            }
        }
    }

    // MARK: Countdown hero — the one big element on the screen

    private var countdownHero: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = scheduler.nextFireDate?.timeIntervalSince(context.date)
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Theme.track, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: countdownFraction(remaining: remaining))
                        .stroke(Theme.accent,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: remaining ?? 0)

                    VStack(spacing: 6) {
                        if let remaining, remaining > 0 {
                            Text(timeString(remaining))
                                .font(.display(44, .bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textPrimary)
                            Overline("Until next stretch")
                        } else {
                            Text(settings.data.remindersEnabled ? "—" : "Off")
                                .font(.display(44, .bold))
                                .foregroundStyle(Theme.textPrimary)
                            Overline(settings.data.remindersEnabled
                                     ? "No active days selected" : "Reminders paused")
                        }
                    }
                }
                .frame(width: 232, height: 232)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var notificationsNudge: some View {
        Group {
            if settings.data.remindersEnabled && !scheduler.authorizationGranted {
                Button {
                    Task {
                        if scheduler.authorizationStatus == .notDetermined {
                            await scheduler.requestAuthorization()
                            await scheduler.reschedule(settings: settings.data)
                        } else if let url = URL(string: UIApplication.openSettingsURLString) {
                            await UIApplication.shared.open(url)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Theme.warning)
                            .frame(width: 6, height: 6)
                        Text(scheduler.authorizationStatus == .notDetermined
                             ? "Turn on notifications to get stretch reminders"
                             : "Notifications are off — open iOS Settings to enable")
                            .font(.appFootnote)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.body(11, .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
        }
    }

    private var stretchNowButton: some View {
        Button {
            activeExercise = settings.suggestedExercise()
        } label: {
            Text("Stretch now")
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityIdentifier("home.stretchNow")
    }

    // MARK: Today — numbers first, separated by hairlines, no icons

    private var todayStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Overline("Today")
            HStack(spacing: 0) {
                todayStat(value: "\(sessionStore.todayCount)", label: "stretches")
                verticalHairline
                todayStat(value: String(format: "%.1f", sessionStore.todayMinutes), label: "minutes")
                verticalHairline
                todayStat(value: intervalDisplay, label: "interval")
            }
        }
    }

    private var verticalHairline: some View {
        Rectangle()
            .fill(Theme.cardStroke)
            .frame(width: 1, height: 34)
    }

    private func todayStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.display(22, .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.appCaption)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Up next — one clean row

    private var upNextRow: some View {
        let exercise = settings.suggestedExercise()
        return VStack(alignment: .leading, spacing: 12) {
            Overline("Up next")
            Button {
                activeExercise = exercise
            } label: {
                HStack(spacing: 16) {
                    PoseThumbnail(spec: exercise.keyframes[0].spec)
                        .frame(width: 44, height: 62)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.name)
                            .font(.appHeadline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(Int(exercise.totalSeconds))s · \(exercise.category.rawValue)")
                            .font(.appFootnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.body(13, .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            .card(padding: 0)
        }
    }

    // MARK: Helpers

    private var intervalDisplay: String {
        let m = settings.data.reminderIntervalMinutes
        return m % 60 == 0 ? "\(m / 60)h" : "\(m)m"
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
