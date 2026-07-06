import UIKit
import QuartzCore

/// A tap-streak recognizer: fires `onReveal` after `requiredTaps` taps that each
/// land within `tapWindow` seconds of the previous one. Recognizes simultaneously
/// with the surrounding scroll/tap gestures so it never blocks normal interaction.
///
/// Generalized from the NovagramPro settings "ads reveal" easter egg; here it
/// unlocks the Secret Vault when the user taps the "Chats" title 10 times.
public final class SecretVaultRevealGestureRecognizer: UITapGestureRecognizer, UIGestureRecognizerDelegate {
    private let onReveal: () -> Void
    private let requiredTaps: Int
    private let tapWindow: Double
    private var lastTapTimestamp: Double = 0.0
    private var tapCount: Int = 0

    public init(requiredTaps: Int = 10, tapWindow: Double = 0.7, onReveal: @escaping () -> Void) {
        self.onReveal = onReveal
        self.requiredTaps = requiredTaps
        self.tapWindow = tapWindow
        super.init(target: nil, action: nil)
        self.cancelsTouchesInView = false
        self.delegate = self
        self.addTarget(self, action: #selector(self.handleTap))
    }

    @objc private func handleTap() {
        let timestamp = CACurrentMediaTime()
        if timestamp - self.lastTapTimestamp > self.tapWindow {
            self.tapCount = 0
        }
        self.lastTapTimestamp = timestamp
        self.tapCount += 1
        if self.tapCount >= self.requiredTaps {
            self.tapCount = 0
            self.onReveal()
        }
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
