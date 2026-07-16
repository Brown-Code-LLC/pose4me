import Combine
import SwiftUI

/// Every key feature is customizable from here — reminders, sessions, tracking, feel.
struct SettingsView: View {
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var scheduler: ReminderScheduler
    @EnvironmentObject private var entitlements: Entitlements
    @Binding var showPaywall: Bool

    private let weekdaySymbols = Calendar.current.veryShortWeekdaySymbols // Sun-first

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.appLargeTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 8)

                remindersCard
                sessionCard
                trackingCard
                feelCard
                aboutCard
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .onChange(of: settings.data) {
            // refresh() rebuilds only when reminder-relevant settings changed;
            // toggling haptics or session length won't reset the countdown.
            Task { await scheduler.refresh(settings: settings.data) }
        }
    }

    // MARK: Reminders

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Reminders", symbol: "bell.badge.fill")

            Toggle(isOn: $settings.data.remindersEnabled) {
                settingLabel("Stretch reminders", detail: "Nudge me to move")
            }
            .tint(Theme.accent)

            if settings.data.remindersEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    settingLabel("Every \(intervalLabel)",
                                 detail: "How often you're reminded")
                    Slider(
                        value: Binding(
                            get: { Double(settings.data.reminderIntervalMinutes) },
                            set: { settings.data.reminderIntervalMinutes = Int($0 / 15) * 15 }
                        ),
                        in: 30...240, step: 15
                    )
                    .tint(Theme.accent)
                }

                VStack(alignment: .leading, spacing: 6) {
                    settingLabel("Active hours",
                                 detail: "Set any window your shift needs — day, overnight, any start minute")
                    HStack(spacing: 10) {
                        DatePicker("", selection: timeBinding(hour: $settings.data.activeStartHour,
                                                              minute: $settings.data.activeStartMinute),
                                   displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Text("to").foregroundStyle(Theme.textTertiary)
                        DatePicker("", selection: timeBinding(hour: $settings.data.activeEndHour,
                                                              minute: $settings.data.activeEndMinute),
                                   displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Spacer()
                    }
                    if settings.data.activeStartMinutesFromMidnight > settings.data.activeEndMinutesFromMidnight {
                        Text("🌙 Overnight window: \(windowTimeLabel(settings.data.activeStartHour, settings.data.activeStartMinute)) through \(windowTimeLabel(settings.data.activeEndHour, settings.data.activeEndMinute)) the next morning — active days refer to the night the shift starts.")
                            .font(.appCaption2)
                            .foregroundStyle(Theme.accent)
                    } else if settings.data.activeStartMinutesFromMidnight == settings.data.activeEndMinutesFromMidnight {
                        Text("Around-the-clock: reminders all day on active days.")
                            .font(.appCaption2)
                            .foregroundStyle(Theme.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    settingLabel("Active days", detail: nil)
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { weekday in
                            let isOn = settings.data.activeWeekdays.contains(weekday)
                            Button {
                                if isOn { settings.data.activeWeekdays.remove(weekday) }
                                else { settings.data.activeWeekdays.insert(weekday) }
                                Haptics.tap()
                            } label: {
                                Text(weekdaySymbols[weekday - 1])
                                    .font(.body(12, .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(
                                        Circle().fill(isOn ? AnyShapeStyle(Theme.brandGradient)
                                                           : AnyShapeStyle(Theme.tintFill))
                                    )
                                    .foregroundStyle(isOn ? .white : Theme.textSecondary)
                            }
                        }
                    }
                }

                Stepper(value: $settings.data.snoozeMinutes, in: 5...60, step: 5) {
                    settingLabel("Snooze: \(settings.data.snoozeMinutes) min", detail: nil)
                }
            }
        }
        .card()
    }

    // MARK: Session

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Stretch sessions", symbol: "figure.flexibility")

            VStack(alignment: .leading, spacing: 8) {
                settingLabel("Session length", detail: "How long each stretch lasts")
                Picker("Session length", selection: $settings.data.sessionSeconds) {
                    Text("30s").tag(30)
                    Text("60s").tag(60)
                    Text("90s").tag(90)
                    Text("2m").tag(120)
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                settingLabel("Movement demo", detail: "Animated preview of the full motion before each stretch, then auto-start")
                Picker("Movement demo", selection: $settings.data.previewSeconds) {
                    Text("Off").tag(0)
                    Text("10s").tag(10)
                    Text("15s").tag(15)
                    Text("30s").tag(30)
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                settingLabel("Max difficulty", detail: nil)
                Picker("Max difficulty", selection: $settings.data.maxDifficulty) {
                    ForEach(Difficulty.allCases, id: \.rawValue) { d in
                        Text(d.label).tag(d.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Toggle(isOn: $settings.data.seatedFriendlyOnly) {
                settingLabel("Seated-friendly only", detail: "Great for desk setups")
            }
            .tint(Theme.accent)

            VStack(alignment: .leading, spacing: 8) {
                settingLabel("Categories", detail: "Which stretches get suggested")
                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(ExerciseCategory.allCases) { category in
                        let isOn = settings.data.enabledCategories.contains(category.rawValue)
                        Button {
                            if isOn { settings.data.enabledCategories.remove(category.rawValue) }
                            else { settings.data.enabledCategories.insert(category.rawValue) }
                            Haptics.tap()
                        } label: {
                            Label(category.rawValue, systemImage: category.symbol)
                                .font(.body(12, .medium))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule().fill(isOn ? AnyShapeStyle(Theme.brandGradient)
                                                        : AnyShapeStyle(Theme.tintFill))
                                )
                                .foregroundStyle(isOn ? .white : Theme.textSecondary)
                        }
                    }
                }
            }
        }
        .card()
    }

    // MARK: Tracking

    private var trackingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Pose tracking", symbol: "camera.viewfinder")

            Toggle(isOn: $settings.data.cameraTrackingEnabled) {
                settingLabel("Camera tracking",
                             detail: "Front camera verifies your pose. All on-device.")
            }
            .tint(Theme.accent)

            if settings.data.cameraTrackingEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    settingLabel("Form strictness: \(strictnessLabel)",
                                 detail: "How precisely you must match the guide")
                    Slider(value: $settings.data.matchStrictness, in: 0...1)
                        .tint(Theme.accent)
                }
            }

            HStack {
                settingLabel("Model", detail: "Estimation backend in use")
                Spacer()
                Text(PoseEstimatorFactory.bestBackendName)
                    .font(.body(12, .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.tintFill, in: Capsule())
            }
            Text("Drop yolo26n-pose.mlpackage into the project (see tools/export_yolo26_pose.py) to switch from Apple Vision to YOLO26.")
                .font(.appCaption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .card()
    }

    // MARK: Feel & About

    private var feelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Feel", symbol: "hand.tap.fill")

            VStack(alignment: .leading, spacing: 8) {
                settingLabel("Appearance", detail: "Light and dark themes, or follow iOS")
                Picker("Appearance", selection: $settings.data.appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Toggle(isOn: $settings.data.hapticsEnabled) {
                settingLabel("Haptics", detail: nil)
            }
            .tint(Theme.accent)
        }
        .card()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Pose4Me Pro", symbol: "sparkles")
            if entitlements.isPro {
                Label("Pro active — thanks for supporting Pose4Me!", systemImage: "checkmark.seal.fill")
                    .font(.appSubheadline)
                    .foregroundStyle(Theme.success)
            } else {
                Button("Upgrade to Pro") { showPaywall = true }
                    .buttonStyle(PrimaryButtonStyle())
            }
            #if DEBUG
            Toggle(isOn: Binding(
                get: { entitlements.isPro },
                set: { entitlements.setDevUnlock($0) }
            )) {
                settingLabel("Developer unlock (DEBUG only)", detail: nil)
            }
            .tint(Theme.warning)
            #endif
        }
        .card()
    }

    // MARK: Helpers

    private func sectionHeader(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.appHeadline)
            .foregroundStyle(Theme.textPrimary)
    }

    private func settingLabel(_ title: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.body(15, .medium))
                .foregroundStyle(Theme.textPrimary)
            if let detail {
                Text(detail)
                    .font(.appCaption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var intervalLabel: String {
        let m = settings.data.reminderIntervalMinutes
        if m % 60 == 0 { return m == 60 ? "hour" : "\(m / 60) hours" }
        return "\(m) min"
    }

    private var strictnessLabel: String {
        switch settings.data.matchStrictness {
        case ..<0.34: "Relaxed"
        case ..<0.67: "Balanced"
        default: "Coach"
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        windowTimeLabel(hour, 0)
    }

    private func windowTimeLabel(_ hour: Int, _ minute: Int) -> String {
        var comps = DateComponents(); comps.hour = hour; comps.minute = minute
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// Bridges an hour+minute pair to the Date a DatePicker needs.
    private func timeBinding(hour: Binding<Int>, minute: Binding<Int>) -> Binding<Date> {
        Binding<Date>(
            get: {
                var comps = DateComponents()
                comps.hour = hour.wrappedValue
                comps.minute = minute.wrappedValue
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { date in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                hour.wrappedValue = comps.hour ?? 0
                minute.wrappedValue = comps.minute ?? 0
            }
        )
    }
}
