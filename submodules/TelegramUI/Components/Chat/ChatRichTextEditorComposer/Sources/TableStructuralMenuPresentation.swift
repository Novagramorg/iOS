import Foundation
import UIKit
import Display
import ContextUI
import TelegramPresentationData
import RichTextEditorCore
import RichTextEditorUIKit
import TelegramCore

/// Presents the editor's table row/column structural menu as a Telegram `ContextController`, anchored to
/// the tapped handle described by `request`. Shared by both editor hosts (the chat composer and the
/// attachment screen); they differ only in HOW the built controller is presented, injected via `present`.
/// This is the ONE place that maps the editor's framework-agnostic `TableStructuralMenuRequest` to ContextUI.
@available(iOS 13.0, *)
public func presentTableStructuralMenu(
    _ request: TableStructuralMenuRequest,
    presentationData: PresentationData,
    present: (ViewController) -> Void
) {
    guard let anchorView = request.view else { return }
    // A transient zero-interaction anchor at the handle's rect (in the canvas's coordinate space); the
    // reference source converts it to window space. Removed when the controller is dismissed.
    let anchor = UIView(frame: request.sourceRect)
    anchor.isUserInteractionEnabled = false
    anchorView.addSubview(anchor)

    var items: [ContextMenuItem] = []
    if let alignment = request.alignment {
        items.append(.custom(TableStructuralMenuAlignmentItem(
            initialHorizontal: alignment.horizontal.map(tableHAlign(fromCore:)),
            initialVertical: alignment.vertical.map(tableVAlign(fromCore:)),
            action: { h, v in
                alignment.apply(h.map(coreHAlign(from:)), v.map(coreVAlign(from:)))
            }), false))

        if !request.actions.isEmpty {
            items.append(.separator)
        }
    }
    items.append(contentsOf: request.actions.map { action in
        .action(ContextMenuActionItem(
            text: tableStructuralMenuTitle(action.kind),
            textColor: tableStructuralMenuIsDestructive(action.kind) ? .destructive : .primary,
            icon: { _ in nil },
            action: { _, f in f(.default); action.perform() }
        ))
    })

    let controller = makeContextController(
        presentationData: presentationData,
        source: .reference(RichTextStructuralMenuReferenceSource(sourceView: anchor)),
        items: .single(ContextController.Items(content: .list(items))),
        gesture: nil
    )
    controller.dismissed = { [weak anchor] in anchor?.removeFromSuperview() }
    present(controller)
}

private func tableStructuralMenuTitle(_ kind: TableStructuralMenuRequest.Kind) -> String {
    switch kind {
    case .addColumnLeft: return "Add Column Left"
    case .addColumnRight: return "Add Column Right"
    case .deleteColumn: return "Delete Column"
    case .addRowAbove: return "Add Row Above"
    case .addRowBelow: return "Add Row Below"
    case .deleteRow: return "Delete Row"
    }
}

private func tableStructuralMenuIsDestructive(_ kind: TableStructuralMenuRequest.Kind) -> Bool {
    switch kind {
    case .deleteColumn, .deleteRow: return true
    default: return false
    }
}

private func tableHAlign(fromCore a: TextAlignment) -> TableHorizontalAlignment {
    switch a { case .left, .natural, .justified: return .left; case .center: return .center; case .right: return .right }
}
private func coreHAlign(from a: TableHorizontalAlignment) -> TextAlignment {
    switch a { case .left: return .left; case .center: return .center; case .right: return .right }
}
private func tableVAlign(fromCore a: VerticalAlignment) -> TableVerticalAlignment {
    switch a { case .top: return .top; case .middle: return .middle; case .bottom: return .bottom }
}
private func coreVAlign(from a: TableVerticalAlignment) -> VerticalAlignment {
    switch a { case .top: return .top; case .middle: return .middle; case .bottom: return .bottom }
}

/// Anchors a `ContextController` to a sub-rect view (the transient handle anchor). Mirrors the attachment
/// screen's `RichTextActionContextReferenceSource`, generalized to any anchor view.
@available(iOS 13.0, *)
private final class RichTextStructuralMenuReferenceSource: ContextReferenceContentSource {
    private let sourceView: UIView
    init(sourceView: UIView) { self.sourceView = sourceView }
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView,
            contentAreaInScreenSpace: UIScreen.main.bounds,
            insets: UIEdgeInsets(top: -4.0, left: 0.0, bottom: -4.0, right: 0.0), actionsPosition: .bottom)
    }
}
