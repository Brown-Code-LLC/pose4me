import Combine
import SwiftUI

/// Drives one stretch session: countdown -> per-keyframe tracking -> summary.
@MainActor
final class SessionViewModel: ObservableObject {
    enum Stage: Equatable {
        case intro
        case countdown(Int)
        case active
        case done
    }

    let exercise: Exercise
    let keyframes: [PoseKeyframe]
    let usesCamera: Bool
    let strictness: Double
    /// Length of the animated movement demo on the intro screen (0 = off).
    let previewSeconds: Int

    @Published var stage: Stage = .intro
    @Published var keyframeIndex = 0
    @Published var holdProgress: Double = 0
    @Published var matchResult: PoseMatcher.Result = .none
    @Published var displayedPose: BodyPose?

    /// Latest pose from the camera pipeline (fed by SessionView's onReceive).
    var latestCameraPose: BodyPose?

    private var scoreSamples: [Double] = []
    private var startedAt: Date?
    private var ticker: Task<Void, Never>?
    private var demoPhase: Double = 0

    var currentKeyframe: PoseKeyframe { keyframes[keyframeIndex] }

    /// Where the "Copy me" coach starts its looping demonstration: the pose the user
    /// is coming from (previous keyframe), or a neutral stance for the first one.
    var copyMeStartSpec: PoseSpec {
        keyframeIndex == 0 ? PoseSpec() : keyframes[keyframeIndex - 1].spec
    }
    var totalDuration: Double { keyframes.reduce(0) { $0 + $1.holdSeconds } }
    var averageScore: Double? {
        guard usesCamera, !scoreSamples.isEmpty else { return nil }
        return scoreSamples.reduce(0, +) / Double(scoreSamples.count)
    }

    /// True when running in the simulator: no camera exists, so a synthetic body is
    /// animated to demo the full tracking experience.
    var isDemoMode: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    init(exercise: Exercise, settings: SettingsData, cameraAvailable: Bool) {
        self.exercise = exercise
        self.keyframes = exercise.fitted(to: Double(settings.sessionSeconds))
        self.usesCamera = exercise.tracking == .camera
            && settings.cameraTrackingEnabled
            && cameraAvailable
        self.strictness = settings.matchStrictness
        self.previewSeconds = settings.previewSeconds
    }

    func begin() {
        stage = .countdown(3)
        Task { [weak self] in
            for n in [2, 1] {
                try? await Task.sleep(for: .seconds(1))
                guard let self, case .countdown = self.stage else { return }
                self.stage = .countdown(n)
                Haptics.tap()
            }
            try? await Task.sleep(for: .seconds(1))
            guard let self, case .countdown = self.stage else { return }
            self.startActive()
        }
    }

    private func startActive() {
        stage = .active
        startedAt = Date()
        Haptics.milestone()
        ticker = Task { [weak self] in
            let dt = 0.1
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(dt))
                guard let self, self.stage == .active else { return }
                self.tick(dt: dt)
            }
        }
    }

    /// Advance the session clock. The pose comes from the camera pipeline; in demo
    /// mode a synthetic body wobbles around the target so the overlay comes alive.
    func tick(dt: Double) {
        guard stage == .active else { return }

        var pose = latestCameraPose
        if isDemoMode && usesCamera {
            demoPhase += dt
            pose = demoPose()
        }
        if let pose { displayedPose = pose }

        var gate = true
        if usesCamera {
            if let pose {
                let result = PoseMatcher.match(pose: pose, spec: currentKeyframe.spec,
                                               strictness: strictness)
                matchResult = result
                scoreSamples.append(result.score)
                gate = result.score >= 0.55
            } else {
                matchResult = .none
                gate = false
            }
        }

        if gate {
            holdProgress += dt / currentKeyframe.holdSeconds
        }

        if holdProgress >= 1 {
            advance()
        }
    }

    private func advance() {
        if keyframeIndex + 1 < keyframes.count {
            keyframeIndex += 1
            holdProgress = 0
            Haptics.success()
        } else {
            holdProgress = 1
            stage = .done
            ticker?.cancel()
            Haptics.milestone()
        }
    }

    func makeRecord() -> SessionRecord {
        SessionRecord(exerciseID: exercise.id,
                      date: startedAt ?? Date(),
                      durationSeconds: Date().timeIntervalSince(startedAt ?? Date()),
                      averageMatchScore: averageScore)
    }

    func cancel() {
        ticker?.cancel()
    }

    /// Synthetic body for simulator demos: target pose + smooth noise.
    private func demoPose() -> BodyPose {
        var joints: [BodyJoint: JointPoint] = [:]
        let base = currentKeyframe.spec.keypoints()
        for (joint, p) in base.joints {
            let wobble = 0.008 * sin(demoPhase * 2.1 + Double(joint.rawValue))
            joints[joint] = JointPoint(x: p.x + wobble, y: p.y + wobble * 0.7, confidence: 0.95)
        }
        return BodyPose(joints: joints)
    }

    /// Human coaching cue for the limb that is most out of position.
    var coachingCue: String? {
        guard usesCamera, stage == .active else { return nil }
        if matchResult.score >= 0.55 { return nil }
        switch matchResult.worstLimb {
        case .leftElbow, .leftWrist: return "Adjust your left arm"
        case .rightElbow, .rightWrist: return "Adjust your right arm"
        case .leftKnee, .leftAnkle: return "Adjust your left leg"
        case .rightKnee, .rightAnkle: return "Adjust your right leg"
        case .leftHip, .rightHip: return "Bend from the waist like the guide"
        case .nose: return "Tilt your head like the guide"
        default: return "Match the glowing figure"
        }
    }
}

