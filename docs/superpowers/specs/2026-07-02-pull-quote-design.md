# Pull Quote block — design spec

**Date:** 2026-07-02
**Status:** Approved (design); ready for implementation planning
**Area:** RichTextEditor composer + InstantPage rich-message round-trip

## Goal

Add a **pull quote** block to the WYSIWYG rich-text editor (`submodules/TelegramUI/Components/RichTextEditor`) — a **text-only** framed block (a variant of the regular quote) that is:

- **centered**, including a **content-hugging tinted pill** background (no left bar);
- rendered with a **fixed italic** font trait (all other inline attributes work as usual);
- decorated with **quote-mark images** in the **top-left** and **bottom-right** corners.

It must **round-trip fully**: authored in the composer, sent as a rich (InstantPage) message, rendered on the recipient, re-editable, and persisted in drafts.

Reference mockup: a light-blue rounded pill under a body paragraph, an opening quote mark top-left, a closing mark bottom-right, centered italic gray placeholder "*Type a quote here*", caret at start.

## Background — the key finding

An InstantPage `.pullQuote` block **already exists** and is **already wired end-to-end**:

- `InstantPageBlock.pullQuote(text: RichText, caption: RichText)` — `SyncCore_InstantPage.swift` (type tag 13, enum case ~line 75), with full Postbox decode/encode, FlatBuffers decode/encode + `.fbs` schema, MTProto parse/encode (`ApiUtils/InstantPage.swift`, TL `pageBlockPullquote`), `Equatable`, `plainText`.
- **V2 message render** already draws it **centered + italic** via `layoutQuoteText(isPull: true)` (`InstantPageV2Layout.swift:2395-2503`) — currently with top/bottom horizontal **rules** (`.shape` `.line` items), which we replace with the corner marks.
- **V1 full-page render** (`InstantPageLayout.swift:576-610`) renders it centered+italic, no rules — used only for web Instant View full-page articles; **untouched** by this work.
- The `.pullQuote` wire format is a **single flat `RichText`** (there is no `pullQuoteBlocks` TL constructor) — which is exactly why the editor block is a single text-only entity (below).

**The gap is purely on the compose/author side:** the composer currency (`ChatInputContent`) has no `.pullQuote` block, and the editor has no pull-quote block. This spec fills that gap and reskins the V2 render to corner marks + a content-hugging pill.

The editor's model is a **separate** system from InstantPage; do not conflate them.

## The model: a first-class `Block.pullQuote` entity (code-block pattern)

A pull quote is modeled as a **first-class `Block` entity holding multi-line rich text**, exactly like `Block.code` — **NOT** as a paragraph style. Rationale:

