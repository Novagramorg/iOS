import UIKit

/// Long press that arms itself only when the touch lands on the chat-list title.
///
/// The vault entry point cannot live on the title view itself: when the story bar is
/// collapsed it puts a full-width "tap to expand" button over the whole title area, and
/// that button is a sibling of the title view — not a descendant — so touches there are
/// never delivered to recognizers attached to the title. The recognizer therefore has to
/// sit on a shared ancestor (the navigation bar) and filter by what the touch actually hit.
///
/// Filtering happens in `touchesBegan` rather than through a delegate so that a press that
/// is not on the title fails immediately and never cancels the touch for the view that
/// legitimately owns it (story avatar context menus, nav-bar buttons).
public final class SecretVaultTitleLongPressGestureRecognizer: UILongPressGestureRecognizer {
    private let shouldBeginAtPoint: (CGPoint) -> Bool

    public init(target: Any?, action: Selector?, shouldBeginAtPoint: @escaping (CGPoint) -> Bool) {
        self.shouldBeginAtPoint = shouldBeginAtPoint
        super.init(target: target, action: action)
    }

    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let view = self.view, let touch = touches.first else {
            self.state = .failed
            return
        }
        guard self.shouldBeginAtPoint(touch.location(in: view)) else {
            self.state = .failed
            return
        }
        super.touchesBegan(touches, with: event)
    }
}
