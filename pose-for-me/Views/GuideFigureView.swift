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
            .stroke(Theme.auroraGradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .shadow(color: glow ? Theme.aurora2.opacity(0.8) : .clear, radius: glow ? 10 : 0)
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

/// Static mini figure for library cards and thumbnails.
struct PoseThumbnail: View {
    let spec: PoseSpec

    var body: some View {
        MorphingSkeletonShape(from: spec.keypoints(), to: spec.keypoints(), progress: 1)
            .stroke(Theme.auroraGradient,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }
}
