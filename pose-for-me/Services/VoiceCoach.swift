import AVFoundation

/// Speaks session guidance aloud so users can follow a stretch without watching
/// the screen — they're usually standing two meters from the phone.
///
/// Uses the system speech synthesizer (on-device, no network) and ducks other
/// audio while speaking instead of silencing it.
@MainActor
final class VoiceCoach {
    static let shared = VoiceCoach()

    private let synthesizer = AVSpeechSynthesizer()
    private var sessionActive = false

    private init() {}

    /// Speak a cue, replacing anything currently being spoken.
    func speak(_ text: String) {
        activateAudioSessionIfNeeded()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }

    /// Stop speaking and release the audio session (call when a session ends).
    func finish() {
        synthesizer.stopSpeaking(at: .immediate)
        guard sessionActive else { return }
        sessionActive = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func activateAudioSessionIfNeeded() {
        guard !sessionActive else { return }
        sessionActive = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }
}
