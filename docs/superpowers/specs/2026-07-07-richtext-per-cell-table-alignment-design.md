# Per-cell table alignment (horizontal + vertical)

**Date:** 2026-07-07
**Module:** `submodules/TelegramUI/Components/RichTextEditor` + `ChatRichTextEditorComposer` + `TelegramCore` (ChatInputContent) + `RichTextEditorMessageConversion`
**Status:** design approved; pending spec review → plan
**Builds on:** the table structural-menu externalization (`2026-07-07-richtext-table-structural-menu-externalization-design.md`) — this fills in the deferred alignment `.custom` item and extends `TableStructuralMenuRequest.Alignment`.

## Problem

Table cell alignment is currently **horizontal-only and per-column** (`ColumnSpec.alignment: TextAlignment`,
stamped onto every cell in the column at render/send). There is no **vertical** alignment in the editor at
all — cells always render top-aligned. The goal is per-cell **horizontal + vertical** alignment, settable on
any selected cell subset (a row-range or a column-range), rendered in the editor, and round-tripped into sent
messages (both the composer and the attachment-screen paths).

## What already exists (no work needed)

- **The InstantPage message model is already per-cell for both axes.** `InstantPageTableCell`
  (`TelegramCore/Sources/SyncCore/SyncCore_InstantPage.swift`) has `alignment: TableHorizontalAlignment` and
  `verticalAlignment: TableVerticalAlignment`, with FlatBuffers already wired. No model / `.fbs` change.
- **The InstantPage V2 renderer already honors both.** `InstantPageV2Layout.swift` (~line 1511/1520/1537)
  switches on `cell.verticalAlignment` (top/middle/bottom content offset) and `cell.alignment` (horizontal).
  No renderer change.

So all work is editor-side + the two Codable currencies (`Document`, `ChatInputContent`) + the bridges +
the attachment-screen builder + the alignment `.custom` menu item.

## Decisions (locked)

1. **Both axes are per-cell.** Horizontal alignment migrates from `ColumnSpec` (per-column) to the `Cell`,
   alongside a new per-cell vertical alignment. This matches InstantPage's per-cell model, simplifies the
   round-trip (no per-column→per-cell stamping), and has no markdown cost (markdown is abandoned).
2. **Both row and column selections offer an H+V control.** Setting alignment applies to exactly the selected
   cells (the row-range's cells or the column-range's cells).
3. **Full round-trip** — editor + composer (`ChatInputContent`) + attachment screen. `ChatInputContent` is
   **Codable-only** (no FlatBuffers), so this is a plain field addition.
4. **No migration.** Cells lacking `horizontalAlignment` decode to `.center`; the retired
   `ColumnSpec.alignment` / `ChatInputColumnSpec.alignment` keys are ignored on decode. Old tables re-center
   (accepted). Vertical default is `.top`.

## Design

### 1. Core model (`RichTextEditorCore`)

- Add `enum VerticalAlignment: String, Codable, CaseIterable { case top, middle, bottom }`
  (Core is UIKit-/TelegramCore-free, so it cannot use TelegramCore's `TableVerticalAlignment`).
- `Cell` gains two render-override fields:
  ```swift
  public var horizontalAlignment: TextAlignment   // default .center
  public var verticalAlignment: VerticalAlignment  // default .top
  ```
  These are the cell's alignment overrides applied to the cell's paragraphs at render time (not stored on the
  paragraphs). `Cell`'s `Codable` decodes both with `decodeIfPresent` → `.center` / `.top` when absent.
- `ColumnSpec` keeps only `width`. Its `alignment` field is **removed**; because Swift `Codable` ignores
  unknown keys, an old document's `ColumnSpec.alignment` is silently dropped on decode. No migration code.
  (The custom `ColumnSpec.init(from:)` that previously tolerated a missing `alignment` is removed with the
  field.)

### 2. Editor rendering (`RichTextEditorUIKit` / `TableBlockBox`)

- **Horizontal**: the per-cell display-override pass (the loop that calls
  `(box as? BlockBox)?.applyDisplayOverride(alignment:forceBold:mapper:)`, ~line 197-204) reads **each cell's**
  `horizontalAlignment` instead of `columns[c].alignment`. Same override mechanism, per-cell source. The
  header-bold override (`forceBold: r == 0`) is unchanged.
- **Vertical**: in `recompute` (~line 232), the cell content origin Y — today `y + cellVerticalPadding`
  (always top) — gains a per-cell offset:
  ```
  freeSpace = rowHeight − 2·cellVerticalPadding − cellContentHeight   // ≥ 0
  vOffset   = freeSpace × (top: 0, middle: 0.5, bottom: 1.0)
  contentOrigin.y = y + cellVerticalPadding + vOffset
  ```
  `cellContentHeight` is the cell stack's measured height (already computed in the row-height pass,
  `rowHeightsComputed`). This mirrors the V2 renderer's math (`InstantPageV2Layout.swift:1511`). Top-aligned
  cells are byte-identical to today (vOffset 0).

### 3. Editor commands (`RichTextEditorUIKit`)

Replace the per-column `setTableColumnAlignment(_:)` with per-cell setters over the **current structural
selection's cells** (the selected row-range's cells, or column-range's cells):

```swift
func setSelectionHorizontalAlignment(_ a: TextAlignment)   // set every selected cell's horizontalAlignment
func setSelectionVerticalAlignment(_ a: VerticalAlignment)  // set every selected cell's verticalAlignment
```

