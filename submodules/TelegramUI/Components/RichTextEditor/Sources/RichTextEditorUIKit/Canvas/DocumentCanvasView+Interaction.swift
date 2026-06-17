#if canImport(UIKit)
import UIKit

@available(iOS 13.0, *)
extension DocumentCanvasView {
    func installSelectionInteractions() {
        if gestureRecognizers?.isEmpty ?? true {
            // One 1-tap recognizer that fires IMMEDIATELY on every tap; multi-tap escalation
            // (caret → word → paragraph) is counted manually in handleTap. We deliberately do NOT chain
            // `require(toFail:)` to double-/triple-tap recognizers — that gate made every caret placement
            // wait out the ~0.35s multi-tap window, which was the reported tap-to-caret latency.
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
            tap.numberOfTapsRequired = 1
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            [tap, longPress].forEach { addGestureRecognizer($0) }
            // Arbitration with the enclosing UIScrollView's pan is intentionally gate-only (see
            // gestureRecognizerShouldBegin) pending on-device verification — do NOT add require(toFail:) or
            // simultaneous recognition blind (it would let a near-handle drag both scroll and select).
            let handlePan = UIPanGestureRecognizer(target: self, action: #selector(handleSelectionHandlePan(_:)))
            handlePan.delegate = self
            addGestureRecognizer(handlePan)
            selectionHandlePan = handlePan
        }
        // iOS 16+ installs the UIEditMenuInteraction; below 16 the canvas presents via UIMenuController on
        // demand (no persistent interaction to install) — see DocumentCanvasView+EditMenu.
        if #available(iOS 16.0, *) {
            installEditMenuInteraction()
        }
        // We deliberately do NOT add a `UITextSelectionDisplayInteraction`. The canvas draws ALL of its own
        // selection visuals — the caret (`CaretView`), the selection wash (`SelectionHighlightView` on the
        // canvas + `CellSelectionView` inside a table's scroll content), and the two handle "lollipops"
        // (`SelectionHandleView`, positioned per endpoint by `updateSelectionHandleViews`) — so they ride a
        // table's horizontal scroll/overscroll. With all three roles own-drawn, the interaction is redundant.
        //
        // Worse than redundant: on iOS 18+/26 the interaction installs its OWN default selection chrome
        // (`_UITextSelectionLollipopView` ×2, `_UITextSelectionHighlightView`, `UIStandardTextCursorView`),
        // and assigning custom no-draw `handleViews`/`highlightView`/`cursorView` no longer suppresses the
        // default lollipops — they are left ORPHANED in the hierarchy at the container origin, surfacing as
        // stray handle knobs at ~CGPoint.zero alongside our own correctly-placed handles. Not creating the
        // interaction at all removes that leak at the source (confirmed live: the chrome appears iff the
        // interaction exists). Everything we still need is independent of it — the loupe
        // (`UITextLoupeSession`), the edit menu (`UIEditMenuInteraction`), and `caretRect(for:)` (which feeds
        // the loupe / hit-test / edit-menu geometry).
    }

    private func ensureFirstResponder() { if !isFirstResponder { becomeFirstResponder() } }

    /// A tap within this window AND distance of the previous one continues the multi-tap run
    /// (caret → word → paragraph); otherwise it starts a fresh count. Approximates the system double-tap.
    static let multiTapWindow: TimeInterval = 0.4
    static let multiTapSlop: CGFloat = 40

    @objc private func handleSingleTap(_ g: UITapGestureRecognizer) {
        handleTap(at: g.location(in: self), time: Date().timeIntervalSinceReferenceDate)
    }

