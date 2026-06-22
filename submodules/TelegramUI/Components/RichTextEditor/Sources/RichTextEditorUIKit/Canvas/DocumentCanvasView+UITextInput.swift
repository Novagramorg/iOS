#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
extension DocumentCanvasView: UITextInput {
    private func clamp(_ n: Int) -> Int { clampGlobal(n) }

    func text(in range: UITextRange) -> String? {
        guard let r = range as? DocumentTextRange else { return nil }
        let lo = clamp(min(r.from.offset, r.to.offset)), hi = clamp(max(r.from.offset, r.to.offset))
        var result = ""
        for region in allLeafRegions() {
            let a = max(lo, region.globalStart), b = min(hi, region.globalStart + region.length)
            guard a < b else { continue }
            let attr = region.layout.attributedString
            let ns = attr.string as NSString
            let slice = NSRange(location: a - region.globalStart, length: b - a)
            // Replace each emoji spacer (U+FFFC + EmojiTextAttachment) with its altText (or nothing);
            // copy every other span verbatim. Keeps non-emoji behaviour identical.
            attr.enumerateAttribute(.attachment, in: slice, options: []) { value, sub, _ in
                if let att = value as? EmojiTextAttachment {
                    result += att.ref.altText ?? ""
                } else {
                    result += ns.substring(with: sub)
                }
            }
        }
        return result
    }

    func replace(_ range: UITextRange, withText text: String) {
        guard let r = range as? DocumentTextRange else { return }
        let lo = min(r.from.offset, r.to.offset)
        let hi = max(r.from.offset, r.to.offset)
        // Route through the 3-way selection logic, not applyReplace directly: a system-initiated
        // replacement (autocorrect/dictation/marked-text) can span a table boundary, which the
        // same-stack-guarded applyReplace would silently drop.
        editing { applySelectionReplace(globalFrom: lo, globalTo: hi, text: text) }
    }

    func typingAttributeDict(region: LeafTextRegion, atLocal location: Int) -> [NSAttributedString.Key: Any] {
        let storage = region.layout.attributedString
        if storage.length == 0 {
            // An empty image caption is render-only centered (not in the model), so the next typed
            // character must carry that centered paragraph style explicitly or it would land left-aligned.
            if let img = boxes.compactMap({ $0 as? MediaBlockBox }).first(where: { region.ref == .caption($0.id) }) {
                return img.captionTypingAttributes()
            }
            // Recover the owning paragraph (if any) so an empty styled/listed paragraph keeps its
            // paragraph style on the next typed character — identical to the prior box-based logic.
            let p = boxes.compactMap { $0 as? BlockBox }.first { region.ref == .paragraph($0.id) }
            let style = p?.style ?? .body
            let para = p?.paragraphAttributes ?? .default
            let list = p?.listMembership
            var attrs = mapper.attributes(for: CharacterAttributes(), style: style)
            attrs[.paragraphStyle] = mapper.styleSheet.paragraphStyle(for: style, attributes: para, list: list)
            return attrs
        }
        return storage.attributes(at: min(max(0, location - 1), storage.length - 1), effectiveRange: nil)
    }

    /// Typing attributes for the caret at a global position: the leaf region's attributes, or body
    /// defaults at a structural boundary (no region). Used by the structural-edit engine.
    func typingAttributesAtGlobal(_ pos: Int) -> [NSAttributedString.Key: Any] {
        if let (region, local) = leafRegion(containingGlobal: clamp(pos)) {
            return typingAttributeDict(region: region, atLocal: local)
        }
        return mapper.attributes(for: CharacterAttributes(), style: .body)
    }

    var selectedTextRange: UITextRange? {
        get { DocumentTextRange(DocumentTextPosition(anchor), DocumentTextPosition(head)) }
        set {
            finalizeMarkedText()     // a deliberate selection move commits a composition / dismisses a prediction
            clearStructuralSelections()
            dismissEditMenuForSelectionOrTextChange()   // system-driven move (keyboard cursor-drag / autocorrect) closes the menu too
            let r = newValue as? DocumentTextRange
            anchor = clamp(r?.from.offset ?? 0); head = clamp(r?.to.offset ?? 0)
            setNeedsDisplay(); refreshSelectionUI()
            onSelectionChange?()     // host scrolls the (possibly off-screen) caret into view — e.g. arrow-key nav up out of a tall image
        }
    }