/// Full-screen stretch session: camera + skeleton overlay + animated guide.
struct SessionView: View {
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var scheduler: ReminderScheduler
    @Environment(\.dismiss) private var dismiss

    @StateObject private var model: SessionViewModel
    @StateObject private var camera = CameraManager()
    @Environment(\.colorScheme) private var systemScheme
    /// Anchor for the intro demo's auto-start countdown.
    @State private var introStartedAt = Date()

    init(exercise: Exercise, settings: SettingsData) {
        _model = StateObject(wrappedValue: SessionViewModel(
            exercise: exercise,
            settings: settings,
            cameraAvailable: true))
    }

    var body: some View {
        ZStack {
            AppBackground()

            if model.usesCamera && !model.isDemoMode {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
                Color.black.opacity(0.25).ignoresSafeArea()
            }

            switch model.stage {
            case .intro: intro
            case .countdown(let n): countdown(n)
            case .active: active
            case .done: summary
            }
        }
        // Over live video the HUD must always read light-on-dark (glassmorphism);
        // adaptive tokens resolve to their dark variants here regardless of app theme.
        .environment(\.colorScheme, model.usesCamera && !model.isDemoMode ? .dark : systemScheme)
        .task {
            if model.usesCamera && !model.isDemoMode {
                await camera.start()
            }
            #if DEBUG
            // UI-testing hook: skips the intro tap (`-pose4me.autobegin YES`).
            if UserDefaults.standard.bool(forKey: "pose4me.autobegin"), model.stage == .intro {
                try? await Task.sleep(for: .seconds(0.5))
                model.begin()
            }
            #endif
        }
        .onDisappear {
            model.cancel()
            camera.stop()
        }
        .onReceive(camera.$latestPose) { pose in
            guard !model.isDemoMode else { return }
            model.latestCameraPose = pose
        }
    }

    // MARK: - Stages

