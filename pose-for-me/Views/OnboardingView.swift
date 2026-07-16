import Combine
import SwiftUI

/// Three-step onboarding: pitch -> pick a rhythm -> grant permissions.
struct OnboardingView: View {
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var scheduler: ReminderScheduler

    @State private var page = 0
    @State private var demoPoseIndex = 0

    private static let demoSpecs: [PoseSpec] = [
        PoseSpec(),
        PoseSpec(leftUpperArm: -172, leftForearm: -176, rightUpperArm: 172, rightForearm: 176),
        PoseSpec(leftUpperArm: -92, leftForearm: -90, rightUpperArm: 92, rightForearm: 90),
        PoseSpec(spine: 160, head: 152, leftUpperArm: -150, leftForearm: -155,
                 rightUpperArm: -175, rightForearm: -170),
    ]

    var body: some View {
        ZStack {
            AppBackground()
            VStack {
                TabView(selection: $page) {
                    pitchPage.tag(0)
                    rhythmPage.tag(1)
                    permissionsPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page dots + CTA
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Theme.aurora1 : Color.white.opacity(0.25))
                            .frame(width: i == page ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: page)
                    }
                }
                .padding(.bottom, 14)

                Button(page < 2 ? "Continue" : "Let's stretch") {
                    if page < 2 {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { page += 1 }
                    } else {
                        finish()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            // Cycle the hero figure through demo poses.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.4))
                withAnimation { demoPoseIndex = (demoPoseIndex + 1) % Self.demoSpecs.count }
            }
        }
    }

    private var pitchPage: some View {
        VStack(spacing: 20) {
            Spacer()
            GuideFigureView(spec: Self.demoSpecs[demoPoseIndex])
                .frame(width: 190, height: 250)

            Text("Pose4Me")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(Theme.auroraGradient)

            Text("Sitting is the new smoking.\nWe'll interrupt it — one 60-second stretch at a time.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Spacer()
        }
    }

    private var rhythmPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "bell.and.waves.left.and.right.fill")
                .font(.system(size: 60))
                .foregroundStyle(Theme.auroraGradient)

            Text("Pick your rhythm")
                .font(.title.bold())
                .foregroundStyle(Theme.textPrimary)

            Text("How often should we get you moving?\nYou can fine-tune everything later.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                rhythmOption(minutes: 60, title: "Every hour", detail: "Recommended — matches your body's need to move")
                rhythmOption(minutes: 120, title: "Every 2 hours", detail: "A lighter cadence for busy days")
                rhythmOption(minutes: 45, title: "Every 45 minutes", detail: "Maximum circulation, deep-work friendly")
            }
            .padding(.horizontal, 28)
            Spacer()
        }
    }

    private func rhythmOption(minutes: Int, title: String, detail: String) -> some View {
        let isOn = settings.data.reminderIntervalMinutes == minutes
        return Button {
            settings.data.reminderIntervalMinutes = minutes
            Haptics.tap()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Theme.aurora1 : Theme.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isOn ? AnyShapeStyle(Theme.auroraGradient)
                                               : AnyShapeStyle(Theme.cardStroke),
                                          lineWidth: isOn ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var permissionsPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(Theme.auroraGradient)

            Text("Your camera is your coach")
                .font(.title.bold())
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 14) {
                permissionRow("bell.fill", "Notifications",
                              "So we can tap you on the shoulder when it's time")
                permissionRow("camera.fill", "Camera",
                              "Pose tracking runs 100% on-device. No video ever leaves your phone.")
            }
            .card(padding: 18)
            .padding(.horizontal, 28)
            Spacer()
        }
    }

    private func permissionRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.aurora2)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func finish() {
        Task {
            await scheduler.requestAuthorization()
            await scheduler.reschedule(settings: settings.data)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                settings.data.hasOnboarded = true
            }
        }
    }
}
