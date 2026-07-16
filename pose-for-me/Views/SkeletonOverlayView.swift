import SwiftUI

/// Draws the live detected skeleton over the camera preview.
/// Mint lines and dots per the design system; the joint most out of position
/// (and its bones) glow amber so the user knows exactly what to correct.
struct SkeletonOverlayView: View {
    let pose: BodyPose?
    let matchScore: Double        // 0...1; dims the glow while far from target
    let offTargetJoint: BodyJoint?

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard let pose, !pose.isEmpty else { return }
                let projection = PoseProjection(viewSize: size)

                let mint = Theme.skeletonLine
                let amber = Theme.skeletonOffTarget

                func isOffTarget(_ joint: BodyJoint) -> Bool {
                    joint == offTargetJoint
                }

                // Bones — amber when they end at the off-target joint.
                var mintBones = Path()
                var amberBones = Path()
                for (a, b) in BodyPose.bones {
                    guard let pa = pose[a], let pb = pose[b],
                          pa.confidence > 0.25, pb.confidence > 0.25 else { continue }
                    var segment = Path()
                    segment.move(to: projection.point(pa))
                    segment.addLine(to: projection.point(pb))
                    if isOffTarget(a) || isOffTarget(b) {
                        amberBones.addPath(segment)
                    } else {
                        mintBones.addPath(segment)
                    }
                }
                let glowOpacity = 0.25 + 0.2 * matchScore
                context.stroke(mintBones, with: .color(mint.opacity(glowOpacity)),
                               style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                context.stroke(mintBones, with: .color(mint),
                               style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                context.stroke(amberBones, with: .color(amber.opacity(0.4)),
                               style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                context.stroke(amberBones, with: .color(amber),
                               style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

                // Head halo around the nose
                if let nose = pose[.nose], nose.confidence > 0.25 {
                    let center = projection.point(nose)
                    let head = Path(ellipseIn: CGRect(x: center.x - 26, y: center.y - 26,
                                                      width: 52, height: 52))
                    context.stroke(head, with: .color(isOffTarget(.nose) ? amber : mint), lineWidth: 4)
                }

                // Joint dots
                for joint in BodyJoint.allCases where joint.rawValue >= BodyJoint.leftShoulder.rawValue {
                    guard let p = pose[joint], p.confidence > 0.25 else { continue }
                    let c = projection.point(p)
                    let dot = Path(ellipseIn: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12))
                    context.fill(dot, with: .color(.white))
                    context.stroke(dot, with: .color(isOffTarget(joint) ? amber : mint), lineWidth: 3)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
        .animation(.linear(duration: 0.08), value: matchScore)
    }
}
