#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Which interactive control on a media view was tapped. `.more` shows the owner's menu; `.add` is the
/// forthcoming "+" button (its UI is not built yet, but the seam carries it so wiring it is additive).
public enum RichTextMediaControlKind {
    case more
    case add
}

/// A framework-agnostic description the editor emits when a media control is tapped. The editor is
/// account-free, so it carries the opaque `mediaID` (the owner resolves the concrete media) plus
/// occurrence-bound operation closures (`delete` now; `replace`/`addMore` reserved). The host presents its
/// own menu — the editor owns HOW each operation is performed (bound to the exact block), the host owns
/// WHICH actions to show. Mirrors `TableStructuralMenuRequest`, with named operations instead of an action
/// list (media actions are owner-specific). References only UIKit + Core.
@available(iOS 13.0, *)
public final class MediaControlRequest {
    /// The tapped control's view — the coordinate space of `sourceRect` and the anchor the host presents
    /// from. Weak so the host does not retain media internals past presentation.
    public weak var view: UIView?
    /// The control's rect in `view` coordinates.
    public let sourceRect: CGRect
    /// Which control was tapped.
    public let control: RichTextMediaControlKind
    /// The opaque host media key for this occurrence. The host resolves the concrete media (e.g. its
    /// `EngineMedia`) from this. NOT unique — see `delete` for occurrence binding.
    public let mediaID: String
    /// Removes THIS occurrence (bound to its `BlockID` by the editor — unambiguous even when `mediaID`
    /// repeats). One undo step.
    public let delete: () -> Void
    /// Reserved: replace THIS occurrence's media with host-picked media. `nil` until implemented.
    public let replace: ((_ mediaID: String, _ naturalSize: CGSize, _ kind: MediaKind) -> Void)?
    /// Reserved: add another medium relative to this occurrence (the "+" button). `nil` until implemented.
    public let addMore: ((_ mediaID: String, _ naturalSize: CGSize, _ kind: MediaKind) -> Void)?

    public init(view: UIView?, sourceRect: CGRect, control: RichTextMediaControlKind, mediaID: String,
                delete: @escaping () -> Void,
                replace: ((String, CGSize, MediaKind) -> Void)? = nil,
                addMore: ((String, CGSize, MediaKind) -> Void)? = nil) {
        self.view = view
        self.sourceRect = sourceRect
        self.control = control
        self.mediaID = mediaID
        self.delete = delete
        self.replace = replace
        self.addMore = addMore
    }
}
#endif
