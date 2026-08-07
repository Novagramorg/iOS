import UIKit

/// `ScrollEngine` backed by `UIScrollView`. Behavior-preserving adapter: it keeps UIKit's
/// pan/momentum/rubber-band/bounce while exposing the physics-semantic seam. The 10M
/// virtual-content trick and the re-entrancy guard live HERE — `UIScrollView` needs a finite
/// `contentSize`; a future physics engine implements `ScrollEngine` without either.
final class UIKitScrollEngine: NSObject, ScrollEngine, UIScrollViewDelegate {
    let scrollView: UIScrollView
    var onScroll: ((CGFloat) -> Void)?

    /// Never fires: UIScrollView advances `bounds.origin` on the main thread every frame, so a
    /// per-frame consumer is already in lockstep with the content.
    var onFlightChanged: ((ScrollFlight?) -> Void)?
    var onWillBeginDragging: (() -> Void)?
    var onDidEndDragging: (() -> Void)?

    /// Raised around programmatic writes so the re-entrant `scrollViewDidScroll` is suppressed.
    /// This is the old `CoreVirtualListView.isUpdating`, now encapsulated.
    private var isProgrammatic = false

    init(scrollView: UIScrollView = UIScrollView()) {
        self.scrollView = scrollView
        super.init()
        scrollView.delegate = self
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.bounces = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.clipsToBounds = false
        scrollView.layer.borderColor = UIColor.blue.cgColor
        scrollView.layer.borderWidth = 1.0
    }

    /// `UIScrollView` clamps `bounds.origin.y` to [0, contentSize − viewport], so it needs a finite
    /// content extent far from 0 for an open edge to be effectively unreachable. Private to the adapter.
    private let canvasExtent: CGFloat = 10_000_000

    var offset: CGFloat { scrollView.bounds.origin.y }
    var contentHost: UIView { scrollView }

    func containerOrigin(windowHeight h: CGFloat, topLoaded: Bool, bottomLoaded: Bool) -> CGFloat {
        if topLoaded { return 0 }                       // glued to the top bounce point
        if bottomLoaded { return canvasExtent - h }     // bottom glued; room above toward 0
        return canvasExtent / 2 - h / 2                 // centred; room both ways
    }

    func setOffset(_ y: CGFloat) {
        isProgrammatic = true
        scrollView.bounds.origin.y = y
        isProgrammatic = false
    }

    func haltMotionInPlace() {
        // A `UIScrollView`'s `bounds.origin` IS its presented position, so writing it back is an exact
        // halt-in-place here — this is the historical `setOffset(offset)` idiom, now stated once instead of
        // at four call sites, and behaviour-preserving for this backend. (If UIKit momentum ever needs a
        // harder stop than a programmatic offset write, the canonical form is
        // `setContentOffset(contentOffset, animated: false)` — deliberately not changed here, since this
        // backend's behaviour is not what the change is about.)
        setOffset(offset)
    }

    func syncToPresentedPosition() {
        // A `UIScrollView`'s `bounds.origin` is always the presented value; there is nothing to re-anchor.
    }

    func applyShift(_ dy: CGFloat) {
        isProgrammatic = true
        scrollView.bounds.origin.y += dy
        isProgrammatic = false
    }

    func setEdges(min: CGFloat?, max: CGFloat?) {
        let height: CGFloat
        if let lo = min, let hi = max {
            // UIScrollView bounces at [0, contentSize.height − viewport]; contentSize.height =
            // maxOffset + viewport. The floor reproduces `max(logicalSize.height, window.height)`
            // and handles content shorter than the viewport (hi − lo negative).
            let viewport = scrollView.bounds.height
            height = Swift.max(viewport, (hi - lo) + viewport)
        } else {
            height = canvasExtent
        }
        // A contentSize SHRINK clamps `bounds.origin.y` into the new [0, contentSize − viewport]
        // range, which fires `scrollViewDidScroll`. `setEdges` is a programmatic declaration (called
        // from `render()`), never a user scroll — so guard it like `setOffset`/`applyShift`. Without
        // this, shrinking the canvas (e.g. a delete that turns a deep bottom-loaded window into a
        // tight both-edges-loaded one) clamps the offset by a huge amount and RE-ENTERS
        // `onScroll → handleUserScroll → rebalanceActiveWindow` mid-render, with a stale
        // `containerOriginY`, collapsing the loaded window to a single row.
        isProgrammatic = true
        scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: height)
        isProgrammatic = false
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isProgrammatic else { return }
        onScroll?(scrollView.bounds.origin.y)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        onWillBeginDragging?()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        onDidEndDragging?()
    }
}