    var inputDelegate: UITextInputDelegate? {
        get { textInputDelegate }
        set { textInputDelegate = newValue }
    }
    var tokenizer: UITextInputTokenizer {
        if let t = inputTokenizer { return t }
        let t = DocumentTokenizer(canvas: self)
        inputTokenizer = t
        return t
    }

    // The first/last positions the caret can occupy must be RENDERABLE (a leaf region start/end or an
    // image gap), not the document's structural open/close token slots (0 / documentSize) — otherwise
    // "move to start/end of document" would hide the caret.
    var beginningOfDocument: UITextPosition { DocumentTextPosition(snapToRenderable(0, forward: true)) }
    var endOfDocument: UITextPosition { DocumentTextPosition(snapToRenderable(documentSize, forward: false)) }

    // Optional iOS-18 UITextInput member: tells the system the view supports editing so Writing Tools
    // can apply results in place (vs treating content as read-only). Together with our `UIEditMenuInteraction`
    // (the non-UITextInteraction path, WWDC24 #10168), this surfaces the system Writing Tools item on
    // Apple-Intelligence hardware.
    @available(iOS 18.0, *)
    var isEditable: Bool { true }

    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        guard let f = fromPosition as? DocumentTextPosition, let t = toPosition as? DocumentTextPosition else { return nil }
        return f.offset <= t.offset ? DocumentTextRange(f, t) : DocumentTextRange(t, f)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        guard let p = position as? DocumentTextPosition else { return nil }
        let n = p.offset + offset
        guard n >= 0, n <= documentSize else { return nil }
        // The system tokenizer (Option+Arrow word nav, double-tap select, …) steps through positions
        // via this primitive; snap to a renderable slot so it can never park the caret on a structural
        // token (which would be invisible). No-op for positions already renderable.
        return DocumentTextPosition(snapToRenderable(n, forward: offset >= 0))
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        let a = (position as? DocumentTextPosition)?.offset ?? 0
        let b = (other as? DocumentTextPosition)?.offset ?? 0
        return a < b ? .orderedAscending : (a > b ? .orderedDescending : .orderedSame)
    }

    func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        ((toPosition as? DocumentTextPosition)?.offset ?? 0) - ((from as? DocumentTextPosition)?.offset ?? 0)
    }

    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        guard let r = range as? DocumentTextRange else { return nil }
        return (direction == .left || direction == .up) ? r.start : r.end
    }

    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        guard let p = position as? DocumentTextPosition else { return nil }
        return (direction == .left || direction == .up)
            ? DocumentTextRange(DocumentTextPosition(0), p)
            : DocumentTextRange(p, DocumentTextPosition(documentSize))
    }

    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection { .leftToRight }
    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {}

    func firstRect(for range: UITextRange) -> CGRect {
        guard let r = range as? DocumentTextRange else { return .zero }
        return selectionRects(globalFrom: min(r.from.offset, r.to.offset),
                              globalTo: max(r.from.offset, r.to.offset)).first ?? .zero
    }

    func caretRect(for position: UITextPosition) -> CGRect {
        // A structural row/column selection hides the caret entirely (the outline is the indicator).
        // An image atom selection does NOT zero the caret here: `caretRect` must keep reporting the gap
        // geometry so the OS can run arrow-key navigation OUT of a tap-selected image — vertical arrows
        // read the caret's rect to step a line, so a `.zero` rect strands them (the reported "Up does
        // nothing / caret vanishes" bug). The VISIBLE caret is suppressed separately in `updateCaretView`
        // (the image tint is the selection indicator), so no blinking caret shows over a selected image.
        if tableSelection != nil { return .zero }
        guard let p = position as? DocumentTextPosition else { return .zero }
        let pos = clamp(p.offset)
        if let (r, local) = leafRegion(containingGlobal: pos) {
            // `emptyLineLeadingIndent`/`emptyLineHeight` only matter on an empty line, whose caret TextKit
            // would otherwise place at x=0 with a fixed 20pt height (no glyphs to carry the indent/metrics).
            return r.caretRect(atLocal: local)
                .offsetBy(dx: r.canvasOrigin.x + r.emptyLineLeadingIndent - tableContentOffsetX(forGlobal: pos),
                          dy: r.canvasOrigin.y)
        }
        // An image gap is a real caret slot but not a text leaf. Report a vertical bar at the image's
        // leading edge; `updateCaretView` renders the app's own caret there (and this geometry also feeds the
        // loupe / hit-test / edit menu). (This returned .zero before, which is why draw(_:) used to hand-draw
        // a custom GapCursor bar.)
        if let img = mediaBox(atGap: pos) {
            let rr = img.mediaRect()
            return CGRect(x: rr.minX, y: rr.minY, width: 2, height: rr.height)
        }
        return .zero
    }

    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        guard let r = range as? DocumentTextRange else { return [] }
        let rects = selectionRects(globalFrom: min(r.from.offset, r.to.offset),
                                   globalTo: max(r.from.offset, r.to.offset))
        return rects.enumerated().map { index, frame in
            DocumentSelectionRect(rect: frame, containsStart: index == 0, containsEnd: index == rects.count - 1)
        }
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
        DocumentTextPosition(closestGlobalPosition(to: point))
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        guard let p = closestPosition(to: point) as? DocumentTextPosition, let r = range as? DocumentTextRange else { return nil }
        return DocumentTextPosition(min(max(p.offset, r.from.offset), r.to.offset))
    }

    func characterRange(at point: CGPoint) -> UITextRange? {
        guard let p = closestPosition(to: point) as? DocumentTextPosition else { return nil }
        return DocumentTextRange(p, DocumentTextPosition(min(p.offset + 1, documentSize)))
    }
}

