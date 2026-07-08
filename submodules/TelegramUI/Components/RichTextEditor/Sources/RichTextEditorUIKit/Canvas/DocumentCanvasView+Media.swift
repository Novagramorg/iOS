#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Reconciles pooled host media views against the laid-out document: reuse by owning `BlockID`,
    /// create via the provider for new blocks, size+position each at its media rect, tear down removed
    /// ones. Mirrors `syncEmojiViews`; media is simpler (one view per `MediaBlockBox`, positioned at the
    /// box's own canvas rect — no attachment-glyph scan). Called from `layoutSubviews` after blocks lay out.
    func syncMediaItemViews() {
        var present = Set<BlockID>()
        for box in boxes {
            guard let media = box as? MediaBlockBox else { continue }
            present.insert(media.id)
            let canvasRect = media.mediaRect()
            let hosted: HostedMediaItem
            if let h = mediaItemViews[media.id] {
                hosted = h
            } else if let v = mediaViewProvider(media.mediaID, CGSize(width: media.naturalSize.width,
                                                                      height: media.naturalSize.height)) {
                // Interaction-enabled so its `hitTest` is consulted, but the media view only claims a
                // touch that lands on one of its interactive controls (the more button); the poster area
                // returns nil and the touch falls through to the editor. See MediaPassthroughOverlayView.
                v.isUserInteractionEnabled = true
                hosted = HostedMediaItem(view: v, canvasFrame: canvasRect)
                mediaItemViews[media.id] = hosted
            } else {
                continue   // provider not ready — retried on the next layout pass
            }
            hosted.canvasFrame = canvasRect
            if hosted.view.superview !== mediaOverlay { mediaOverlay.addSubview(hosted.view) }
            hosted.view.frame = canvasRect
            hosted.view.update(size: canvasRect.size)
        }
        for (id, h) in mediaItemViews where !present.contains(id) {
            h.view.removeFromSuperview()
            mediaItemViews[id] = nil
        }
        cullMediaItemViews()
    }

    /// Hides media views whose canvas frame is > `mediaCullMargin` outside the visible viewport.
    func cullMediaItemViews() {
        let visible: CGRect
        if let sv = superview as? UIScrollView {
            visible = CGRect(origin: sv.contentOffset, size: sv.bounds.size)
        } else {
            visible = bounds
        }
        let expanded = visible.insetBy(dx: -mediaCullMargin, dy: -mediaCullMargin)
        for (_, h) in mediaItemViews {
            h.view.isHidden = !expanded.intersects(h.canvasFrame)
        }
    }

    // MARK: Test accessors
    var hostedMediaCountForTesting: Int { mediaItemViews.count }
    func hostedMediaViewForTesting(_ id: BlockID) -> RichTextMediaItemView? { mediaItemViews[id]?.view }
}

/// The `mediaOverlay` container. A full-bounds, visually-transparent pass-through: its `hitTest` returns
/// a hosted media view's subview ONLY when that media view claims the touch (i.e. the touch lands on an
/// interactive control such as the more button, per `MediaItemNodeView.hitTest`). Otherwise it returns
/// nil — NOT itself — so the canvas's own tap/caret/selection handling runs for taps on the media poster
/// and everywhere else. It must stay user-interaction-enabled or its `hitTest` (and the media views'
/// below it) would be skipped entirely.
@available(iOS 13.0, *)
final class MediaPassthroughOverlayView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        return result === self ? nil : result
    }
}
#endif
