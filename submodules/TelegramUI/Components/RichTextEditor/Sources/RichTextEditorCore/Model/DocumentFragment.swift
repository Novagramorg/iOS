import Foundation

// MARK: - Task 3: insertingFragment helpers

/// True for a fragment block that pastes by folding its runs INLINE into the host paragraph
/// (plain body / headings, not a list item). Quotes, list items, and code blocks paste as own block.
public func isInlineMergeable(_ block: Block) -> Bool {
    guard case .paragraph(let p) = block else { return false }
    switch p.style {
    case .body, .heading1, .heading2, .heading3: return p.list == nil
    case .quote, .caption, .pullQuote: return false
    }
}

extension Document {
    /// Returns a copy with every top-level paragraph/code block given a fresh `BlockID`
    /// (fragments only carry paragraph/code blocks, per scope).
    public func regeneratingTopLevelIDs() -> Document {
        Document(schemaVersion: schemaVersion, blocks: blocks.map { block in
            switch block {
            case .paragraph(let p):
                return .paragraph(ParagraphBlock(id: .generate(), style: p.style,
                                                 paragraph: p.paragraph, list: p.list, runs: p.runs))
            case .code(let c):
                return .code(CodeBlock(id: .generate(), language: c.language, runs: c.runs))
            case .pullQuote(let pq):
                return .pullQuote(PullQuote(id: .generate(), runs: pq.runs))
            default:
                return block
            }
        })
    }

    /// Splices `fragment` into this document at the global caret. Returns the new document and the
    /// caret position at the end of the pasted content, or nil if `caret` is not in a top-level
    /// paragraph/code text region (caller falls back to a plain insert).
    public func insertingFragment(_ fragment: Document, atGlobal caret: Int) -> (document: Document, caret: Int)? {
        let frag = fragment.regeneratingTopLevelIDs().blocks
        guard let locus = topLevelTextLocus(globalCaret: caret) else { return nil }
        guard !frag.isEmpty else { return (self, caret) }
        var newBlocks = blocks

        // Destination is a code block → flatten the fragment to text and insert inline.
        if case .code(let host) = blocks[locus.index] {
            let inserted = frag.map(blockPlainText).joined(separator: "\n")
            let runs = insertingText(inserted, into: host.runs, atUTF16: locus.local)
            newBlocks[locus.index] = .code(CodeBlock(id: host.id, language: host.language, runs: runs))
            return (Document(schemaVersion: schemaVersion, blocks: newBlocks),
                    caret + (inserted as NSString).length)
        }

        guard case .paragraph(let host) = blocks[locus.index] else { return nil }
        let (headHalf, tailHalf) = host.split(at: locus.local, newID: .generate())

        // Single inline-mergeable paragraph → fold its runs into the host paragraph.
        if frag.count == 1, isInlineMergeable(frag[0]), case .paragraph(let only) = frag[0] {
            let merged = ParagraphBlock(id: host.id, style: host.style, paragraph: host.paragraph,
                                        list: host.list, runs: headHalf.runs + only.runs + tailHalf.runs)
            newBlocks[locus.index] = .paragraph(merged)
            return (Document(schemaVersion: schemaVersion, blocks: newBlocks), caret + only.utf16Count)
        }

        // Multi-block (or a single non-inline block): split host, merge inline-compatible ends.
        var middle = frag
        var headBlock = Block.paragraph(headHalf)
        var tailPara = ParagraphBlock(id: .generate(), style: host.style, paragraph: host.paragraph,
                                      list: host.list, runs: tailHalf.runs)
        var caretInTail = 0

        if let first = middle.first, isInlineMergeable(first), case .paragraph(let fp) = first {
            headBlock = .paragraph(headHalf.merging(fp))
            middle.removeFirst()
        }
        if let last = middle.last, isInlineMergeable(last), case .paragraph(let lp) = last {
            tailPara = ParagraphBlock(id: tailPara.id, style: tailPara.style, paragraph: tailPara.paragraph,
                                      list: tailPara.list, runs: lp.runs + tailPara.runs)
            caretInTail = lp.utf16Count
            middle.removeLast()
        }

        var assembled = [headBlock] + middle + [Block.paragraph(tailPara)]
        // The empty halves of the split host that no pasted block merged into would be spurious blank lines
        // around the paste (most visible: pasting a list / quote / code — non-inline-mergeable — at a
        // paragraph end leaves a trailing empty paragraph; at a paragraph start, a leading one). These are
        // EXACTLY `headBlock`/`tailPara` — the split halves — so dropping is keyed on emptiness of the
        // OUTERMOST block only, never a pasted fragment block (those sit in `middle`, and even when a single
        // fragment block inline-merges into a split half it folds INTO `headBlock`/`tailPara`, so the merged
        // result is what's tested). Drop a trailing and/or leading empty paragraph as long as content remains.
        // "Empty" is text-emptiness (`text.isEmpty`) — a paragraph may carry either no runs or one zero-length
        // run; both must be treated as a blank line. A non-empty tail (mid-paragraph paste) and interior empty
        // paragraphs within the fragment (which live in `middle`, not at an end) are untouched.
        let tailDropped = { () -> Bool in
            if case .paragraph(let t) = assembled.last, t.text.isEmpty, assembled.count > 1 {
                assembled.removeLast(); return true
            }
            return false
        }()
        if case .paragraph(let h) = assembled.first, h.text.isEmpty, assembled.count > 1 {
            assembled.removeFirst()
        }
        newBlocks.replaceSubrange(locus.index...locus.index, with: assembled)
        let newDoc = Document(schemaVersion: schemaVersion, blocks: newBlocks)
        // `lastIndex` is computed AFTER both removals so a leading drop doesn't skew it.
        let lastIndex = locus.index + assembled.count - 1
        let caretPos: Int
        if tailDropped {
            // The empty host-tail was dropped → the caret goes to the END of the new last block (the last
            // pasted block); `caretInTail` (0 here, since the tail wasn't inline-merged) no longer applies.
            let lastLen: Int
            switch assembled.last! {
            case .paragraph(let p): lastLen = p.utf16Count
            case .code(let c): lastLen = c.utf16Count
            case .pullQuote(let pq): lastLen = pq.utf16Count
            default: lastLen = 0
            }
            caretPos = newDoc.globalTextStart(ofBlockAt: lastIndex) + lastLen
        } else {
            // The tail survived (real content after the caret, or an inline-merged tail) → keep the original target.
            caretPos = newDoc.globalTextStart(ofBlockAt: lastIndex) + caretInTail
        }
        return (newDoc, caretPos)
    }
}

