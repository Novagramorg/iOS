#if canImport(UIKit)
import UIKit

/// A host-supplied view that renders one attached medium (image/video). The editor creates it once
/// per media occurrence (via the registered provider), owns/positions/culls it, and calls
/// `update(size:)` on every layout pass with the current display rect; resize in place and keep it
/// cheap (idempotent) — so a heavy backing (e.g. an `InstantPageImageNode`) is resized in place
/// rather than rebuilt. The view is non-interactive from the editor's perspective; it lays itself
/// out against its own `bounds`.
@available(iOS 13.0, *)
public protocol RichTextMediaItemView: UIView {
    func update(size: CGSize)
}
#endif
