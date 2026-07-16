import SwiftUI

/// A skeleton path that can smoothly morph between two poses.
/// `progress` is the animatable interpolation parameter (0 = from, 1 = to), so any
/// SwiftUI animation (springs included) drives the morph.
struct MorphingSkeletonShape: Shape {
    var from: BodyPose
    var to: BodyPose
    var progress: CGFloat
    /// Portion of the rect the figure is fitted into.
    var inset: CGFloat = 0.06

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let drawRect = rect.insetBy(dx: rect.width * inset, dy: rect.height * inset)

        func point(_ joint: BodyJoint) -> CGPoint? {
            guard let a = from[joint], let b = to[joint] else { return nil }
            let t = min(max(progress, 0), 1)
            let x = a.x + (b.x - a.x) * t
            let y = a.y + (b.y - a.y) * t
            return CGPoint(x: drawRect.minX + x * drawRect.width,
                           y: drawRect.minY + y * drawRect.height)
        }

        for (a, b) in BodyPose.bones {
            guard let pa = point(a), let pb = point(b) else { continue }
            path.move(to: pa)
            path.addLine(to: pb)
        }

        // Head: circle centered a touch above the nose keypoint.
        if let nose = point(.nose) {
            let r = drawRect.width * 0.085
            path.addEllipse(in: CGRect(x: nose.x - r, y: nose.y - r * 1.5,
                                       width: r * 2, height: r * 2))
        }
        return path
    }
}

/// The animated coach: demonstrates the current keyframe's pose and springs into the
/// next one when the session advances. This is the "imitate me" figure.
struct GuideFigureView: View {
    let spec: PoseSpec
    var lineWidth: CGFloat = 5
    var glow: Bool = true

    @State private var fromPose: BodyPose
    @State private var toPose: BodyPose
    @State private var progress: CGFloat = 1
    @State private var breathe = false

    init(spec: PoseSpec, lineWidth: CGFloat = 5, glow: Bool = true) {
        self.spec = spec
        self.lineWidth = lineWidth
        self.glow = glow
        let pose = spec.keypoints()
        _fromPose = State(initialValue: pose)
        _toPose = State(initialValue: pose)
    }

    var body: some View {
        MorphingSkeletonShape(from: fromPose, to: toPose, progress: progress)
            .stroke(Theme.brandGradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .shadow(color: glow ? Theme.accent.opacity(0.8) : .clear, radius: glow ? 10 : 0)
            .scaleEffect(breathe ? 1.02 : 0.99)
            .onAppear {
                guard glow else { return }
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
            .onChange(of: spec) { _, newSpec in
                fromPose = toPose
                toPose = newSpec.keypoints()
                progress = 0
                withAnimation(.spring(response: 1.0, dampingFraction: 0.72)) {
                    progress = 1
                }
            }
    }
}

/// A coach that repeatedly performs the movement into `spec` on loop:
/// morph from `fromSpec` into the target, hold it, ease back, repeat.
/// Used by the in-session "Copy me" card so the user sees the motion, not a
/// frozen pose — and unlike ExercisePreviewPlayer it never leaves the keyframe
/// the tracker is currently scoring.
struct LoopingGuideFigureView: View {
    let fromSpec: PoseSpec
    let spec: PoseSpec
    var lineWidth: CGFloat = 4

    @State private var showTarget = true

    var body: some View {
        // GuideFigureView owns the spring morph via its onChange(of: spec); this
        // loop only toggles which pose it is given, so the animation path is the
        // same one the intro demo uses.
        GuideFigureView(spec: showTarget ? spec : fromSpec, lineWidth: lineWidth)
            .task(id: spec) {
                showTarget = true
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2.6)) // hold the target
                    guard !Task.isCancelled else { return }
                    showTarget = false                        // ease back to start
                    try? await Task.sleep(for: .seconds(1.2))
                    guard !Task.isCancelled else { return }
                    showTarget = true                         // perform the move again
                }
            }
    }
}

/// Loops the exercise's full movement — the guide figure morphs through every
/// keyframe with its cue caption — so users watch the motion before copying it.
struct ExercisePreviewPlayer: View {
    let exercise: Exercise
    /// Seconds each keyframe is shown before morphing to the next.
    var stepSeconds: Double = 2.2

    @State private var index = 0

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topTrailing) {
                GuideFigureView(spec: exercise.keyframes[index].spec)
                    .frame(maxWidth: .infinity)

                Label("Demo", systemImage: "play.fill")
                    .font(.body(11, .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accent, in: Capsule())
            }

            Text(exercise.keyframes[index].cue)
                .font(.appHeadline)
                .foregroundStyle(Theme.accent)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.4), value: index)
                .frame(minHeight: 44, alignment: .top)

            // Step dots mirroring the movement's keyframes.
            HStack(spacing: 7) {
                ForEach(0..<exercise.keyframes.count, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? Theme.accent : Theme.track)
                        .frame(width: i == index ? 22 : 8, height: 5)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
                }
            }
        }
        .task {
            guard exercise.keyframes.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(stepSeconds))
                guard !Task.isCancelled else { return }
                index = (index + 1) % exercise.keyframes.count
            }
        }
    }
}

/// Static mini figure for library cards and thumbnails.
struct PoseThumbnail: View {
    let spec: PoseSpec

    var body: some View {
        MorphingSkeletonShape(from: spec.keypoints(), to: spec.keypoints(), progress: 1)
            .stroke(Theme.brandGradient,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }
}
