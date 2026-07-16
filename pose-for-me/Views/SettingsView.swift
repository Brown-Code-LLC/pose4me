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
                    .font(.largeTitle.bold())
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
            Task { await scheduler.reschedule(settings: settings.data) }
        }
    }

    // MARK: Reminders

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Reminders", symbol: "bell.badge.fill")

            Toggle(isOn: $settings.data.remindersEnabled) {
                settingLabel("Stretch reminders", detail: "Nudge me to move")
            }
            .tint(Theme.aurora2)

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
                    .tint(Theme.aurora2)
                }

                HStack {
                    settingLabel("Active hours", detail: "No pings outside these")
                    Spacer()
                    Picker("", selection: $settings.data.activeStartHour) {
                        ForEach(0..<24, id: \.self) { Text(hourLabel($0)).tag($0) }
                    }
                    .tint(Theme.aurora1)
                    Text("–").foregroundStyle(Theme.textTertiary)
                    Picker("", selection: $settings.data.activeEndHour) {
                        ForEach(1..<25, id: \.self) { Text(hourLabel($0 % 24)).tag($0 % 24) }
                    }
                    .tint(Theme.aurora1)
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
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(
                                        Circle().fill(isOn ? AnyShapeStyle(Theme.auroraGradient)
                                                           : AnyShapeStyle(Color.white.opacity(0.08)))
                                    )
                                    .foregroundStyle(isOn ? Color.black.opacity(0.8) : Theme.textSecondary)
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
            .tint(Theme.aurora2)

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
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule().fill(isOn ? AnyShapeStyle(Theme.auroraGradient)
                                                        : AnyShapeStyle(Color.white.opacity(0.08)))
                                )
                                .foregroundStyle(isOn ? Color.black.opacity(0.8) : Theme.textSecondary)
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
            .tint(Theme.aurora2)

            if settings.data.cameraTrackingEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    settingLabel("Form strictness: \(strictnessLabel)",
                                 detail: "How precisely you must match the guide")
                    Slider(value: $settings.data.matchStrictness, in: 0...1)
                        .tint(Theme.aurora2)
                }
            }

            HStack {
                settingLabel("Model", detail: "Estimation backend in use")
                Spacer()
                Text(PoseEstimatorFactory.bestBackendName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.aurora1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }
            Text("Drop yolo26n-pose.mlpackage into the project (see tools/export_yolo26_pose.py) to switch from Apple Vision to YOLO26.")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .card()
    }

    // MARK: Feel & About

    private var feelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Feel", symbol: "hand.tap.fill")
            Toggle(isOn: $settings.data.hapticsEnabled) {
                settingLabel("Haptics", detail: nil)
            }
            .tint(Theme.aurora2)
        }
        .card()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Pose4Me Pro", symbol: "sparkles")
            if entitlements.isPro {
                Label("Pro active — thanks for supporting Pose4Me!", systemImage: "checkmark.seal.fill")
                    .font(.subheadline)
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
            .font(.headline)
            .foregroundStyle(Theme.textPrimary)
    }

    private func settingLabel(_ title: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
            if let detail {
                Text(detail)
                    .font(.caption2)
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
        var comps = DateComponents(); comps.hour = hour
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
