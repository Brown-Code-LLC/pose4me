import Foundation
import CoreVideo
import ImageIO

/// A pose estimation backend. Implementations run synchronously on the camera's
/// video-data queue; frames are dropped upstream while an estimate is in flight.
nonisolated protocol PoseEstimator: AnyObject, Sendable {
    /// Human-readable backend name shown in Settings ("YOLO26-pose", "Apple Vision").
    var backendName: String { get }

    /// Estimate the most prominent person's pose.
    /// - Returns: keypoints normalized to 0...1, origin top-left, already in the
    ///   mirrored "selfie" orientation the preview shows.
    func estimatePose(in pixelBuffer: CVPixelBuffer) -> BodyPose?
}

/// Picks the best available backend: bundled YOLO26 CoreML model when present,
/// otherwise Apple Vision (always available, zero setup).
enum PoseEstimatorFactory {
    nonisolated static func makeBest() -> any PoseEstimator {
        if let yolo = YOLO26PoseEstimator() {
            return yolo
        }
        return VisionPoseEstimator()
    }

    /// Cached backend name for display in Settings (computed once, lazily).
    nonisolated static let bestBackendName: String = makeBest().backendName
}