/// Plain text of a paragraph/code block (empty for media/table). Used for the code-destination flatten.
public func blockPlainText(_ block: Block) -> String {
    switch block {
    case .paragraph(let p): return p.text
    case .code(let c): return c.text
    case .pullQuote(let pq): return pq.text
    default: return ""
    }
}

extension Document {
    /// The (top-level block index, local UTF-16 offset) for a global caret landing in a top-level
    /// paragraph or code block. nil when the caret is inside a table cell / media caption / non-text slot.
    public func topLevelTextLocus(globalCaret caret: Int) -> (index: Int, local: Int)? {
        var cursor = 0
        for i in blocks.indices {
            let size = DocumentTree.documentSize(Document(blocks: [blocks[i]]))
            let textStart = cursor + 1
            switch blocks[i] {
            case .paragraph(let p):
                if caret >= textStart && caret <= textStart + p.utf16Count { return (i, caret - textStart) }
            case .code(let c):
                if caret >= textStart && caret <= textStart + c.utf16Count { return (i, caret - textStart) }
            default: break
            }
            cursor += size
        }
        return nil
    }

    /// The global position of the first editable text offset of the top-level block at `index`.
    public func globalTextStart(ofBlockAt index: Int) -> Int {
        DocumentTree.documentSize(Document(blocks: Array(blocks[..<index]))) + 1
    }

    /// A sub-`Document` of the selection `[lo, hi)`. Paragraph and code blocks are copied (boundary
    /// blocks truncated to the covered runs); **media and table blocks are skipped** (Phase 5d scope).
    /// All block IDs are freshly generated.
    public func extractFragment(globalFrom lo: Int, globalTo hi: Int) -> Document {
        guard lo < hi else { return Document(blocks: []) }
        var out: [Block] = []
        var cursor = 0
        for block in blocks {
            let size = DocumentTree.documentSize(Document(blocks: [block]))
            let textStart = cursor + 1
            switch block {
            case .paragraph(let p):
                let a = max(lo, textStart), b = min(hi, textStart + p.utf16Count)
                if a < b || (p.utf16Count == 0 && lo <= textStart && hi > textStart) {
                    let r = sliceRuns(p.runs, fromUTF16: max(0, a - textStart), toUTF16: max(0, b - textStart))
                    out.append(.paragraph(ParagraphBlock(id: .generate(), style: p.style,
                                                          paragraph: p.paragraph, list: p.list, runs: r)))
                }
            case .code(let c):
                let a = max(lo, textStart), b = min(hi, textStart + c.utf16Count)
                if a < b {
                    let r = sliceRuns(c.runs, fromUTF16: a - textStart, toUTF16: b - textStart)
                    out.append(.code(CodeBlock(id: .generate(), language: c.language, runs: r)))
                }
                // Note: empty code blocks (utf16Count == 0) are intentionally not captured — they
                // carry no content and are meaningless to paste (asymmetric with empty paragraphs,
                // which preserve the blank line's structure on intra-document paste).
            case .pullQuote(let pq):
                let a = max(lo, textStart), b = min(hi, textStart + pq.utf16Count)
                if a < b {
                    let r = sliceRuns(pq.runs, fromUTF16: a - textStart, toUTF16: b - textStart)
                    out.append(.pullQuote(PullQuote(id: .generate(), runs: r)))
                }
            default:
                break   // media/table not carried in a fragment
            }
            cursor += size
        }
        return Document(blocks: out)
    }
}