    private var intro: some View {
        VStack(spacing: 18) {
            headerBar(showsTitle: false)
            Spacer()

            if model.previewSeconds > 0 {
                // Animated movement demo: the figure performs the whole stretch on
                // loop until the user starts (or the customizable timer auto-starts).
                ExercisePreviewPlayer(exercise: model.exercise)
                    .frame(width: 230, height: 330)
            } else {
                GuideFigureView(spec: model.keyframes[0].spec)
                    .frame(width: 200, height: 260)
            }

            Text(model.exercise.name)
                .font(.appLargeTitle)
                .foregroundStyle(Theme.textPrimary)

            Text(model.exercise.instructions)
                .font(.appBody)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Label("\(Int(model.totalDuration))s • \(model.usesCamera ? "camera tracked" : "timer")",
                  systemImage: model.usesCamera ? "camera.viewfinder" : "timer")
                .font(.appSubheadline)
                .foregroundStyle(Theme.textTertiary)

            Spacer()

            if model.previewSeconds > 0 {
                TimelineView(.periodic(from: introStartedAt, by: 1)) { context in
                    let elapsed = Int(context.date.timeIntervalSince(introStartedAt))
                    let remaining = max(0, model.previewSeconds - elapsed)
                    Button(remaining > 0 ? "Start now • auto in \(remaining)s" : "Start now") {
                        model.begin()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            } else {
                Button("Begin") { model.begin() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
            }
        }
        .task {
            // Auto-start once the demo has played for the user-chosen duration.
            guard model.previewSeconds > 0 else { return }
            try? await Task.sleep(for: .seconds(Double(model.previewSeconds)))
            if !Task.isCancelled, model.stage == .intro {
                model.begin()
            }
        }
    }

    private func countdown(_ n: Int) -> some View {
        VStack {
            Spacer()
            Text("\(n)")
                .font(.display(110, .heavy))
                .foregroundStyle(Theme.brandGradient)
                .contentTransition(.numericText(countsDown: true))
                .id(n)
                .transition(.scale(scale: 1.6).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: n)
            Text("Get in frame — whole body visible")
                .font(.appHeadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
    }

    private var active: some View {
        ZStack {
            if model.usesCamera {
                SkeletonOverlayView(pose: model.displayedPose,
                                    matchScore: model.matchResult.score,
                                    offTargetJoint: model.matchResult.score < 0.55
                                        ? model.matchResult.worstLimb : nil)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                headerBar(showsTitle: true)

                HStack(alignment: .top) {
                    Spacer()
                    // The pose to imitate: a coach performing the movement into the
                    // current target on loop.
                    VStack(spacing: 6) {
                        LoopingGuideFigureView(fromSpec: model.copyMeStartSpec,
                                               spec: model.currentKeyframe.spec)
                            .frame(width: 110, height: 150)
                        Text("Copy me")
                            .font(.body(11, .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    .padding(.trailing, 16)
                }
                .padding(.top, 6)

                Spacer()

                VStack(spacing: 14) {
                    Text(model.currentKeyframe.cue)
                        .font(.display(18, .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                        .animation(.easeInOut, value: model.keyframeIndex)

                    if let cue = model.coachingCue {
                        Text(cue)
                            .font(.appSubheadline)
                            .foregroundStyle(Theme.warning)
                            .transition(.opacity)
                    } else if model.usesCamera && model.matchResult.score >= 0.55 {
                        Text("Great form — hold it")
                            .font(.appSubheadline)
                            .foregroundStyle(Theme.success)
                            .transition(.opacity)
                    }

                    holdRing
                        .frame(width: 92, height: 92)

                    // Keyframe progress dots
                    HStack(spacing: 8) {
                        ForEach(0..<model.keyframes.count, id: \.self) { i in
                            Capsule()
                                .fill(i <= model.keyframeIndex ? Theme.accent : Theme.track)
                                .frame(width: i == model.keyframeIndex ? 26 : 10, height: 5)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8),
                                           value: model.keyframeIndex)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    private var holdRing: some View {
        ZStack {
            Circle()
                .stroke(Theme.track, lineWidth: 8)
            Circle()
                .trim(from: 0, to: model.holdProgress)
                .stroke(Theme.brandGradient,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.12), value: model.holdProgress)
            Text("\(Int(ceil(model.currentKeyframe.holdSeconds * (1 - model.holdProgress))))")
                .font(.display(21, .bold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private var summary: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 84))
                .foregroundStyle(Theme.brandGradient)
                .symbolEffect(.bounce, value: model.stage)

            Text("Stretch complete!")
                .font(.appLargeTitle)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 14) {
                summaryStat(value: "\(Int(model.totalDuration))s", label: "Duration")
                if let avg = model.averageScore {
                    summaryStat(value: "\(Int(avg * 100))%", label: "Form match")
                }
                summaryStat(value: model.exercise.category.rawValue, label: "Focus")
            }
            .padding(.horizontal, 24)

            Text("Blood is moving, spine is happy. See you next hour.")
                .font(.appSubheadline)
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            Button("Done") {
                sessionStore.add(model.makeRecord())
                // You just stretched — restart the interval clock from now.
                Task { await scheduler.reschedule(settings: settings.data) }
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
    }

    private func summaryStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.appTitle3)
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.appCaption)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 12)
    }

    private func headerBar(showsTitle: Bool) -> some View {
        HStack {
            if showsTitle {
                Text(model.exercise.name)
                    .font(.appHeadline)
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            Button {
                model.cancel()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body(15, .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
