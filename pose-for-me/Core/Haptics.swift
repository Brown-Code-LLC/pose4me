import UIKit

/// Lightweight haptic helper; every call is a no-op when the user disables haptics.
enum Haptics {
    nonisolated(unsafe) static var isEnabled = true

    @MainActor static func tap() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @MainActor static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @MainActor static func milestone() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}