@available(iOS 13.0, *)
extension DocumentCanvasView: UIKeyInput {
    var hasText: Bool { documentSize > 0 }

    func insertText(_ text: String) {
        // A committing keystroke while composing: replace the WHOLE marked range with `text`, then
        // finalize the composition as one undo step. (The system delivers a confirming char this way.)
        if let m = markedRange {
            textInputDelegate?.textWillChange(self)
            applyReplace(globalFrom: m.from, globalTo: m.to, text: text)   // in place; caret → end
            textInputDelegate?.textDidChange(self)
            commitMarkedText()
            notifyContentSizeChanged(); setNeedsDisplay(); refreshSelectionUI()
            onSelectionChange?()   // committing a composition moves the caret — scroll it into view too
            return
        }
        clearStructuralSelections()
        // Caret on an image's gap cursor → open a new body paragraph immediately before the image
        // (Enter inserts an empty one), rather than letting the text fall into the caption. Symmetric
        // to deleteBackward's gap branch below.
        if selFrom == selTo, let img = mediaBox(atGap: head), let i = boxIndex(of: img) {
            editing { insertParagraphBeforeImage(at: i, text: text == "\n" ? "" : text) }
            return
        }
        if text == "\n" {
            if let active = activeStack(at: head), active.box is CodeBlockBox {
                // Enter on an empty trailing line of a code block EXITS it to a body paragraph (the escape
                // hatch); otherwise it inserts a literal newline (no paragraph split). A selection always
                // replaces-with-newline — only a collapsed caret can exit.
                if selFrom == selTo, caretAtCodeBlockTrailingBlankLine(active) {
                    exitCodeBlockToBodyParagraph(active)
                } else {
                    insertCodeBlockNewline()
                }
            } else {
                insertParagraphBreak()
            }
            return
        }
        if selFrom != selTo {
            editing { applySelectionReplace(globalFrom: selFrom, globalTo: selTo, text: text) }
            return
        }
        // A collapsed caret that resolves to a table box (e.g. before a leading table / after a
        // trailing table) is a structural boundary — snap it into the nearest cell so the edit goes
        // through that cell's stack, never through the table's degenerate textLayout (which would drop
        // the keystroke).
        if !isInsideTable(head), let r = resolveBox(at: head), r.box is TableBlockBox {
            let snapped = caretSnappedIntoCell(head)
            anchor = snapped; head = snapped
        }
        if isInsideTable(head) {
            // collapsed caret in a cell: text is in-place.
            editing { applyLeafReplace(globalFrom: selFrom, globalTo: selTo, text: text) }
            return
        }
        editing { applyReplace(globalFrom: selFrom, globalTo: selTo, text: text) }
    }

