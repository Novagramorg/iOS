#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// The top-level paragraph box containing the caret (`head`), or nil when the caret is inside a table
    /// cell (there the containing top-level box is a `TableBlockBox`, not a `BlockBox`).
    private func headTopLevelBlock() -> BlockBox? {
        guard let r = resolveBox(at: head) else { return nil }
        return r.box as? BlockBox
    }

    private func currentInlineFormats() -> (bold: Bool, italic: Bool, underline: Bool, strikethrough: Bool, code: Bool) {
        let targets = characterFormatTargets()
        if !targets.isEmpty {
            return (
                bold: targets.allSatisfy { rangeIsBold($0.storage, $0.range) },
                italic: targets.allSatisfy { rangeIsItalic($0.storage, $0.range) },
                underline: targets.allSatisfy { rangeIsUnderline($0.storage, $0.range) },
                strikethrough: targets.allSatisfy { rangeIsStrikethrough($0.storage, $0.range) },
                code: targets.allSatisfy { rangeIsInlineCode($0.storage, $0.range) }
            )
        }
        // Collapsed caret: the format the next typed character would inherit.
        guard let (region, local) = leafRegion(containingGlobal: head) else { return (false, false, false, false, false) }
        let ca = mapper.characterAttributes(from: typingAttributeDict(region: region, atLocal: local))
        return (ca.bold, ca.italic, ca.underline, ca.strikethrough, ca.inlineCode)
    }

    func currentState() -> RichTextEditorView.EditorState {
        let topBlock = headTopLevelBlock()
        let fmt = currentInlineFormats()
        return RichTextEditorView.EditorState(
            bold: fmt.bold, italic: fmt.italic, underline: fmt.underline, strikethrough: fmt.strikethrough, code: fmt.code,
            paragraphStyle: topBlock?.style,
            listMarker: topBlock?.listMembership?.marker,
            link: currentLink(),
            // Either endpoint in a table: a selection partially overlapping a table still counts as
            // "in table" for toolbar purposes (so table-structural commands can enable).
            hasSelection: selFrom < selTo,
            isInTable: isInsideTable(head) || isInsideTable(anchor),
            canUndo: effectiveUndoManager?.canUndo ?? false,
            canRedo: effectiveUndoManager?.canRedo ?? false
        )
    }
}
#endif
