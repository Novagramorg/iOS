#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// A framework-agnostic description of the table row/column structural menu the editor wants shown.
/// The editor hands this to its host (via `RichTextEditorView.onRequestTableStructuralMenu`); the host
/// presents its own menu (a Telegram `ContextController`) however it sees fit. The editor owns WHAT the
/// menu contains (adapted to the table state); the host owns HOW it is presented (title strings, icons,
/// styling, coordinate conversion). References only UIKit + Core — never ContextUI/Display.
@available(iOS 13.0, *)
public final class TableStructuralMenuRequest {
    /// The view whose coordinate space `sourceRect` is expressed in — the editor's canvas. Weak so the
    /// host does not retain editor internals past presentation.
    public weak var view: UIView?
    /// The tapped handle's rect in `view` coordinates — the anchor the host presents the menu from.
    public let sourceRect: CGRect
    /// Add/Delete actions, already adapted to the table state (header row → no Add-Above/Delete;
    /// all-columns range → no Delete Column). Ordered for display.
    public let actions: [Action]
    /// Column selections only (nil for rows): the alignment choices + a callback. The host renders this
    /// as a custom segmented control (deferred); the data is carried now.
    public let alignment: Alignment?

    public init(view: UIView?, sourceRect: CGRect, actions: [Action], alignment: Alignment?) {
        self.view = view
        self.sourceRect = sourceRect
        self.actions = actions
        self.alignment = alignment
    }

    /// One menu action. `kind` is a stable semantic identity from which the host derives the (localizable)
    /// title, destructive styling, and icon — no presentation state is carried here. `perform` runs the
    /// edit AND clears the structural selection.
    public struct Action {
        public let kind: Kind
        public let perform: () -> Void
        public init(kind: Kind, perform: @escaping () -> Void) {
            self.kind = kind
            self.perform = perform
        }
    }

    public enum Kind: Equatable {
        case addColumnLeft, addColumnRight, deleteColumn
        case addRowAbove, addRowBelow, deleteRow
    }

    /// Column alignment (host renders a custom segmented control). `select` applies + clears the selection.
    public struct Alignment {
        public let options: [TextAlignment]
        public let current: TextAlignment?
        public let select: (TextAlignment) -> Void
        public init(options: [TextAlignment], current: TextAlignment?, select: @escaping (TextAlignment) -> Void) {
            self.options = options
            self.current = current
            self.select = select
        }
    }
}
#endif