    /// Tap handling with MANUAL multi-tap counting (split out with an explicit timestamp so it's
    /// unit-testable). A single 1-tap recognizer fires immediately on every tap, so we escalate here:
    /// the 1st tap places the caret (or toggles the menu / hits a table handle, via performSingleTap), a
    /// quick 2nd tap upgrades to a word selection, a 3rd to a paragraph. A tap outside the time/space
    /// window starts a fresh count. One handler means there is no UIKit firing-order race between separate
    /// single/double/triple recognizers — and no ~0.35s `require(toFail:)` caret-placement lag.
    func handleTap(at point: CGPoint, time now: TimeInterval) {
        // An image atom has no word/paragraph to escalate to — route EVERY tap on an image to the
        // single-tap (two-step select/menu) handler, bypassing multi-tap escalation.
        if let img = mediaBox(atGap: closestGlobalPosition(to: point)), img.mediaRect().contains(point) {
            lastTapTime = now; lastTapLocation = point; tapCount = 1
            performSingleTap(at: point)
            return
        }
        // A tap on a HIDDEN spoiler reveals it: place the caret inside the run (→ selection-revealed by the
        // reconcile) and flag the explosion from the tap point. Bypasses word/paragraph escalation.
        // Invariant: a prediction ghost sits at the caret, which is always OUTSIDE a hidden spoiler
        // (a hidden run never contains the caret — see isSpoilerRevealed), so setCaret's
        // finalizeMarkedText() can't shift `target` into an invalid position within the run.
        if let run = hiddenSpoilerRun(at: point) {
            lastTapTime = now; lastTapLocation = point; tapCount = 1
            ensureFirstResponder()
            spoilerRevealHint = (run.key, point)
            let target = min(max(closestGlobalPosition(to: point), run.globalRange.lowerBound),
                             run.globalRange.upperBound)
            setCaret(global: target)
            return
        }
        if now - lastTapTime < Self.multiTapWindow,
           hypot(point.x - lastTapLocation.x, point.y - lastTapLocation.y) < Self.multiTapSlop {
            tapCount += 1
        } else {
            tapCount = 1
        }
        lastTapTime = now
        lastTapLocation = point
        switch tapCount {
        case 1:
            performSingleTap(at: point)
        case 2:
            ensureFirstResponder()
            selectWord(at: closestGlobalPosition(to: point))
            presentEditMenu()
        default:                       // 3+ taps → paragraph
            ensureFirstResponder()
            selectParagraph(at: closestGlobalPosition(to: point))
            presentEditMenu()
        }
    }

    /// Testable core of the single-tap handler (`point` in canvas coordinates).
    func performSingleTap(at point: CGPoint) {
        let wasMenuVisible = editMenuVisible               // capture before the system auto-dismisses on touch-down
        ensureFirstResponder()
        // A tap BELOW the document's last block, when that block is a quote, starts a new body paragraph
        // after it — the only way to escape a trailing quote (nothing exists below it to tap into).
        if let last = boxes.last as? BlockBox, last.style == .quote, point.y > last.frame.maxY {
            insertEmptyBodyParagraph(at: boxes.count)   // append a body paragraph after the trailing quote
            return
        }
        if let hit = tableHandle(at: point), let action = tableHandleTap(at: point) {
            switch action {
            case .select(let kind):                        // 1st tap → select the row/column (no menu yet)
                dismissEditMenu()
                switch kind {
                case .rows(let r): selectTableRows(r)
                case .columns(let c): selectTableColumns(c)
                }
            case .menu:
                // Toggle like the text menu: tapping the already-selected handle while its menu is open
                // dismisses it instead of re-presenting (the close-then-reopen flicker).
                let justDismissed = Date().timeIntervalSinceReferenceDate - lastMenuDismissTime < Self.menuToggleSuppressWindow
                switch menuToggleAction(menuVisible: wasMenuVisible, justDismissed: justDismissed) {
                case .present: presentEditMenu(sourcePoint: hit.center)
                case .dismiss: dismissEditMenu()
                }
            }
            return
        }
        let p = closestGlobalPosition(to: point)
        // Tap on an image body (resolves to its gap AND the point is inside the image) → atom-select /
        // menu. MUST precede the clear below (else a 2nd tap on a selected image would clear it before
        // its menu could open).
        if let img = mediaBox(atGap: p), img.mediaRect().contains(point) {
            handleImageTap(img, wasMenuVisible: wasMenuVisible)
            return
        }
        clearStructuralSelections()                        // a non-handle, non-image tap clears both structural selections
        switch tapOutcome(forResolvedPosition: p) {
        case .toggleMenu:
            // Tap on the caret / inside the selection: toggle the menu, keeping the current selection.
            // The system auto-dismisses the menu on this tap's touch-down (firing willDismiss) BEFORE this
            // handler runs on tap-up, so `wasMenuVisible` is already false — `justDismissed` recognizes that
            // case and suppresses a re-present (the close-then-reopen flicker).
            let justDismissed = Date().timeIntervalSinceReferenceDate - lastMenuDismissTime < Self.menuToggleSuppressWindow
            switch menuToggleAction(menuVisible: wasMenuVisible, justDismissed: justDismissed) {
            case .present: presentEditMenu()
            case .dismiss: dismissEditMenu()
            }
        case .setCaret(let q):
            dismissEditMenu()
            setCaret(global: q)
        }
    }

