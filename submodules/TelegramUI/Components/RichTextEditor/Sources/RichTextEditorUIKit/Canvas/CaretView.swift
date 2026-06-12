#if canImport(UIKit)
import UIKit

/// The app's OWN text caret — a thin tint-colored bar with a self-driven blink. We draw it ourselves
/// (the canvas installs no `UITextSelectionDisplayInteraction`, so there is no OS cursor view to begin with —
/// see `installSelectionInteractions`) so that, when the caret sits inside a horizontally-scrollable table
/// cell, it can be hosted INSIDE the table's scrolling content view and ride the scroll/overscroll bounce —
/// exactly like the selection fill and handles already do. We own the blink here.
@available(iOS 17.0, *)
final class CaretView: UIView {
    private static let blinkKey = "caretBlink"

    /// Incremented every time the blink is reset (solid-then-resume). Exposed for unit tests to assert the
    /// idempotency of `DocumentCanvasView.updateCaretView` — a no-op update must not restart the blink.
    private(set) var blinkResetCount = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .tintColor
        layer.cornerRadius = 1
        isHidden = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        backgroundColor = .tintColor
    }

    /// Adds the repeating opacity blink (1 → 0, autoreversing) if it isn't already running. Solid at first.
    func startBlink() {
        guard layer.animation(forKey: Self.blinkKey) == nil else { return }
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 1
        anim.toValue = 0
        anim.duration = 0.5
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(anim, forKey: Self.blinkKey)
    }

    /// Restarts the blink so the caret shows SOLID immediately, then resumes blinking — approximating iOS's
    /// pause-on-move behaviour. Called only when the caret actually moves (a real position change), never on
    /// a no-op refresh (e.g. a scroll tick), so the blink isn't perpetually reset.
    func resetBlink() {
        layer.removeAnimation(forKey: Self.blinkKey)
        layer.opacity = 1
        blinkResetCount += 1
        startBlink()
    }

    /// Hides the caret and stops the blink (no caret to show, e.g. a ranged/structural selection).
    func stopBlink() {
        layer.removeAnimation(forKey: Self.blinkKey)
        isHidden = true
    }
}
#endif
