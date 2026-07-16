import SwiftUI
import AVFoundation

/// Live front-camera preview backed by AVCaptureVideoPreviewLayer.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

/// Maps normalized image coordinates (top-left origin) into view coordinates,
/// matching the preview layer's aspect-fill crop so the skeleton hugs the video.
struct PoseProjection {
    var viewSize: CGSize
    /// Camera buffer aspect after the 90° portrait rotation (480x640 -> 3:4).
    var imageAspect: CGFloat = 3.0 / 4.0

    func point(_ p: JointPoint) -> CGPoint {
        project(CGPoint(x: p.x, y: p.y))
    }

    func project(_ p: CGPoint) -> CGPoint {
        guard viewSize.width > 0, viewSize.height > 0 else { return .zero }
        let viewAspect = viewSize.width / viewSize.height
        var displayed = CGSize.zero
        if viewAspect > imageAspect {
            displayed = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
        } else {
            displayed = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
        }
        let xOffset = (displayed.width - viewSize.width) / 2
        let yOffset = (displayed.height - viewSize.height) / 2
        return CGPoint(x: p.x * displayed.width - xOffset,
                       y: p.y * displayed.height - yOffset)
    }
}