    /// The number of UTF-16 units the composed character sequence (grapheme cluster) immediately
    /// before the caret at global position `head` occupies. Backspace deletes this many units so a
    /// multi-unit emoji — a surrogate-pair scalar, a ZWJ sequence, a skin-tone / flag / variation-
    /// selector combo — is removed as ONE unit instead of one code unit (which would orphan the rest
    /// and render "part" of the emoji). Within a leaf region the global axis is 1:1 with UTF-16, and a
    /// grapheme never spans regions, so `head - n` stays in the same region. Returns 1 when the region
    /// can't be resolved (the safe single-unit fallback); a custom-emoji `U+FFFC` and any plain BMP
    /// character are single-unit clusters, so this is a no-op for them. Caller guarantees `local > 0`.
    func graphemeClusterLengthBeforeCaret(global head: Int) -> Int {
        guard let (region, local) = leafRegion(containingGlobal: head), local > 0 else { return 1 }
        let s = region.layout.attributedString.string as NSString
        guard local <= s.length else { return 1 }
        let r = s.rangeOfComposedCharacterSequence(at: local - 1)
        return max(1, local - r.location)
    }

    /// Expands a global range so neither endpoint sits INSIDE a composed character sequence: `from` snaps
    /// DOWN to its cluster start, `to` snaps UP to its cluster end. The OS can request a delete/replace of a
    /// PARTIAL grapheme — notably a backspace arriving as a 1-UTF-16-unit range covering only one half of a
    /// surrogate-pair emoji (`selFrom≠selTo`) — and deleting it verbatim leaves a stray code unit (a
    /// "service character"). A grapheme never spans leaf regions, so each endpoint is snapped within its own
    /// region; a range already on boundaries (the common case) is returned unchanged.
    func rangeExpandedToGraphemeBoundaries(globalFrom: Int, globalTo: Int) -> (from: Int, to: Int) {
        func snap(_ g: Int, up: Bool) -> Int {
            guard let (region, local) = leafRegion(containingGlobal: g), local > 0 else { return g }
            let s = region.layout.attributedString.string as NSString
            guard local < s.length else { return g }
            let r = s.rangeOfComposedCharacterSequence(at: local)
            guard r.location != local else { return g }   // already on a cluster boundary
            return region.globalStart + (up ? r.location + r.length : r.location)
        }
        let lo = min(globalFrom, globalTo), hi = max(globalFrom, globalTo)
        return (snap(lo, up: false), snap(hi, up: true))
    }

