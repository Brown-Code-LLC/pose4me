import Combine
import Foundation
import AVFoundation
import CoreVideo

/// Owns the front-camera capture session and publishes detected poses to the UI.
///
/// Frames are processed synchronously on the video-data queue by `FrameProcessor`
/// (dropped frames are discarded upstream), and each resulting `BodyPose` hops to the
/// main actor for SwiftUI.
@MainActor
final class CameraManager: ObservableObject {
    // Xcode 26.2's Swift runtime intermittently aborts in the isolated-deinit
    // executor hop (malloc abort in TaskLocal scope) when MainActor classes
    // deallocate. Deinit only releases storage, which is thread-safe, so opt
    // out of isolation and skip the crashing hop entirely.
    nonisolated deinit {}

    @Published private(set) var latestPose: BodyPose?
    @Published private(set) var isRunning = false
    @Published private(set) var permissionDenied = false

    let session = AVCaptureSession()
    let backendName: String

    private let processor: FrameProcessor
    private var configured = false

    init() {
        let estimator = PoseEstimatorFactory.makeBest()
        backendName = estimator.backendName
        processor = FrameProcessor(estimator: estimator)
        processor.onPose = { [weak self] pose in
            Task { @MainActor [weak self] in
                self?.latestPose = pose
            }
        }
    }

    func start() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                permissionDenied = true
                return
            }
        case .denied, .restricted:
            permissionDenied = true
            return
        default:
            break
        }

        configureIfNeeded()
        let session = self.session
        await Task.detached(priority: .userInitiated) {
            if !session.isRunning { session.startRunning() }
        }.value
        isRunning = true
    }

    func stop() {
        let session = self.session
        Task.detached(priority: .utility) {
            if session.isRunning { session.stopRunning() }
        }
        isRunning = false
        latestPose = nil
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true

        session.beginConfiguration()
        session.sessionPreset = .vga640x480 // plenty for pose; keeps inference fast

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(processor, queue: processor.queue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        // Rotate + mirror on the connection so estimators receive upright selfie frames
        // that already match what the preview layer shows.
        if let connection = output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
        session.commitConfiguration()
    }
}

/// Receives camera frames off the main actor and runs pose estimation on them.
nonisolated final class FrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "pose4me.videodata", qos: .userInitiated)
    var onPose: (@Sendable (BodyPose?) -> Void)?

    private let estimator: any PoseEstimator
    private var frameIndex = 0

    init(estimator: any PoseEstimator) {
        self.estimator = estimator
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        frameIndex += 1
        // ~15 fps estimation is plenty for stretch tracking and halves the power draw.
        guard frameIndex.isMultiple(of: 2),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pose = estimator.estimatePose(in: pixelBuffer)
        onPose?(pose)
    }
}