Each is one undo step, mutates the affected `Cell`s in the `TableBlock`, and triggers a recompute/redraw. They
resolve the selected cells from `tableSelection` (`rows(range)` → every cell in those rows;
`columns(range)` → every cell in those columns). The structural selection is preserved (unlike the Add/Delete
actions, which clear it) so the user can keep adjusting alignment.

### 4. Descriptor + the alignment `.custom` item

`TableStructuralMenuRequest.Alignment` carries **both axes**, and `tableStructuralMenuRequest()` returns it for
**both** `rows` and `columns` selections (previously columns-only):

```swift
public struct Alignment {
    public let horizontal: TextAlignment?       // uniform value across the selected cells; nil = mixed
    public let vertical: VerticalAlignment?      // uniform value; nil = mixed
    public let apply: (TextAlignment?, VerticalAlignment?) -> Void   // set H and/or V on the selected cells;
                                                                      // a nil argument leaves that axis unchanged
}
```

- `horizontal`/`vertical` are computed by folding the selected cells: the common value, or `nil` when they
  differ (drives the control's selected / "mixed" state).
- `apply(h, v)` calls `setSelectionHorizontalAlignment` and/or `setSelectionVerticalAlignment` (skipping a
  `nil` axis). `VerticalAlignment` is a Core type, so the descriptor stays framework-agnostic.

**The alignment `.custom` item** (the user's in-progress `TableStructuralMenuAlignmentItem` in
`ChatRichTextEditorComposer`, currently a stub, plus the `presentTableStructuralMenu` change that prepends it
when `request.alignment != nil`) is completed and wired:

- Its callback maps the host-side TelegramCore `(TableHorizontalAlignment, TableVerticalAlignment)` to Core
  `(TextAlignment, VerticalAlignment)` and calls `request.alignment.apply(...)`.
- Its initial selected-state is seeded from `request.alignment.horizontal` / `.vertical` (showing "mixed"
  when nil).
- The item renders a control for both axes (e.g. two segmented rows, H and V). The exact control layout is a
  UI detail owned by the item; this spec fixes only the data interface (`Alignment`) and the mapping.

### 5. Round-trip

All four converters move from per-column to per-cell for horizontal, and start carrying vertical.

- **`ChatInputContent`** (`TelegramCore/Sources/ChatInputContent/ChatInputContentModel.swift`, Codable-only):
  - `ChatInputTableCell` gains `horizontalAlignment: ChatInputTextAlignment` (default `.center`) and
    `verticalAlignment: ChatInputTableVerticalAlignment` (new `enum … : Int32, Codable { top, middle, bottom }`,
    default `.top`), both `decodeIfPresent`.
  - `ChatInputColumnSpec.alignment` is **removed** (ignored on decode, like `ColumnSpec`).
- **`DocumentChatInputContentBridge`** (`ChatRichTextEditorComposer`): the `chatInputTable(fromTable:)` and the
  reverse map per-cell `horizontalAlignment`/`verticalAlignment` both directions (drop the per-column read).
- **`ChatInputContentInstantPage`** (`TelegramCore`): forward emits each cell's `horizontalAlignment` →
  `InstantPageTableCell.alignment` and `verticalAlignment` → `.verticalAlignment` (drop the hardcoded
  `verticalAlignment: .top` and the `columns[columnIndex].alignment` read); reverse reads both back into the
  `ChatInputTableCell`.
- **`InstantPageBuilder`** (`RichTextEditorMessageConversion`, attachment screen: Document→InstantPage) and its
  reverse (InstantPage→Document restore): emit/read per-cell `alignment` + `verticalAlignment`.
- **`InstantPageTableCell` and the V2 renderer are unchanged** (already per-cell for both).

### 6. Testing

- **Core (`swift test`)**: `VerticalAlignment` codec; `Cell` H+V Codable round-trip incl. the
  `decodeIfPresent` defaults (`.center` / `.top`); old-document decode ignores `ColumnSpec.alignment` and yields
  `.center` cells.
- **UIKit (`iostest.sh`, K3 sim)**: per-cell horizontal render override (two cells in one column with different
  H); vertical content-offset geometry (top vs middle vs bottom origin.y within a fixed-height row); the
  selection setters mutate exactly the selected cells; `tableStructuralMenuRequest()` returns an `Alignment` for
  both a row and a column selection, with `horizontal`/`vertical` = the uniform value or nil when mixed, and
  `apply` mutating the selected cells.
- **Round-trip (Core / `TextFormat` where the mappers live)**: Document→ChatInputContent→InstantPage and
  Document→InstantPage preserve per-cell H+V; reverse restores them; `ChatInputContent` Codable back-compat
  (old draft without the fields decodes to `.center`/`.top`).

## Non-goals

- No change to the InstantPage model, its FlatBuffers, or the V2 renderer (already per-cell).
- No per-cell alignment UI beyond the structural-menu `.custom` item (no drag handles, no inline toolbar).
- No colspan/rowspan/background work (out of scope; unchanged).
- Markdown (abandoned — not applicable).

## Risks / open items

- **Cell content-height availability in `recompute`** for the vertical offset — the row-height pass already
  measures each cell; confirm the per-cell measured height is reachable at the content-origin step (or measure
  once and reuse). Load-bearing for correct middle/bottom offsets.
- **"Mixed" state semantics** in the custom item when selected cells disagree — `apply(nil, v)` must leave the
  disagreeing axis untouched (partial application), not coerce it.
- **Existing-table visual change**: dropping the column-alignment migration re-centers old tables. Accepted.
- **Runtime verification** is simulator-manual for the menu/rendering (as with the prior feature).
