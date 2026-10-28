import Foundation
import UIKit

/// A long press with a very long duration, attached to a Settings row's touch view.
///
/// No visual feedback. The recognizer cancels the view's touches when it fires, so the row's normal tap
/// does not run after a long hold. Moving the finger more than the system tolerance (or scrolling)
/// makes it fail, which restarts the wait.
public final class NovagramHiddenLongPress: NSObject, UIGestureRecognizerDelegate {
    private let recognizer = UILongPressGestureRecognizer()
    private var action: (() -> Void)?

    /// `recognizesSimultaneously`: for a view with its own tap recognizer (a Settings comment line).
    /// That recognizer ends after 0.3 s of holding and would make this one fail with it.
    public init(view: UIView, recognizesSimultaneously: Bool = false) {
        super.init()
        self.recognizer.isEnabled = false
        self.recognizer.addTarget(self, action: #selector(self.handle(_:)))
        if recognizesSimultaneously {
            self.recognizer.delegate = self
        }
        view.addGestureRecognizer(self.recognizer)
    }

    /// A nil action (or a zero duration) turns the recognizer off.
    public func update(duration: TimeInterval, action: (() -> Void)?) {
        self.action = action
        self.recognizer.minimumPressDuration = duration
        self.recognizer.isEnabled = action != nil && duration > 0.0
    }

    @objc private func handle(_ recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .began {
            self.action?()
        }
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
