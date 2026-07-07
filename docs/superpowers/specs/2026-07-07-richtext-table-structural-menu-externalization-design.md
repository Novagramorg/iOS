# Externalize the table structural menu to a host ContextController

**Date:** 2026-07-07
**Module:** `submodules/TelegramUI/Components/RichTextEditor` (+ hosts)
**Status:** design approved; pending spec review → plan

## Problem

The table row/column **structural menu** (Add/Delete row/column + column Align) is currently built
and presented *inside* the editor package as a `UIMenu` on `UIEditMenuInteraction`:

- `DocumentCanvasView+TableControls.swift` → `structuralMenu() -> UIMenu?` builds the menu (with
  state adaptation: header row → no Add-Above/Delete; single-column → no Delete Column; all-columns →
  no Delete; inline Align submenu).
- `DocumentCanvasView+Interaction.swift` (the `.menu` `TableHandleTap` case, ~line 255) presents it
  via `presentEditMenu(sourcePoint: hit.center)`.
- `DocumentCanvasView+EditMenuActions.swift` (`editMenuInteraction(_:menuFor:)`, line 20) returns
  `structuralMenu()` when `tableSelection != nil`.

This couples the editor to `UIEditMenuInteraction` for a menu that should look and behave like the
rest of Telegram's UI. Telegram presents anchored menus with **`ContextController`** (ContextUI),
which the editor package cannot import (it stays free of `AccountContext`/TelegramUI/ContextUI).

## Goal

Replace the in-editor `UIMenu` with a **framework-agnostic description** that the editor hands to
its host via a closure hook. The host (which owns the editor view) presents its own
`ContextController` from that description, anchored to the tapped table handle. The editor keeps
ownership of **what** the menu contains (state adaptation); the host owns **how** it's presented.

Scope is **table structural selection only**. The image-selection menu (`imageSelectionMenu()`) and
the text edit menu are out of scope and unchanged.

## Design

### 1. The descriptor (in `RichTextEditorUIKit`, framework-agnostic)

A reference-type request carrying the anchor + the actions. Lives in the editor package (imports
`RichTextEditorCore` for `TextAlignment`); it references only UIKit + Core, never ContextUI.

```swift
public final class TableStructuralMenuRequest {
    /// The view whose coordinate space `sourceRect` is expressed in — the editor's canvas. Weak so
    /// the host does not retain editor internals past presentation.
    public weak var view: UIView?
    /// The tapped handle's rect in `view` coordinates — the anchor the host presents the menu from.
    public let sourceRect: CGRect
    /// Add/Delete actions, already adapted to the table state (header row → no Add-Above/Delete;
    /// single-column → no Delete Column; all-columns → no Delete). Ordered for display.
    public let actions: [Action]
    /// Column selections only (nil for rows): the alignment choices + a callback. The host renders
    /// this as a `.custom` segmented control (deferred — see below); the data is carried now.
    public let alignment: Alignment?

    public struct Action {
        public let kind: Kind            // stable semantic identity — host derives title, destructive
                                         // styling, and icon from this; no presentation state here
        public let perform: () -> Void   // runs the edit AND clears the structural selection
    }
    public enum Kind {
        case addColumnLeft, addColumnRight, deleteColumn
        case addRowAbove, addRowBelow, deleteRow
    }
    public struct Alignment {
        public let options: [TextAlignment]         // [.left, .center, .right]
        public let current: TextAlignment?          // segmented selected-state, when resolvable
        public let select: (TextAlignment) -> Void  // applies the alignment AND clears the selection
    }
}
```

- `perform` / `select` are `() -> Void` / `(TextAlignment) -> Void` closures that wrap the existing
  `run + clearTableSelection` semantics (today's `structuralAction`). The host invokes them blindly —
  no editor internals leak.
- **No presentation state on `Action`** — no `title`, no `isDestructive`. `kind` is a stable semantic
  identity from which the host derives the (localizable) title, the destructive text styling, and the
  icon (`kind → themed UIImage`, or nil). This keeps the descriptor framework-agnostic, puts the look
  and localization under host control, and matches the principle already applied to icons.
- **Pluralization:** today's `structuralMenu()` pluralizes the delete title (`"Delete Columns"` when
  the range spans >1 column). `kind` alone can't express that. Decision: the host uses **singular
  titles** (`"Delete Column"` / `"Delete Row"`), matching the existing Telegram table menu items in
  the attachment screen (which do not pluralize). No multiplicity signal is carried on the request.
  If pluralization is wanted later, add a single `isMultiSelection: Bool` to the request then.

### 2. Editor-side changes (`DocumentCanvasView` + facade)

- **Facade hook** on `RichTextEditorView`:
  ```swift
  public var onRequestTableStructuralMenu: ((TableStructuralMenuRequest) -> Void)? {
      get { canvas.onRequestTableStructuralMenu }
      set { canvas.onRequestTableStructuralMenu = newValue }
  }
  ```
  Mirrors the existing `contextMenuItemsProvider` get/set forwarding.