    func deleteBackward() {
        if markedRange != nil { commitMarkedText() }   // delete acts on committed text, not the composition
        guard !boxes.isEmpty else { return }
        if selFrom != selTo {
            editing { applySelectionReplace(globalFrom: selFrom, globalTo: selTo, text: "") }
            return
        }
        if isInsideTable(head) {
            guard let active = activeStack(at: head) else { return }
            if active.local > 0 {
                let n = graphemeClusterLengthBeforeCaret(global: head)
                editing { applyLeafReplace(globalFrom: head - n, globalTo: head, text: "") }
            } else if active.index > 0 {
                editing { mergeParagraphs(in: active.stack, upperIndex: active.index - 1) }
            } else {
                // Caret at the cell's first-paragraph start: move WITHOUT deleting to the previous text
                // position — the previous cell's end (row-major), or, at the table's FIRST cell, the end
                // of the block before the table. No-op only when the table is the document's first block
                // (nothing before — like Backspace at the very start of a document).
                let prev = prevTextPosition(before: head)
                if prev != head { setCaret(global: prev) }
            }
            return
        }
        // Caret at a media block's leading gap.
        if let img = mediaBox(atGap: head), let i = boxIndex(of: img) {
            if imageSelection != nil {
                // A tap-SELECTED media atom → delete the whole block (explicit selection delete).
                editing { deleteImageBox(at: i) }
                clearImageSelection()
            } else if i > 0, let prev = boxes[i - 1] as? BlockBox {
                // A plain caret at the gap must NOT delete the media. Act on the previous paragraph: a
                // non-empty one → move the caret to its end (no delete); an empty one → delete it (the
                // caret stays at the media's gap).
                if prev.textLength == 0 {
                    editing { deleteBlock(at: i - 1, parkingCaretAtGapOf: img) }
                } else {
                    setCaret(global: prev.textStart + prev.textLength)
                }
            } else {
                // Media is the document's first block, or the previous block isn't a paragraph (another
                // media / a table): move to the previous caret slot without deleting (no-op at doc start).
                let prev = prevTextPosition(before: head)
                if prev != head { setCaret(global: prev) }
            }
            return
        }
        guard let pos = resolveBox(at: head) else { return }
        if let p = pos.box as? BlockBox, p.style == .quote, p.textLength == 0 {
            // Backspace in an EMPTY quote un-quotes it (→ body paragraph). Otherwise an empty quote —
            // especially the document's FIRST block, which matches no merge branch below — can't be
            // removed at all. Mirrors empty-list-item Return (DocumentCanvasView+Editing.insertParagraphBreak).
            editing { p.style = .body; restyle(p); recomputeSpans() }
            return
        }
        if let codeBox = pos.box as? CodeBlockBox, codeBox.textLength == 0,
           let active = activeStack(at: head) {
            // Backspace in an EMPTY code block converts it to a body paragraph (a `CodeBlockBox` is a
            // distinct class, so it's REPLACED in its stack with a body `BlockBox`). Mirrors the empty-quote
            // branch above — without this an empty code block, especially the document's FIRST block, matches
            // no merge branch below and is undeletable.
            editing {
                let body = BlockBox(paragraph: ParagraphBlock(id: codeBox.id, style: .body, runs: []),
                                    mapper: mapper, width: effectiveWidth)
                var newBoxes = active.stack.boxes
                newBoxes.replaceSubrange(active.index...active.index, with: [body])
                active.stack.boxes = newBoxes
                recomputeSpans()
                anchor = body.textStart; head = body.textStart
            }
            return
        }
        if pos.box is MediaBlockBox, pos.local == 0 {        // caption start → delete the image
            editing { deleteImageBox(at: pos.index) }
        } else if pos.local > 0 {
            let n = graphemeClusterLengthBeforeCaret(global: head)
            editing { applyReplace(globalFrom: head - n, globalTo: head, text: "") }
        } else if pos.index > 0, boxes[pos.index - 1] is MediaBlockBox {
            editing { deleteImageBox(at: pos.index - 1) }     // start of a block after an image
        } else if pos.index > 0, boxes[pos.index - 1] is TableBlockBox {
            // Start of a block after a table → move WITHOUT deleting into the table's last cell (no merge
            // across the table boundary). Mirrors Backspace at a cell's first-paragraph start, which moves
            // to the block before. Avoids parking the caret on the table's degenerate node-start boundary.
            let prev = prevTextPosition(before: head)
            if prev != head { setCaret(global: prev) }
        } else if pos.index > 0 {
            let prev = boxes[pos.index - 1]
            let from = prev.textStart + prev.textLength
            editing { applyReplace(globalFrom: from, globalTo: head, text: "") }
        }
    }
}
#endif