- **Text-only by construction.** A pull quote can only contain text with inline formatting — never an image/table/list. A single-block entity enforces this physically (you can't insert a block *inside* it). A paragraph style could not: an image dropped mid-run would split the pill, and quoted-lists would become reachable.
- **1:1 wire mapping, no coalescing.** One `Block.pullQuote` ↔ one `ChatInputBlock.pullQuote` ↔ one InstantPage `.pullQuote(text:)`. This mirrors the existing `Block.code` → `ChatInputBlock.code` → `.preformatted` path **exactly** (`ChatInputContentInstantPage.swift:76` forward, `:215` reverse), and removes any join-forward / split-reverse ambiguity.
- **Proven template.** The code block (added 2026-06-19) is, per the editor CLAUDE.md, "the single best template for adding a sibling framed block." We follow its structure, position mapping, editing affordances, and cross-block-delete handling.

**The one substantive difference from `Block.code`:** pull-quote runs keep **full inline formatting** (bold/underline/strike/link/color/custom-emoji). Code-block runs flatten to a plain monospace string on read-back; a pull quote's `currentBlock()` returns the **rich runs**. Plus: it draws a content-hugging pill + corner marks (not the code/quote left-bar fill), and forces italic + center render-only.

## Decisions (locked)

1. **Scope: full round-trip** — author → send as rich message → recipient render → re-edit → draft persistence. Reuses the existing InstantPage `.pullQuote` wire block.
2. **Model: first-class `Block.pullQuote(PullQuote)` entity**, mirroring `Block.code`. Multi-line via interior `"\n"` in the runs (not coalesced paragraphs).
3. **Editing semantics: mirror the code block.** Enter inserts an interior line; double-return / Enter-on-a-trailing-empty-line exits to a body paragraph; Backspace in an empty pull quote un-makes it to body; tap-below appends a trailing paragraph; cross-block delete treats a pull-quote endpoint like a framed atom (truncate-keep partial / drop full). Creation (`makePullQuote()`) toggles the selected paragraphs into one pull-quote block (text joined by `"\n"`) and toggles back to body paragraphs split on `"\n"`.
4. **Corner marks: reuse `Chat/Message/ReplyQuoteIcon`** (the shipped `quotemini.pdf` glyph), tinted to the accent color: top-left as-is, bottom-right rotated 180°. No new assets.
5. **Background: content-hugging centered pill** — the fill width tracks the widest wrapped line in the block (+ horizontal padding), centered; not full column width. Empty state hugs the placeholder width (or a configured minimum).
6. **Render-only fixed traits: italic + center alignment.** Applied at render time only; **never persist into the model** (markdown-clean), mirroring how headings force serif render-only and how the InstantPage `.pullQuote` render already forces `.italic`. Consequence: the **italic toggle is inert** inside a pull quote (the forced trait always wins); bold/underline/strike/color/link/emoji all apply as usual on top (e.g. bold → bold-italic).

## Rejected alternatives

- **Paragraph style `ParagraphStyleName.pullQuote`** (mirror the regular quote): a paragraph style can't enforce text-only — an interleaved image splits the run, quoted-lists become reachable — and it forces a coalesce/join/split round-trip. Rejected in favor of the entity model.
- **New wire flag on `.blockQuote`**: `.blockQuote` has no such field on the wire; the existing `.pullQuote` block already represents exactly this.
- **Full-width symmetric fill**: rejected in favor of the content-hugging pill to match the mockup.

---

## Detailed design

### 1. Core model (`RichTextEditorCore`, UIKit-free)

Mirror `Block.code` / `CodeBlock` throughout.

- **`Model/PullQuote.swift`** (new) — `public struct PullQuote: Equatable { public var id: BlockID; public var runs: [TextRun] }`, whose runs' `text` may contain interior `"\n"`. (No `language` field — unlike `CodeBlock`.) `Codable`.
- **`Model/Block.swift`** — add `case pullQuote(PullQuote)` to `Block`; extend the `id` accessor and the `Codable` `Kind` enum (`case pullQuote`) + `init(from:)` + `encode(to:)` arms.
- **`Position/DocumentTree.swift`** — `node(for:)` maps `.pullQuote` to a `.paragraph` DocNode carrying a text leaf, sized `content + 2` — identical to the `.code` arm. Interior `"\n"` is a linear UTF-16 range TextKit wraps; **no** new position/selection/tokenizer machinery.
- **`Model/DocumentFragment.swift`** — `regeneratingTopLevelIDs` gets a `.pullQuote` arm (fresh id); `isInlineMergeable` → `.pullQuote` returns `false` (paste never fuses it inline).
- **Serialization** — `DocumentCodec` / `DocumentPackage` follow the `Block.code` precedent (the new `Kind` case handles it).

### 2. Editor rendering (`RichTextEditorUIKit`)

**New `Canvas/PullQuoteBox.swift`** — a `CanvasBlock`-conforming framed box, modeled on `CodeBlockBox`, but:
- A **body-font** `BlockLayoutEngine` (not monospace), with **forced italic** and **forced center** alignment applied render-only in the box's `StyleSheet`/mapper (never written back to runs). `currentBlock()` returns the **rich runs** (full inline formatting preserved — the key divergence from code, whose read-back is plain).
- `nodeSize`/`textStart`/`textLength`/`closestPosition`/`leafRegions`/`draw` mirror `CodeBlockBox` (sized `content + 2`).
- Reuses the theme accent for the pill tint + mark tint.

**Content-hugging pill fill (`Canvas/BlockquoteUnderlay.swift` + `Canvas/DocumentCanvasView+Decorations.swift`):**
- Give `BlockquoteUnderlay` a **barless** cached image (`bar = 0`) selectable per-run (or add a sibling `PullQuoteUnderlay`).
- `blockquoteDecorations()` gets a `PullQuoteBox` case that emits a **pill rect** = the union of the widest laid-out line width across the block's lines (+ horizontal pill padding), **horizontally centered** in the content column, spanning the block's vertical extent (+ vertical pill padding). The box exposes its max-line-width from its layout. Rounded both ends (its own single-block run, like code/collapsed).
- **Empty pull quote:** the pill sizes to the placeholder width (or a configured minimum), so the empty state renders like the mockup (marks + centered placeholder + caret).

**Corner marks (new pooled controls view, modeled on `Canvas/QuoteCollapseControlsView.swift`):**
- Two tinted `ReplyQuoteIcon` `UIImageView`s per visible pull-quote run at the pill's **top-left** (as-is) and **bottom-right** (`transform = CGAffineTransform(rotationAngle: .pi)`), inset by a small padding, drawn above the fill. Virtualized to visible runs like the underlay.

**Per-host geometry knob:** add a `PullQuoteStyle` value (mirroring `QuoteStyle`: pill horizontal/vertical padding, corner radius, fill alpha, mark size/inset, min pill width) set via `RichTextEditorView.pullQuoteStyle` → `DocumentCanvasView.applyPullQuoteStyle` (rebuild stylesheet + reload), so the compact composer and the full-page attachment editor tune it. Follows the existing `quoteStyle` `applyX` + reload convention.

### 3. Editing behavior (mirror `Block.code`)

- **Creation:** `RichTextEditorView.makePullQuote()` (façade-forwarded, `+ParagraphFormat`) toggles the touched top-level paragraphs into one `Block.pullQuote` (joining their text with `"\n"`, refusing a selection that spans a non-text block), and toggles back to body paragraphs split on `"\n"` — exactly like `makeCodeBlock()`. Wired to a new **"Pull Quote"** entry in the composer Format submenu (`ChatTextInputPanelNode`) and the attachment-screen action bar (`RichTextActionBarComponent` / `RichTextAttachmentScreen`).
- **Enter:** `insertPullQuoteNewline()` inserts an interior `"\n"` (replacing any selection), mirroring `insertCodeBlockNewline()`.
- **Exit (double-return):** mirror `codeBlockDoubleReturnExit` — a **trailing** blank line → body paragraph *after*; the **first** blank line (incl. the local-1 "two newlines at the beginning") → body *before*; a **wholly-empty** block → un-make to body; a **middle** blank line just inserts a newline.
- **Backspace:** in a fully-empty pull quote, un-make it to a body paragraph (mirrors `uncodeEmptyCodeBlock`).
- **Placeholder:** `PullQuoteBox.placeholderText` returns the pull-quote placeholder (host-supplied via `RichTextEditorPlaceholders`, add a `pullQuote` field, **default "Type a quote here"**), centered/italic/gray. The empty-state pill hugs this string's width.
- **Tap below** a trailing pull quote appends a body paragraph; **cross-block** edits treat a pull-quote endpoint like a framed atom (truncate-and-keep partial coverage, drop full coverage) in `applyReplace`; **Backspace at the start of a paragraph after a pull quote** deletes the empty paragraph, not the block (add `.pullQuote` to `isNonParagraphAtom` / `coverableContentEnd` where `.code` appears).

### 4. Round-trip (send / draft / recipient) — mirror the `.code`/`.preformatted` path

**a. `ChatInputContent` model (`TelegramCore/Sources/ChatInputContent/ChatInputContentModel.swift`):**
- New `public struct ChatInputPullQuote: Equatable, Codable { public var runs: [ChatInputRun] }` (mirror `ChatInputCode`, no `language`).
- Add `case pullQuote(ChatInputPullQuote)` to `ChatInputBlock` (+ the `CodingKeys`/decode/encode arms next to `.code`).
- `isEntityExpressible(options:)` → `.pullQuote` returns **`false` unconditionally** (a pull quote has no plain-message/entity representation; it always forces the rich InstantPage send path).
- Flat-axis membership (`blockIsFlatParticipating` / `blockFlatLength`) — a `.pullQuote` participates with its **full text length** (interior newlines counted), like `.code` (it is editable text), **not** a 1-char atom like `.collapsedQuote`.

**b. `ChatInputContent` ↔ InstantPage (`ChatInputContentInstantPage.swift`):**
- **Forward** (next to the `.code` arm at :76): `case let .pullQuote(pq): result.append(.pullQuote(text: richText(from: pq.runs), caption: .empty))`.
- **Reverse** (next to the `.preformatted` arm at :215): `case let .pullQuote(rt, _): result.append(.pullQuote(ChatInputPullQuote(runs: chatInputRuns(fromRichText: rt))))`.

**c. Editor `Document` ↔ `ChatInputContent` (`ChatRichTextEditorComposer/Sources/DocumentChatInputContentBridge.swift`):**
- Add the `Block.pullQuote ↔ ChatInputBlock.pullQuote` arms in both directions (mirror the `.code` arms). Map `PullQuote.runs ↔ ChatInputPullQuote.runs` via the existing run converters.

**d. Flat NSAttributedString currency (`ChatRichTextEditorComposer/Sources/ComposerDocumentBridge.swift`):** thread `Block.pullQuote` through the same two-pass `document(from:)` + emit path as `Block.code` (so `composerSelectedRange` / flat-coordinate mapping count its interior text), following the code-block precedent. (Only if the code block touches this file — mirror it exactly.)

**e. Attachment-screen send path (`RichTextEditorMessageConversion` InstantPage builder):** add the parallel `Block.pullQuote` → `InstantPageBlock.pullQuote(text: richText(from runs), caption: .empty)` arm (the attachment screen builds InstantPage directly from the editor `Document`).

**f. V2 message render (`InstantPageUI`):** reskin `.pullQuote` from rules → corner marks + content-hugging pill so the recipient matches the composer:
- `InstantPageV2Layout.swift` `layoutQuoteText(isPull: true)` — remove the top/bottom `.shape` `.line` rules; add a **content-hugging rounded-rect pill** background (reuse the existing `InstantPageV2ShapeKind.roundedRect` fill item, sized to the laid-out text width + padding, centered) and **two corner-mark image items** at the pill's top-left / bottom-right. Keep the existing centered + italic text.
- New laid-out **image-ornament** item + view (a `UIImageView`-backed `InstantPageItemView`; pattern: `InstantPageV2ShapeView` at `InstantPageRenderer.swift:1642-1671`), with its case added to every non-`default` switch: `InstantPageV2LaidOutItem.frame`/`offsetBy`, `InstantPageV2ItemKind`, `reuse`, `stableId`, `makeItemView`, **and the zero-cost list in `InstantPageV2RevealCost.swift`** (or it mis-charges the streaming reveal cursor).
- RTL: the pill is symmetric (centered), no leading-edge flip; marks stay in the same physical corners. (Composed messages send `rtl:false`; web-IV `.pullQuote` in V2 gets the same centered treatment.)

**g. Drafts:** free — `ChatInputContent` is the draft currency; once (a)–(c) land, a pull quote persists locally and syncs cross-device like any other block.

### 5. Markdown & RTF

- **Markdown (`InstantPageToMarkdown.swift` / `BrowserMarkdown.swift`):** InstantPage→markdown already reverses `.pullQuote` to a `>` blockquote (lossy — no standard markdown for a pull quote). **Leave as-is** for v1 (accepted limitation). Markdown→InstantPage has no pull-quote producer; unchanged.
- **RTF (`Canvas/RTFConversion.swift` / `RTFImport.swift`):** export a `Block.pullQuote` as an italicized quote-like paragraph (best-effort; degrades to a normal quote on re-import, parity with existing quote RTF limitations). Add the `.pullQuote` block arm wherever `.code` is handled in the export walk.

---

## Testing (TDD)

- **Core** (`swift test`, macOS): `PullQuoteTests` / `BlockTests` (Codable round-trip, `id`), `DocumentFragmentTests` (`isInlineMergeable == false`, `regeneratingTopLevelIDs`), `DocumentTreeTests` (`.pullQuote` node shape sized `content + 2`, interior-newline positions).
- **UIKit** (simulator, `Scripts/iostest.sh`): mirror the code-block + quote suites —
  - `PullQuoteBoxTests`: forced center + italic (render-only), rich-run read-back (formatting survives `currentBlock()`), base size, insets.
  - `PullQuoteGeometryTests` / decorations: content-hugging pill rect (widest-line union + centering), corner-mark placement (top-left / bottom-right-rotated), empty-state min width.
  - `CanvasPullQuoteEditTests`: `makePullQuote` toggle (join `\n` / split `\n`), placeholder, Enter = interior newline, double-return exit (trailing/first/wholly-empty/middle), empty-Backspace un-make, tap-below, cross-block delete.
  - Assert the render-only invariant: italic/center **never** appear in the read-back `Document` runs/attributes.
- **TelegramCore** (`TextFormat` `ios_unit_test`, run via `Make.py test --target //submodules/TextFormat:TextFormatTests`): `ChatInputContent ↔ InstantPage` `.pullQuote` 1:1 round-trip (runs ↔ flat RichText, interior `\n` preserved, inline formatting preserved); `isEntityExpressible == false`; `DocumentChatInputContentBridge` `Block.pullQuote` round-trip.

## Full build gate

Full app build per the CLAUDE.md Bazel invocation (touches TelegramCore, InstantPageUI, TelegramUI, the RichTextEditor package, and the composer/attachment hosts). Intended acceptance: a logged-in two-device send/receive check (mirrors the checklist / collapsed-quote / code-block verification).

## Accepted limitations

- Multi-line pull quotes are flat text on the wire (the `.pullQuote` format is a single `RichText`); interior newlines round-trip, but there is no nested-block structure by design.
- Markdown reverse is lossy (`>` blockquote).
- Reskinning V2 `.pullQuote` changes how *any* `.pullQuote` renders in a **message bubble**; web-IV **full-page** articles (V1) are unaffected.
- No language field, no collapse, no nested blocks — a pull quote is a flat text-only entity.

## File touch-list (anchors from exploration)

**TelegramCore:** `ChatInputContent/ChatInputContentModel.swift` (`ChatInputPullQuote` struct + `ChatInputBlock.pullQuote` case + `isEntityExpressible` + flat-axis), `ChatInputContent/ChatInputContentInstantPage.swift` (forward :76-area / reverse :215-area). *(InstantPage `.pullQuote` model/wire already complete — no `SyncCore_InstantPage.swift` / `.fbs` / `ApiUtils` change.)*

**InstantPageUI:** `Sources/InstantPageV2Layout.swift` (`layoutQuoteText`), `Sources/InstantPageRenderer.swift` (image-ornament item kind + reuse + stableId + makeItemView + view), `Sources/InstantPageV2RevealCost.swift` (zero-cost list).

**RichTextEditor package (`RichTextEditorCore`):** `Model/PullQuote.swift` (new), `Model/Block.swift`, `Position/DocumentTree.swift`, `Model/DocumentFragment.swift`, `Serialization/DocumentCodec.swift` / `DocumentPackage.swift` (as the `Kind` case flows through).

**RichTextEditor package (`RichTextEditorUIKit`):** `Canvas/PullQuoteBox.swift` (new), `Canvas/BlockquoteUnderlay.swift` (barless variant), `Canvas/DocumentCanvasView+Decorations.swift` (pill run + hug geometry), a new corner-mark controls view (new file), `Canvas/DocumentCanvasView.swift` (box-factory arm), `Canvas/DocumentCanvasView+ParagraphFormat.swift` (`makePullQuote`), `Canvas/DocumentCanvasView+UITextInput.swift` + `+Editing.swift` (Enter / double-return exit / backspace / cross-block), `Mapping/StyleSheet.swift` (pull-quote font/metrics/center), `Canvas/RTFConversion.swift`, `RichTextEditorView.swift` + `RichTextEditorView+ComposerHost.swift` (`makePullQuote`, `pullQuoteStyle`, placeholder field), new `PullQuoteStyle.swift`.

**App-side composer / hosts:** `ChatRichTextEditorComposer/Sources/DocumentChatInputContentBridge.swift`, `ChatRichTextEditorComposer/Sources/ComposerDocumentBridge.swift` (if code touches it), `RichTextEditorMessageConversion` InstantPage builder, `ChatTextInputPanelNode` (Format submenu entry), `RichTextAttachmentScreen` / `RichTextActionBarComponent` (action-bar entry).

**Assets:** reuse `Images.xcassets/Chat/Message/ReplyQuoteIcon` (no new asset).