    // Long press places the caret and (on release) presents the menu, with a magnifier loupe
    // (`UITextLoupeSession`, iOS 17+) tracking the caret during the drag.
    @objc private func handleLongPress(_ g: UILongPressGestureRecognizer) {
        ensureFirstResponder()
        let point = g.location(in: self)
        let p = closestGlobalPosition(to: point)
        switch g.state {
        case .began:
            dismissEditMenu()
            setCaret(global: p)
            // The magnifier loupe is iOS 17+; below it, the long-press still places the caret + (on release)
            // presents the menu — just without the magnifier.
            if #available(iOS 17.0, *) {
                loupeSession = UITextLoupeSession.begin(at: point, fromSelectionWidgetView: nil, in: self)
            }
        case .changed:
            setCaret(global: p)
            if #available(iOS 17.0, *) {
                // At an image gap caretRect(for:) is .zero; the loupe wants CGRectNull there (no caret) so it
                // tracks the touch instead of snapping toward the view origin. No real caret sits at {0,0}.
                let caret = caretRect(for: DocumentTextPosition(p))
                loupeSession?.move(to: point, withCaretRect: caret == .zero ? .null : caret,
                                   trackingCaret: caret != .zero)
            }
        case .ended, .cancelled, .failed:
            if #available(iOS 17.0, *) {
                loupeSession?.invalidate()
                loupeSession = nil
            }
            if g.state == .ended { setCaret(global: p); presentEditMenu() }
        default:
            break
        }
    }

    @objc private func handleSelectionHandlePan(_ g: UIPanGestureRecognizer) {
        let point = g.location(in: self)
        let pos = closestGlobalPosition(to: point)
        switch g.state {
        case .began:
            if tableSelection != nil, let end = tableResizeKnob(at: point) {
                draggingTableKnob = end                       // table range-knob drag
            } else {
                draggingEndpoint = nearerSelectionEndpoint(toGlobal: pos)   // text-selection handle drag
            }
        case .changed:
            if let end = draggingTableKnob {
                extendTableSelection(end: end, toward: point)
            } else if let end = draggingEndpoint {
                if end == .anchor { setSelectionAnchor(global: pos) } else { setSelectionHead(global: pos) }
                // If the head endpoint is being dragged into a scrollable table's edge zone, auto-scroll.
                updateDragAutoScroll(point: point, headInTable: end == .head && tableBox(containingGlobal: head) != nil)
            }
        case .ended, .cancelled, .failed:
            stopDragAutoScroll()
            if draggingTableKnob != nil || draggingEndpoint != nil { presentEditMenu() }
            draggingTableKnob = nil
            draggingEndpoint = nil
        default:
            break
        }
    }
}

@available(iOS 13.0, *)
extension DocumentCanvasView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        guard g === selectionHandlePan else { return true }   // only gate our handle pan; everything else passes
        return isSelectionDragTouch(g.location(in: self))
    }

    // MARK: - Gesture predicates

    /// True when a touch should begin a selection-handle / table-knob DRAG rather than a scroll. Shared by
    /// the canvas handle-pan gate (returns this) and the inner table scroll gate (begins only when this is
    /// FALSE), so a handle/knob drag always wins near a grip — gate-only, no require(toFail:).
    func isSelectionDragTouch(_ point: CGPoint) -> Bool {
        if tableSelection != nil, tableResizeKnob(at: point) != nil { return true }   // a table knob drag
        guard selFrom != selTo else { return false }          // no text selection → no handle drag → a drag scrolls
        let tol: CGFloat = 22
        let startRect = caretRect(for: DocumentTextPosition(selFrom))
        let endRect = caretRect(for: DocumentTextPosition(selTo))
        return startRect.insetBy(dx: -tol, dy: -tol).contains(point)
            || endRect.insetBy(dx: -tol, dy: -tol).contains(point)
    }
}
#endif