- **New builder** `func tableStructuralMenuRequest() -> TableStructuralMenuRequest?` on
  `DocumentCanvasView` (replaces `structuralMenu()`). Same adaptation logic; emits `Action`s
  (+ `alignment` for column selections) instead of `UIAction`/`UIMenu`. It sets `view = self` and
  computes `sourceRect` by matching the active `tableSelection.kind` to `tableHandles()` (the handle
  rect), so it is self-contained (does not depend on the tap point).
- **`.menu` interaction case** (`+Interaction.swift`, ~line 255): call
  `if let req = tableStructuralMenuRequest() { onRequestTableStructuralMenu?(req) }` instead of
  `presentEditMenu(sourcePoint: hit.center)`.
- **Remove** `structuralMenu()` (the `UIMenu`) and the `tableSelection != nil → structuralMenu()`
  branch in `editMenuInteraction(_:menuFor:)`. The structural menu no longer rides
  `UIEditMenuInteraction` at all. The `structuralAction` helper is retyped to return `() -> Void`
  (the closure the descriptor carries) rather than `UIActionHandler`.

### 3. Shared presentation helper + host wiring

A single helper, in **`ChatRichTextEditorComposer`** (both hosts already depend on it; add
`ContextUI` + `TelegramPresentationData` to its Bazel deps):

```swift
public func presentTableStructuralMenu(
    _ request: TableStructuralMenuRequest,
    presentationData: PresentationData,
    present: (ViewController) -> Void
)
```

It:
1. maps `request.actions → [ContextMenuItem]` (`.action`, with the title / destructive text color /
   icon all derived from each action's `kind`);
2. anchors via a transient zero-interaction `UIView(frame: request.sourceRect)` inserted into
   `request.view`, exposed through a `ContextReferenceContentSource` (generalize the existing
   `RichTextActionContextReferenceSource` pattern to a sub-rect), removed on dismissal;
3. builds the `ContextController(… source: .reference(source), items: .single(.list(items)))` and
   hands it to the host's `present` closure.

**Per-host presentation** (the only difference, injected via `present`):
- **Attachment screen** (`RichTextAttachmentScreen`): `editor.onRequestTableStructuralMenu = { req in
  presentTableStructuralMenu(req, presentationData: pd) { c in
  environment?.controller()?.presentInGlobalOverlay(c) } }`.
- **Chat composer**: `ChatTextInputPanelNode` wires `richTextInputNode.onRequestTableStructuralMenu`
  to `presentTableStructuralMenu(req, presentationData:) { c in
  interfaceInteraction?.presentGlobalOverlayController(c, nil) }`; `RichTextEditorChatInputNode`
  forwards the new hook to `editorView` exactly like `contextMenuItemsProvider`.

### 4. Tests, behavior notes, deferred

- **Tests:** `TableControlsTests` switch from `structuralMenu()` to `tableStructuralMenuRequest()`,
  asserting on `actions.map(\.kind)` (which actions are present, in order) and `alignment?.options`.
  The adaptation logic is unchanged, so the existing title-based assertions become kind-based
  assertions of the same set (e.g. "Delete Column absent for a single-column table" → `.deleteColumn`
  not in `actions.map(\.kind)`); any align-title assertions move to `alignment?.options`.
- **Behavior change (flagged):** the editor no longer owns the presented menu, so today's "tap the
  already-selected handle to dismiss the open menu" *toggle* becomes a host/ContextController concern.
  First cut: each qualifying tap re-requests the menu; ContextController replaces any open menu.
  Noted as a follow-up, not fixed here.
- **Deferred:** the alignment `.custom` segmented item (descriptor already carries options + callback;
  host renders when ready); host icon assets per `kind` (can start nil / SF Symbols).

## Non-goals

- No change to the image-selection menu or the text edit menu.
- No new module (helper reuses `ChatRichTextEditorComposer`).
- No change to the underlying edit commands (`insertTableColumnLeft`, `deleteTableRow`,
  `setTableColumnAlignment`, …) — only how their menu is described/presented.

## Risks / open items

- **Coordinate space:** `sourceRect` is in canvas (content) coordinates; the canvas is the scroll
  content view, so anchoring a transient view at that rect inside the canvas is correct. Verify the
  ContextController anchors correctly when the table is horizontally scrolled (the handle rect tracks
  the unscrolled left edge for the row grip; column grip is offset by `contentOffsetX`).
- **Retap-to-dismiss toggle** behavior change (above) — confirm acceptable for the first cut.
- **Runtime verification:** SwiftPM tests cover the descriptor; the host wiring (ContextController
  presentation) is Bazel-only and must be verified in the running app (both hosts).
