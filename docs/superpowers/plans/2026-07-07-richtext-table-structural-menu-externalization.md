# Externalize the Table Structural Menu to a Host ContextController — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the editor's in-package `UIMenu`/`UIEditMenuInteraction` table row/column structural menu with a framework-agnostic descriptor the editor hands to its host, which presents its own Telegram `ContextController`.

**Architecture:** The editor (RichTextEditorUIKit) builds a `TableStructuralMenuRequest` (anchor view + rect + semantic actions + alignment callback) and fires a host closure `onRequestTableStructuralMenu`. A single shared helper `presentTableStructuralMenu(...)` in `ChatRichTextEditorComposer` maps that descriptor to `ContextController` items and presents it; both hosts (the attachment screen and the chat composer) call the helper, injecting only their own present-controller closure.

**Tech Stack:** Swift, UIKit, Bazel (full-app build), SwiftPM (editor package unit tests), ContextUI, TelegramPresentationData.

## Global Constraints

- **iOS floor 13.0.** New public types/methods are `@available(iOS 13.0, *)` (the UIKit target's floor). The ContextController path is NOT iOS-16-gated (unlike the existing `contextMenuItemsProvider`).
- **`-warnings-as-errors`** on every submodule BUILD: no unused vars/bindings, no always-false `is`/`as?`. Removing `hit.center`'s only use means the `hit` binding must go too.
- **The editor package (`RichTextEditor`) must NOT import ContextUI / Display / AccountContext / TelegramUI.** The descriptor references only UIKit + `RichTextEditorCore`. All ContextUI mapping lives host-side.
- **No isolated build for UIKit-dependent Bazel libs** (bare `bazel build //…:Lib` fails: `UIKit/UIKit.h not found`). Host-side modules (Tasks 3–5) are compile-verified only by the **full app build** in Task 6.
- **Editor unit tests run via SwiftPM on the simulator**, not Bazel: `Scripts/iostest.sh` with `DEVICE="iPhone 17 Pro K3"` (the dedicated K-sims — the shared default `iPhone 17 Pro` is ambiguous and hangs/flakes).
- **Full app build** is the only supported Bazel build (`Telegram/Telegram`, `debug_sim_arm64`); prefix with `source ~/.zshrc 2>/dev/null;` for the codesigning password.
- Commit messages end with the `Co-Authored-By: Claude …` / `Claude-Session:` trailers (repo convention).

---

## File Structure

- **Create** `submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/TableStructuralMenuRequest.swift` — the framework-agnostic descriptor (value/reference types only, no behavior).
- **Modify** `…/RichTextEditorUIKit/Canvas/DocumentCanvasView.swift` — add the `onRequestTableStructuralMenu` stored hook.
- **Modify** `…/RichTextEditorUIKit/Canvas/DocumentCanvasView+TableControls.swift` — add `tableStructuralMenuRequest()` + `structuralPerform`; remove `structuralMenu()` + `structuralAction`.
- **Modify** `…/RichTextEditorUIKit/Canvas/DocumentCanvasView+Interaction.swift` — route the `.menu` tap to the hook.
- **Modify** `…/RichTextEditorUIKit/Canvas/DocumentCanvasView+EditMenuActions.swift` — drop the `tableSelection` branch from `editMenuInteraction(menuFor:)`.
- **Modify** `…/RichTextEditorUIKit/RichTextEditorView.swift` — public facade hook.
- **Modify** `…/Tests/RichTextEditorUIKitTests/TableControlsTests.swift` — migrate menu tests to the descriptor.
- **Create** `submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer/Sources/TableStructuralMenuPresentation.swift` — the shared helper + reference source.
- **Modify** `…/ChatRichTextEditorComposer/BUILD` — add `ContextUI` + `TelegramPresentationData` deps.
- **Modify** `…/ChatRichTextEditorComposer/Sources/RichTextEditorChatInputNode.swift` — forward the hook.
- **Modify** `submodules/TelegramUI/Components/RichTextAttachmentScreen/Sources/RichTextAttachmentScreen.swift` — wire the attachment host.
- **Modify** `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift` — wire the composer host.

---

### Task 1: Descriptor type + builder + facade hook (editor side, additive)

Adds the descriptor, the `tableStructuralMenuRequest()` builder, and the facade hook. Purely additive — `structuralMenu()` still exists and is still used by production until Task 2. Migrates the existing menu unit tests to the descriptor.

**Files:**
- Create: `submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/TableStructuralMenuRequest.swift`
- Modify: `submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView.swift:294`
- Modify: `submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+TableControls.swift`
- Modify: `submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/RichTextEditorView.swift:156`
- Test: `submodules/TelegramUI/Components/RichTextEditor/Tests/RichTextEditorUIKitTests/TableControlsTests.swift`

**Interfaces:**
- Produces:
  - `public final class TableStructuralMenuRequest` with `weak var view: UIView?`, `let sourceRect: CGRect`, `let actions: [Action]`, `let alignment: Alignment?`.
  - `TableStructuralMenuRequest.Action { let kind: Kind; let perform: () -> Void }`.
  - `TableStructuralMenuRequest.Kind: Equatable` = `addColumnLeft, addColumnRight, deleteColumn, addRowAbove, addRowBelow, deleteRow`.
  - `TableStructuralMenuRequest.Alignment { let options: [TextAlignment]; let current: TextAlignment?; let select: (TextAlignment) -> Void }`.
  - `DocumentCanvasView.tableStructuralMenuRequest() -> TableStructuralMenuRequest?` (internal).
  - `DocumentCanvasView.onRequestTableStructuralMenu: ((TableStructuralMenuRequest) -> Void)?` (internal stored).
  - `RichTextEditorView.onRequestTableStructuralMenu: ((TableStructuralMenuRequest) -> Void)?` (public).

- [ ] **Step 1: Write the descriptor file**

Create `TableStructuralMenuRequest.swift`:

```swift
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
```

- [ ] **Step 2: Add the canvas stored hook**

In `DocumentCanvasView.swift`, immediately after the `hostContextMenuItemsProvider` declaration (line 294), add:

```swift
    /// Host hook for the table row/column structural menu. Fired from the `.menu` handle-tap case with a
    /// framework-agnostic description; the host presents its own ContextController. nil ⇒ no menu shown.
    var onRequestTableStructuralMenu: ((TableStructuralMenuRequest) -> Void)?
```

- [ ] **Step 3: Add the builder + `structuralPerform` in `DocumentCanvasView+TableControls.swift`**

Add these two methods to the extension (e.g. directly above the existing `structuralMenu()`; leave `structuralMenu`/`structuralAction` in place for now):

```swift
    /// The closure form of `structuralAction`: run a structural command, then clear the selection.
    private func structuralPerform(_ run: @escaping (DocumentCanvasView) -> Void) -> () -> Void {
        { [weak self] in guard let self else { return }; run(self); self.clearTableSelection() }
    }

    /// The structural row/column menu, described for the host to present its own menu (replaces the
    /// `UIMenu`-building `structuralMenu()`). nil when there is no structural selection. `view`/`sourceRect`
    /// anchor to the active handle, in canvas coordinates. Same state adaptation as `structuralMenu()`.
    func tableStructuralMenuRequest() -> TableStructuralMenuRequest? {
        guard let sel = tableSelection, let a = activeTable(), a.box.id == sel.table else { return nil }
        let sourceRect = tableHandles().first { $0.kind == sel.kind }?.rect ?? .zero
        switch sel.kind {
        case .columns(let range):
            var actions: [TableStructuralMenuRequest.Action] = [
                .init(kind: .addColumnLeft, perform: structuralPerform { $0.insertTableColumnLeft() }),
                .init(kind: .addColumnRight, perform: structuralPerform { $0.insertTableColumnRight() }),
            ]
            // Hide Delete when the range covers every column (deleting all would empty the table).
            let coversAll = range.lowerBound == 0 && range.upperBound == a.box.columnCount - 1
            if !coversAll {
                actions.append(.init(kind: .deleteColumn, perform: structuralPerform { $0.deleteTableColumn() }))
            }
            let current = a.box.columns.indices.contains(range.lowerBound) ? a.box.columns[range.lowerBound].alignment : nil
            let alignment = TableStructuralMenuRequest.Alignment(
                options: [.left, .center, .right],
                current: current,
                select: { [weak self] al in guard let self else { return }; self.setTableColumnAlignment(al); self.clearTableSelection() })
            return TableStructuralMenuRequest(view: self, sourceRect: sourceRect, actions: actions, alignment: alignment)
        case .rows(let range):
            let includesHeader = range.contains { a.box.isHeaderRow($0) }
            let hasBodyRow = range.contains { a.box.cells.indices.contains($0) && !a.box.isHeaderRow($0) }
            var actions: [TableStructuralMenuRequest.Action] = []
            if !includesHeader {                       // can't insert above the header
                actions.append(.init(kind: .addRowAbove, perform: structuralPerform { $0.insertTableRowAbove() }))
            }
            actions.append(.init(kind: .addRowBelow, perform: structuralPerform { $0.insertTableRowBelow() }))
            if hasBodyRow {                             // at least one deletable (non-header) row
                actions.append(.init(kind: .deleteRow, perform: structuralPerform { $0.deleteTableRow() }))
            }
            return TableStructuralMenuRequest(view: self, sourceRect: sourceRect, actions: actions, alignment: nil)
        }
    }
```

- [ ] **Step 4: Add the public facade hook in `RichTextEditorView.swift`**

Immediately after the `contextMenuItemsProvider` computed property (ends at line 156), add:

```swift
    /// The editor's table row/column structural menu, handed to the host to present its own menu (a
    /// ContextController) anchored to the tapped handle. Fired when the user taps an already-selected table
    /// handle. The editor builds WHAT the menu contains; the host owns presentation. Unset ⇒ no menu.
    public var onRequestTableStructuralMenu: ((TableStructuralMenuRequest) -> Void)? {
        get { canvas.onRequestTableStructuralMenu }
        set { canvas.onRequestTableStructuralMenu = newValue }
    }
```

- [ ] **Step 5: Migrate the menu unit tests to the descriptor**

In `TableControlsTests.swift`, replace the `actionTitles` helper (lines 129–136) with a kind-based helper:

```swift
    func actionKinds(_ req: TableStructuralMenuRequest?) -> [TableStructuralMenuRequest.Kind] {
        req?.actions.map { $0.kind } ?? []
    }
```

Then rewrite the four menu tests (lines 138–179) to:

```swift
    func test_columnMenu_hasAddDeleteAlign() {
        let v = canvasWithTable()
        let t = table(v)
        v.head = t.cellTextStart(row: 1, column: 0)!; v.anchor = v.head
        v.selectTableColumn(1)
        let req = v.tableStructuralMenuRequest()
        let kinds = actionKinds(req)
        XCTAssertEqual(kinds.filter { $0 == .addColumnLeft || $0 == .addColumnRight }.count, 2)
        XCTAssertTrue(kinds.contains(.deleteColumn))
        XCTAssertEqual(req?.alignment?.options, [.left, .center, .right])
    }

    func test_rowMenu_headerOmitsDeleteAndAddAbove() {
        let v = canvasWithTable()
        let t = table(v)
        v.head = t.cellTextStart(row: 0, column: 0)!; v.anchor = v.head
        v.selectTableRow(0)                       // header row
        let kinds = actionKinds(v.tableStructuralMenuRequest())
        XCTAssertFalse(kinds.contains(.deleteRow))
        XCTAssertFalse(kinds.contains(.addRowAbove))
        XCTAssertTrue(kinds.contains(.addRowBelow))
    }

    func test_rowMenu_bodyHasAllRowActions() {
        let v = canvasWithTable()
        let t = table(v)
        v.head = t.cellTextStart(row: 1, column: 0)!; v.anchor = v.head
        v.selectTableRow(1)
        let kinds = actionKinds(v.tableStructuralMenuRequest())
        XCTAssertTrue(kinds.contains(.addRowAbove) && kinds.contains(.addRowBelow) && kinds.contains(.deleteRow))
    }

    func test_columnMenu_singleColumnOmitsDelete() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 200)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a","Only")]),
                   Row(id: BlockID("r1"), cells: [cell("b","x")])]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 400); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        v.head = t.cellTextStart(row: 1, column: 0)!; v.anchor = v.head
        v.selectTableColumn(0)
        XCTAssertFalse(actionKinds(v.tableStructuralMenuRequest()).contains(.deleteColumn))
    }
```

Also update the section marker comment (line 127) from `// MARK: - structuralMenu tests (Task 3)` to `// MARK: - tableStructuralMenuRequest tests`.

Then rewrite the two title/pluralization tests further down (lines 475–492). Replace `test_menu_pluralizes_andHidesDeleteWhenAllColumns` (475–483) — pluralization is gone, so it becomes just the delete-visibility test — and `test_menu_rowRangeIncludingHeader_hidesAddAbove_keepsDeleteRows` (485–492):

```swift
    func test_menu_hidesDeleteWhenAllColumns() {
        let v = canvasWithTable(); let t = table(v)
        v.head = t.cellTextStart(row: 0, column: 0)!; v.anchor = v.head
        v.selectTableColumns(0...1)                                   // multi-column, not all → delete shown
        XCTAssertTrue(actionKinds(v.tableStructuralMenuRequest()).contains(.deleteColumn))
        v.selectTableColumns(0...2)                                   // all 3 columns → no delete
        XCTAssertFalse(actionKinds(v.tableStructuralMenuRequest()).contains(.deleteColumn))
    }

    func test_menu_rowRangeIncludingHeader_hidesAddAbove_keepsDeleteRows() {
        let v = canvasWithTable(); let t = table(v)
        v.head = t.cellTextStart(row: 0, column: 0)!; v.anchor = v.head
        v.selectTableRows(0...1)                                       // header + body row
        let kinds = actionKinds(v.tableStructuralMenuRequest())
        XCTAssertFalse(kinds.contains(.addRowAbove))                  // range includes the header
        XCTAssertTrue(kinds.contains(.deleteRow))                     // body row(s) deletable → shown
    }
```

This removes the last references to `actionTitles`/`structuralMenu()` in the test file (grep to confirm none remain: `grep -n 'actionTitles\|structuralMenu' TableControlsTests.swift` should be empty).

- [ ] **Step 6: Run the tests to verify they pass**

Run:

```bash
cd /Users/isaac/build/telegram/telegram-ios/submodules/TelegramUI/Components/RichTextEditor
DEVICE="iPhone 17 Pro K3" Scripts/iostest.sh TableControlsTests
```

Expected: `TableControlsTests` compiles and passes (the migrated menu tests + the pre-existing tap/selection tests). If the destination-name lookup hangs, boot the K3 sim and re-run with `-destination 'platform=iOS Simulator,id=<K3-UDID>'` per the known iostest hang.

- [ ] **Step 7: Commit**

```bash
cd /Users/isaac/build/telegram/telegram-ios
git add submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/TableStructuralMenuRequest.swift \
        submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView.swift \
        submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+TableControls.swift \
        submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/RichTextEditorView.swift \
        submodules/TelegramUI/Components/RichTextEditor/Tests/RichTextEditorUIKitTests/TableControlsTests.swift
git commit -m "feat(richtext): table structural menu descriptor + builder + facade hook"
```

---

### Task 2: Route the tap to the hook; remove the in-editor UIMenu

Switches the `.menu` handle-tap to fire the host hook, removes the `UIEditMenuInteraction` structural branch, and deletes `structuralMenu()` + `structuralAction`. Adds an integration test that the hook fires with the right request.

**Files:**
- Modify: `…/RichTextEditorUIKit/Canvas/DocumentCanvasView+Interaction.swift:247-265`
- Modify: `…/RichTextEditorUIKit/Canvas/DocumentCanvasView+EditMenuActions.swift:20`
- Modify: `…/RichTextEditorUIKit/Canvas/DocumentCanvasView+TableControls.swift` (delete `structuralAction` + `structuralMenu`)
- Test: `…/Tests/RichTextEditorUIKitTests/TableControlsTests.swift`

**Interfaces:**
- Consumes: `tableStructuralMenuRequest()`, `onRequestTableStructuralMenu` (Task 1).
- Produces: no new symbols; removes `structuralMenu()` and `structuralAction(_:)`.

- [ ] **Step 1: Write the failing integration test**

Add to `TableControlsTests.swift` (in the tap-handle test section, near line 181):

```swift
    func test_tapSelectedColumnHandle_firesStructuralMenuRequest() {
        let v = canvasWithTable()
        let t = table(v)
        v.anchor = t.cellTextStart(row: 1, column: 2)!; v.head = v.anchor
        v.selectTableColumn(2)                                   // 1st: select column 2
        var received: TableStructuralMenuRequest?
        v.onRequestTableStructuralMenu = { received = $0 }
        let colHandle = v.tableHandles().first { $0.kind == .columns(2...2) }!.rect
        v.performSingleTap(at: CGPoint(x: colHandle.midX, y: colHandle.midY))   // 2nd: tap selected handle → menu
        XCTAssertNotNil(received)
        XCTAssertTrue(received?.view === v)
        XCTAssertEqual(received?.sourceRect, colHandle)
        XCTAssertTrue((received?.actions.map { $0.kind } ?? []).contains(.deleteColumn))
    }
```

- [ ] **Step 2: Run it to verify it fails**

Run:

```bash
cd /Users/isaac/build/telegram/telegram-ios/submodules/TelegramUI/Components/RichTextEditor
DEVICE="iPhone 17 Pro K3" Scripts/iostest.sh TableControlsTests
```

Expected: `test_tapSelectedColumnHandle_firesStructuralMenuRequest` FAILS (`received` is nil — the `.menu` case still calls `presentEditMenu(sourcePoint:)`, not the hook).

- [ ] **Step 3: Route the `.menu` tap to the hook**

In `DocumentCanvasView+Interaction.swift`, replace the whole table-handle block (lines 247–265):

```swift
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
                switch menuToggleAction(menuVisible: wasMenuVisible, justDismissed: justDismissed, wasFirstResponder: wasFirstResponder) {
                case .present: presentEditMenu(sourcePoint: hit.center)
                case .dismiss: dismissEditMenu()
                }
            }
            return
        }
```

with (drops the now-unused `hit` binding — required under `-warnings-as-errors`):

```swift
        if let action = tableHandleTap(at: point) {
            switch action {
            case .select(let kind):                        // 1st tap → select the row/column (no menu yet)
                dismissEditMenu()
                switch kind {
                case .rows(let r): selectTableRows(r)
                case .columns(let c): selectTableColumns(c)
                }
            case .menu:
                // 2nd tap on the already-selected handle → ask the host to present the structural menu.
                // Presentation (and any toggle-to-dismiss) is the host's concern now — see the design spec.
                if let request = tableStructuralMenuRequest() {
                    onRequestTableStructuralMenu?(request)
                }
            }
            return
        }
```

- [ ] **Step 4: Drop the `UIEditMenuInteraction` structural branch**

In `DocumentCanvasView+EditMenuActions.swift`, delete line 20:

```swift
        if tableSelection != nil { return structuralMenu() }   // table row/column actions — system suggestedActions (Cut/Copy/Paste) are irrelevant to a structural pick
```

(The structural menu no longer rides `UIEditMenuInteraction`, so this delegate is never consulted for it. The `imageSelection` branch and the rest of the method are unchanged.)

- [ ] **Step 5: Delete `structuralMenu()` and `structuralAction`**

In `DocumentCanvasView+TableControls.swift`, delete the `structuralAction(_:)` helper (lines 282–285) and the entire `structuralMenu() -> UIMenu?` method (lines 287–327). Keep `structuralPerform` and `tableStructuralMenuRequest()` from Task 1.

- [ ] **Step 6: Run the tests to verify they pass**

Run:

```bash
cd /Users/isaac/build/telegram/telegram-ios/submodules/TelegramUI/Components/RichTextEditor
DEVICE="iPhone 17 Pro K3" Scripts/iostest.sh TableControlsTests
```

Expected: all `TableControlsTests` pass, including `test_tapSelectedColumnHandle_firesStructuralMenuRequest` (the hook now fires; `received` is non-nil with `view === v`, `sourceRect == colHandle`, and `.deleteColumn` present).

- [ ] **Step 7: Commit**

```bash
cd /Users/isaac/build/telegram/telegram-ios
git add submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+Interaction.swift \
        submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+EditMenuActions.swift \
        submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+TableControls.swift \
        submodules/TelegramUI/Components/RichTextEditor/Tests/RichTextEditorUIKitTests/TableControlsTests.swift
git commit -m "feat(richtext): fire host hook for table structural menu; remove in-editor UIMenu"
```

---

### Task 3: Shared presentation helper in `ChatRichTextEditorComposer`

Adds the ContextUI-side mapping + presentation, shared by both hosts. No unit test (Bazel module, no test target); compile-verified by the full app build in Task 6.

**Files:**
- Create: `submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer/Sources/TableStructuralMenuPresentation.swift`
- Modify: `submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer/BUILD`

**Interfaces:**
- Consumes: `TableStructuralMenuRequest` (Task 1, via `import RichTextEditorUIKit`).
- Produces: `public func presentTableStructuralMenu(_ request: TableStructuralMenuRequest, presentationData: PresentationData, present: (ViewController) -> Void)`.

- [ ] **Step 1: Add the Bazel deps**

In `ChatRichTextEditorComposer/BUILD`, add these two entries to the `deps` list (alphabetical-ish, next to the other `//submodules/...` entries):

```python
        "//submodules/ContextUI",
        "//submodules/TelegramPresentationData",
```

- [ ] **Step 2: Write the helper file**

Create `TableStructuralMenuPresentation.swift`:

```swift
import Foundation
import UIKit
import Display
import ContextUI
import TelegramPresentationData
import RichTextEditorCore
import RichTextEditorUIKit

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

    let items: [ContextMenuItem] = request.actions.map { action in
        .action(ContextMenuActionItem(
            text: tableStructuralMenuTitle(action.kind),
            textColor: tableStructuralMenuIsDestructive(action.kind) ? .destructive : .primary,
            icon: { _ in nil },
            action: { _, f in f(.default); action.perform() }
        ))
    }
    // NOTE: request.alignment (column selections) is intentionally NOT rendered yet — it will become a
    // .custom segmented ContextMenu item. The descriptor already carries options + `select` for that.

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
```

- [ ] **Step 3: Commit**

```bash
cd /Users/isaac/build/telegram/telegram-ios
git add submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer/Sources/TableStructuralMenuPresentation.swift \
        submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer/BUILD
git commit -m "feat(richtext): shared ContextController presenter for the table structural menu"
```

(Compile verification is deferred to Task 6's full app build — no isolated build exists for this UIKit-dependent Bazel module.)

---

### Task 4: Wire the attachment-screen host

**Files:**
- Modify: `submodules/TelegramUI/Components/RichTextAttachmentScreen/Sources/RichTextAttachmentScreen.swift` (one-time editor config block, after line 423)

**Interfaces:**
- Consumes: `RichTextEditorView.onRequestTableStructuralMenu` (Task 1), `presentTableStructuralMenu(...)` (Task 3). Both modules are already imported (`RichTextEditorUIKit`, `ChatRichTextEditorComposer`).

- [ ] **Step 1: Add the wiring in the one-time config block**

In `RichTextAttachmentScreen.swift`, directly after the `editor.configureSelectionHandleView = { … }` block (which ends at line 423) and before `editor.disablesInteractiveTransitionGestureRecognizer = true` (line 424), insert:

```swift
                // Table row/column structural menu: the editor hands us a framework-agnostic descriptor; we
                // present it as a ContextController anchored to the tapped handle (in the editor's canvas).
                editor.onRequestTableStructuralMenu = { [weak self] request in
                    guard let self, let component = self.component else { return }
                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                    presentTableStructuralMenu(request, presentationData: presentationData) { [weak self] controller in
                        self?.environment?.controller()?.presentInGlobalOverlay(controller)
                    }
                }
```

- [ ] **Step 2: Commit**

```bash
cd /Users/isaac/build/telegram/telegram-ios
git add submodules/TelegramUI/Components/RichTextAttachmentScreen/Sources/RichTextAttachmentScreen.swift
git commit -m "feat(richtext): wire attachment screen to present the table structural menu"
```

(Compile verification deferred to Task 6.)

---

### Task 5: Wire the chat-composer host

**Files:**
- Modify: `submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer/Sources/RichTextEditorChatInputNode.swift` (after line 542)
- Modify: `submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift` (after line 1142/1144)

**Interfaces:**
- Consumes: `RichTextEditorView.onRequestTableStructuralMenu` (Task 1), `presentTableStructuralMenu(...)` (Task 3).
- Produces: `RichTextEditorChatInputNode.onRequestTableStructuralMenu: ((TableStructuralMenuRequest) -> Void)?` (public, forwards to `editorView`).

- [ ] **Step 1: Forward the hook on `RichTextEditorChatInputNode`**

In `RichTextEditorChatInputNode.swift`, immediately after the `contextMenuItemsProvider` computed property (ends at line 542), add:

```swift
    public var onRequestTableStructuralMenu: ((TableStructuralMenuRequest) -> Void)? {
        get { self.editorView.onRequestTableStructuralMenu }
        set { self.editorView.onRequestTableStructuralMenu = newValue }
    }
```

(`TableStructuralMenuRequest` is already in scope via `import RichTextEditorUIKit`.)

- [ ] **Step 2: Wire presentation in `ChatTextInputPanelNode`**

In `ChatTextInputPanelNode.swift`, after the `richTextInputNode.onPasteMedia = …` line (line 1144), insert (NOT inside the `#available(iOS 16.0, *)` block — the ContextController path is iOS 13+):

```swift
        richTextInputNode.onRequestTableStructuralMenu = { [weak self] request in
            guard let self, let context = self.context else { return }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentTableStructuralMenu(request, presentationData: presentationData) { [weak self] controller in
                self?.interfaceInteraction?.presentGlobalOverlayController(controller, nil)
            }
        }
```

- [ ] **Step 3: Commit**

```bash
cd /Users/isaac/build/telegram/telegram-ios
git add submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer/Sources/RichTextEditorChatInputNode.swift \
        submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift
git commit -m "feat(richtext): wire chat composer to present the table structural menu"
```

(Compile verification deferred to Task 6.)

---

### Task 6: Full app build + runtime verification (both hosts)

The integration gate for Tasks 3–5 (which have no isolated build) plus runtime confirmation the menu presents.

**Files:** none (build + manual verification).

- [ ] **Step 1: Full app build**

Run (from the repo root; capture the real exit code — this is a long build, run it yourself, not via a backgrounded subagent):

```bash
cd /Users/isaac/build/telegram/telegram-ios
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion \
 --cacheDir ~/telegram-bazel-cache \
 build \
 --configurationPath build-system/appstore-configuration.json \
 --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
 --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 --configuration=debug_sim_arm64
```

Expected: build succeeds. If it fails, fix compile errors in Tasks 3–5 (common: a wrong `ContextMenuActionItem` label, a missing dep, or `presentGlobalOverlayController` arity) and rebuild.

- [ ] **Step 2: Install the fresh build on the K3 simulator (whole-`.app` copy)**

```bash
cd /Users/isaac/build/telegram/telegram-ios
K3=FA6F7462-AA97-42FE-9E57-8DA0593CE756
BUNDLE=ph.telegra.Telegraph
SRC="$(find -L bazel-out -maxdepth 14 -path '*/Telegram_archive-root/Payload/Telegram.app' -type d | head -1)"
DEST="$(xcrun simctl get_app_container "$K3" "$BUNDLE" app)"
[ -x "$SRC/Telegram" ] || { echo "no fresh bundle at SRC=$SRC — aborting"; exit 1; }
xcrun simctl terminate "$K3" "$BUNDLE" 2>/dev/null
rm -rf "$DEST" && cp -Rp "$SRC" "$DEST"
xcrun simctl launch "$K3" "$BUNDLE"
```

- [ ] **Step 3: Runtime — attachment screen**

Open the rich-text attachment editor, insert a table (table action → 2×2), tap a row or column handle once (selects it), then tap the same handle again. Expected: a **ContextController** (not a `UIEditMenuInteraction` menu) appears anchored at the handle, listing the Add/Delete actions (Delete in destructive red), adapted to the row/column state (header row omits Delete/Add-Above; a single-column table omits Delete Column). Tapping an item performs the edit and dismisses the menu; the transient anchor leaves no residue.

- [ ] **Step 4: Runtime — chat composer (best-effort)**

In a chat, get a table into the native composer (e.g. paste a table, or round-trip via the expanded attachment editor), tap a handle twice. Expected: the same ContextController presents over the input panel via `presentGlobalOverlayController`. If tables cannot be created in the compact composer in the current build, note that and rely on the attachment-screen verification (the wiring is identical through the shared helper).

- [ ] **Step 5: Commit any fixes**

If Step 1 required compile fixes, amend/commit them into the owning task's files:

```bash
cd /Users/isaac/build/telegram/telegram-ios
git add -A && git commit -m "fix(richtext): resolve structural-menu host wiring build errors"
```

---

## Self-Review Notes

- **Spec coverage:** descriptor (Task 1) ✓; editor hook + builder + removal of the UIMenu path (Tasks 1–2) ✓; shared helper in `ChatRichTextEditorComposer` (Task 3) ✓; both host wirings (Tasks 4–5) ✓; tests migrated to `.kind` (Tasks 1–2) ✓; alignment carried but not rendered (Task 1 descriptor + Task 3 note) ✓; singular titles / no pluralization (Task 3 titles + Task 1 test rewrite) ✓; retap-toggle behavior change accepted (Task 2 comment) ✓.
- **Type consistency:** `onRequestTableStructuralMenu` and `TableStructuralMenuRequest` (+ nested `Action`/`Kind`/`Alignment`) are named identically across canvas hook, facade, forwarder, and both hosts; `tableStructuralMenuRequest()` is the single builder; `presentTableStructuralMenu(_:presentationData:present:)` signature matches both call sites.
- **Coordinate-space risk (from the spec):** `sourceRect` is in canvas coords; the transient anchor is added to `request.view` (the canvas), so ContextUI resolves window space correctly even under table horizontal scroll — confirm in Step 3/4.
```
