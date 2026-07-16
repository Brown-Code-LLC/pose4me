import SwiftUI

/// Draws the live detected skeleton over the camera preview.
/// Bones glow green as the user's pose converges on the target.
struct SkeletonOverlayView: View {
    let pose: BodyPose?
    let matchScore: Double // 0...1 drives the color shift

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard let pose, !pose.isEmpty else { return }
                let projection = PoseProjection(viewSize: size)

                let color = Color(
                    hue: 0.36 * matchScore + 0.55 * (1 - matchScore), // azure -> green
                    saturation: 0.85, brightness: 1.0
                )

                // Bones
                var bonesPath = Path()
                for (a, b) in BodyPose.bones {
                    guard let pa = pose[a], let pb = pose[b],
                          pa.confidence > 0.25, pb.confidence > 0.25 else { continue }
                    bonesPath.move(to: projection.point(pa))
                    bonesPath.addLine(to: projection.point(pb))
                }
                context.stroke(bonesPath, with: .color(color.opacity(0.35)),
                               style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                context.stroke(bonesPath, with: .color(color),
                               style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

                // Head halo around the nose
                if let nose = pose[.nose], nose.confidence > 0.25 {
                    let center = projection.point(nose)
                    let head = Path(ellipseIn: CGRect(x: center.x - 26, y: center.y - 26,
                                                      width: 52, height: 52))
                    context.stroke(head, with: .color(color), lineWidth: 4)
                }

                // Joints
                for joint in BodyJoint.allCases where joint.rawValue >= BodyJoint.leftShoulder.rawValue {
                    guard let p = pose[joint], p.confidence > 0.25 else { continue }
                    let c = projection.point(p)
                    let dot = Path(ellipseIn: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12))
                    context.fill(dot, with: .color(.white))
                    context.stroke(dot, with: .color(color), lineWidth: 3)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
        .animation(.linear(duration: 0.08), value: matchScore)
    }
}
