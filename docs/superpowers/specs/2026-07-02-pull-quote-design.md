# Pull Quote block — design spec

**Date:** 2026-07-02
**Status:** Approved (design); ready for implementation planning
**Area:** RichTextEditor composer + InstantPage rich-message round-trip

## Goal

Add a **pull quote** block to the WYSIWYG rich-text editor (`submodules/TelegramUI/Components/RichTextEditor`) — a variant of the regular quote that is:

- **centered**, including a **content-hugging tinted pill** background (no left bar);
- rendered with a **fixed italic** font trait (all other inline attributes work as usual);
- decorated with **quote-mark images** in the **top-left** and **bottom-right** corners.

It must **round-trip fully**: authored in the composer, sent as a rich (InstantPage) message, rendered on the recipient, re-editable, and persisted in drafts.

Reference mockup: a light-blue rounded pill under a body paragraph, an opening quote mark top-left, a closing mark bottom-right, centered italic gray placeholder "*Type a quote here*", caret at start.

## Background — the key finding

An InstantPage `.pullQuote` block **already exists** and is **already wired end-to-end**:

- `InstantPageBlock.pullQuote(text: RichText, caption: RichText)` — `SyncCore_InstantPage.swift` (type tag 13, enum case ~line 75), with full Postbox decode/encode, FlatBuffers decode/encode + `.fbs` schema, MTProto parse/encode (`ApiUtils/InstantPage.swift`, TL `pageBlockPullquote`), `Equatable`, `plainText`.
- **V2 message render** already draws it **centered + italic** via `layoutQuoteText(isPull: true)` (`InstantPageV2Layout.swift:2395-2503`) — currently with top/bottom horizontal **rules** (`.shape` `.line` items), which we will replace with the corner marks.
- **V1 full-page render** (`InstantPageLayout.swift:576-610`) renders it centered+italic, no rules — used only for web Instant View full-page articles; **untouched** by this work.
- Real web Instant View articles / the server are the only current producers of `.pullQuote`.

**The gap is purely on the compose/author side:** the `ChatInputContent` codec (`ChatInputContentInstantPage.swift`) has no `.pullQuote` handling, and the editor has no pull-quote paragraph style. This spec fills that gap and reskins the V2 render to corner marks.

The editor's model is a **separate** system from InstantPage; do not conflate them. In the editor, the regular quote is a **paragraph style** (`ParagraphStyleName.quote`), not a `Block` case. The pull quote follows the same pattern.

## Decisions (locked)

1. **Scope: full round-trip** — author → send as rich message → recipient render → re-edit → draft persistence. Reuses the existing InstantPage `.pullQuote` wire block.
2. **Content model: multi-paragraph paragraph style**, mirroring the regular quote. A new `ParagraphStyleName.pullQuote`; consecutive `.pullQuote` paragraphs coalesce into one visual block. On send, the run's paragraphs join into one `.pullQuote(text:)` `RichText` (newline-separated); on edit, the text re-splits on newlines into paragraphs. (The wire format is a single flat `RichText` — there is no `pullQuoteBlocks` TL constructor.)
3. **Corner marks: reuse `Chat/Message/ReplyQuoteIcon`** (the shipped `quotemini.pdf` glyph), tinted to the accent color: top-left as-is, bottom-right rotated 180°. No new assets.
4. **Background: content-hugging centered pill** — the fill width tracks the widest wrapped line (+ horizontal padding) and centers as a pill; not full column width.
5. **Render-only fixed traits: italic + center alignment.** Both are applied at render time only and **never persist into the model** (markdown-clean), mirroring how headings force serif render-only and how the InstantPage `.pullQuote` render already forces `.italic`. All other inline attributes (bold, underline, strike, color, links, custom emoji) apply as usual on top.

## Rejected alternatives

- **New `Block` case** (like `Block.code` / `Block.collapsedQuote`): those are non-coalescing framed atoms. We chose multi-paragraph coalescing, so a paragraph style is the correct and far cheaper pattern, reusing the whole `.quote` machinery (coalescing runs, empty-caret, escape affordances).
- **New wire flag on `.blockQuote`** (a "centered/pull" bool): `.blockQuote` has no such field on the wire; adding one needs a TL/MTProto/server change. The existing `.pullQuote` block already represents exactly this.
- **Full-width symmetric fill** for the background: rejected in favor of the content-hugging pill to match the mockup.

---

## Detailed design

### 1. Core model (`RichTextEditorCore`, UIKit-free)

- **`Model/Enums.swift`** — add `pullQuote` to `ParagraphStyleName` (String, Codable, CaseIterable). No decode shim: an old build fails to decode `"pullQuote"`, same precedent as `.quote`/`.caption`.
- **`Model/DocumentFragment.swift`** — `isInlineMergeable`: `.pullQuote` returns `false` (like `.quote`), so paste never fuses a pull quote into an adjacent paragraph.
- **`Position/DocumentTree.swift`** — **no change.** A `.pullQuote` paragraph maps to the same `.paragraph` DocNode (one `.text` leaf) as body/quote. No new position, selection, or tokenizer machinery.
- **Serialization** — `DocumentCodec` / `DocumentPackage` need no special-casing (the enum is String-Codable). Exhaustive `switch ParagraphStyleName` sites elsewhere get a `.pullQuote` arm (see touch-list).

### 2. Editor rendering (`RichTextEditorUIKit`)

**Style (`Mapping/StyleSheet.swift`):**
- `baseSize(.pullQuote)` → match `.quote` (15pt) unless a follow-up tweaks it.
- `metrics(.pullQuote)` → spacing before/after + `lineHeightMultiple` (start from quote's values).
- `paragraphStyle(...)` → force **`.center`** alignment for `.pullQuote` regardless of the stored alignment (render-only). Symmetric text insets; **no** leading bar indent.
- `font(...)` → force **italic** for `.pullQuote` (`italic = true`, ignoring the run's italic bit) — the render-only fixed trait. `bold = attributes.bold`, `serif = false` (as body). Consequence: the **italic toggle is inert** inside a pull quote (the forced trait always wins, like you can't un-serif a heading); bold/underline/strike/color/link/emoji toggles all work normally and compose on top (e.g. bold → bold-italic).
- `AttributedStringMapper` default foreground: `.pullQuote` uses `theme.primaryText` (same as body/quote). No quote-specific color forcing.

**Content-hugging pill fill:**
- The regular quote's `Canvas/BlockquoteUnderlay.swift` always paints a left bar and stretches to the run frame. Give it (or a sibling `PullQuoteUnderlay`) a **barless** cached image (`bar = 0`) and drive the pill frame from the **text extent**, not the block frame.
- `Canvas/DocumentCanvasView+Decorations.swift` `blockquoteDecorations()`: a `.pullQuote` run is its **own** run (rounded both ends), **not** fused with adjacent `.quote` runs. Compute the run's **pill rect** = the union of the widest laid-out line width across all paragraphs in the run (+ horizontal pill padding), **horizontally centered** in the content column, spanning the run's vertical extent (+ vertical pill padding). The engine (`BlockLayoutEngine`) exposes per-line rects; take the max line width.
- **Empty pull quote:** the pill sizes to the placeholder text width (or a configured minimum), so the empty state renders like the mockup (marks + centered placeholder + caret).

**Corner marks:**
- A new pooled image-view layer modeled on `Canvas/QuoteCollapseControlsView.swift`, placing two tinted `ReplyQuoteIcon` `UIImageView`s at the pill's **top-left** (as-is) and **bottom-right** (`transform = CGAffineTransform(rotationAngle: .pi)`), inset by a small padding, drawn above the fill. Virtualized to visible runs like the underlay.
- Tint = the editor theme accent (reuses the existing accent plumbing that already colors the quote bar/fill/caret).

**Per-host geometry knob:** add a `PullQuoteStyle` value (mirroring `QuoteStyle`: pill horizontal/vertical padding, corner radius, fill alpha, mark size/inset, min pill width) set via `RichTextEditorView.pullQuoteStyle` → `DocumentCanvasView.applyPullQuoteStyle` (rebuild stylesheet + reload), so the compact composer and the full-page attachment editor can tune it. Follows the existing `quoteStyle` `applyX` + reload convention.

### 3. Editing behavior

- **Creation:** a new **"Pull Quote"** entry in the composer's Format submenu (`ChatTextInputPanelNode` builds the 10-item submenu today) and in the attachment-screen action bar (`RichTextActionBarComponent` / `RichTextAttachmentScreen`), wired to `RichTextEditorView.setParagraphStyle(.pullQuote)` — a toggle exactly like Quote.
- **Placeholder:** `Canvas/BlockBox.swift` `placeholderText` returns the pull-quote placeholder for an empty `.pullQuote` (quotes currently return `nil`; add the case). The string is host-supplied via the existing `RichTextEditorPlaceholders` config (add a `pullQuote` field, **default "Type a quote here"**) so it's localizable and a host can blank it. The empty-state pill hugs this placeholder's width (see §2).
- **Empty-caret geometry:** centered caret in the empty pill (the alignment is `.center`), consistent with the empty-line fallbacks.
- **Escape / delete affordances mirror `.quote`** at every `.quote`-keyed site the exploration flagged: Backspace in an **empty** pull quote un-styles it to `.body`; **double-return** on an empty edge line exits to a body paragraph; coalescing / `facingInset` / run-edge vertical-inset rules treat `.pullQuote` as its own container; quoted-list interactions are out of scope (a pull quote is not combined with lists in v1).

### 4. Round-trip (send / draft / recipient)

**a. `ChatInputContent` model (`TelegramCore/Sources/ChatInputContent/ChatInputContentModel.swift`):**
- Add `ChatInputParagraphStyle.pullQuote` (with Codable discriminator + encode/decode, mirroring `.quote`).
- `isEntityExpressible(options:)` → `.pullQuote` returns **`false` unconditionally** (a pull quote has no plain-message/entity representation, so it always forces the rich InstantPage send path — stronger than `.quote`, which is expressible unless `quotesRequireRichContent`).
- Flat-axis membership (`blockIsFlatParticipating` / `blockFlatLength`) — a `.pullQuote` paragraph participates like any text paragraph.

**b. Editor `Document` ↔ `ChatInputContent` (`ChatRichTextEditorComposer/Sources/DocumentChatInputContentBridge.swift`):**
- `chatInputStyle(fromParagraphStyle:)` and `paragraphStyle(fromChatInputStyle:)` — add `.pullQuote ↔ .pullQuote`.

**c. `ChatInputContent` ↔ InstantPage (`TelegramCore/Sources/ChatInputContent/ChatInputContentInstantPage.swift`):**
- **Forward:** coalesce a maximal run of consecutive `.pullQuote` paragraphs into one `InstantPageBlock.pullQuote(text: <joined RichText>, caption: .empty)`, joining paragraphs' `RichText` with `"\n"`. (Sits alongside the existing `.quote`-coalescing logic.)
- **Reverse:** `.pullQuote(text, _)` → split `text` on `"\n"` into `.pullQuote` paragraphs.

**d. Attachment-screen send path (`RichTextEditorMessageConversion` InstantPage builder):** add the parallel `.pullQuote` arm (the attachment screen builds InstantPage directly from the editor `Document`, bypassing `ChatInputContent`).

**e. V2 message render (`InstantPageUI`):** reskin `.pullQuote` from rules → corner marks + content-hugging pill so the recipient matches the composer:
- `InstantPageV2Layout.swift` `layoutQuoteText(isPull: true)` — remove the top/bottom `.shape` `.line` rules; add a **content-hugging tinted pill** background item and **two corner-mark image items** at the pill's top-left / bottom-right. Keep the existing centered + italic text.
- New laid-out-item + view for an **image ornament** (the corner marks) — a `UIImageView`-backed `InstantPageItemView` (pattern: `InstantPageV2ShapeView` at `InstantPageRenderer.swift:1642-1671`); add its case to every non-`default` switch: `InstantPageV2LaidOutItem.frame`/`offsetBy`, `InstantPageV2ItemKind`, `reuse`, `stableId`, `makeItemView`, and the **zero-cost list in `InstantPageV2RevealCost.swift`** (or it will mis-charge the streaming reveal cursor).
- The pill background can reuse the existing `.blockQuoteBar`/`.roundedRect` shape machinery (a rounded-rect fill item) — no left bar.
- RTL: the pill is symmetric (centered), so no leading-edge flip; the marks stay in the same physical corners. (Composed messages send `rtl:false`, so mirroring is moot for authored pull quotes; web-IV `.pullQuote` in V2 would use the same centered treatment.)

**f. Drafts:** free — `ChatInputContent` is the draft currency; once (a)/(b) land, a pull quote persists locally and syncs cross-device like any other block.

### 5. Markdown & RTF

- **Markdown (`InstantPageToMarkdown.swift` / `BrowserMarkdown.swift`):** InstantPage→markdown already reverses `.pullQuote` to a `>` blockquote (lossy — there's no standard markdown for a pull quote). **Leave as-is** for v1 (accepted limitation; a distinct marker is out of scope). Markdown→InstantPage has no pull-quote producer; unchanged.
- **RTF (`Canvas/RTFConversion.swift` / `RTFImport.swift`):** add `.pullQuote` to the paragraph-style size map (`case .body, .quote, .pullQuote: return 17`). On RTF **export** a pull quote degrades to a normal quote (parity with existing quote RTF limitations); no import producer.

---

## Testing (TDD)

- **Core** (`swift test`, macOS): `ParagraphBlockTests` / `DocumentFragmentTests` / `DocumentCodecTests` cover `.pullQuote` encode/decode + `isInlineMergeable`.
- **UIKit** (simulator, `Scripts/iostest.sh`): mirror the quote suites —
  - `StyleSheetPullQuoteTests`: forced center + italic (render-only), base size, insets.
  - `PullQuoteGeometryTests` / decorations: content-hugging pill rect (widest-line union + centering), corner-mark placement (top-left / bottom-right-rotated), empty-state min width.
  - `CanvasPullQuoteEditTests`: creation via `setParagraphStyle`, placeholder text, empty-Backspace un-style, double-return exit, coalescing runs, vertical insets.
  - Assert the render-only invariant: italic/center **never** appear in the read-back `Document` runs/attributes.
- **TelegramCore** (`TextFormat` `ios_unit_test`, run via `Make.py test --target //submodules/TextFormat:TextFormatTests`): `ChatInputContent ↔ InstantPage` `.pullQuote` round-trip (coalesce/join forward, split reverse); `isEntityExpressible == false`; `DocumentChatInputContentBridge` style round-trip.

## Full build gate

Full app build per the CLAUDE.md Bazel invocation (touches TelegramCore, InstantPageUI, TelegramUI, and the RichTextEditor package). No runtime device pass is gating for the spec, but a logged-in two-device send/receive check is the intended acceptance (mirrors the checklist/collapsed-quote verification).

## Accepted limitations

- Multi-paragraph pull quotes flatten to newline-separated text on the wire (no nested-block fidelity — the `.pullQuote` wire format is flat). Re-split on edit recovers paragraphs.
- Markdown reverse is lossy (`>` blockquote).
- Reskinning V2 `.pullQuote` changes how *any* `.pullQuote` renders in a **message bubble**; web-IV **full-page** articles (V1) are unaffected.
- Pull quote + list container combination is out of scope for v1.

## File touch-list (anchors from exploration)

**TelegramCore:** `ChatInputContent/ChatInputContentModel.swift` (new style case + `isEntityExpressible`), `ChatInputContent/ChatInputContentInstantPage.swift` (forward coalesce/reverse split). *(InstantPage `.pullQuote` model/wire already complete — no `SyncCore_InstantPage.swift` / `.fbs` / `ApiUtils` change.)*

**InstantPageUI:** `Sources/InstantPageV2Layout.swift` (`layoutQuoteText`/`layoutBlock`), `Sources/InstantPageRenderer.swift` (item kind + reuse + stableId + makeItemView + new image-ornament view), `Sources/InstantPageV2RevealCost.swift` (zero-cost list).

**RichTextEditor package (`RichTextEditorCore`):** `Model/Enums.swift`, `Model/DocumentFragment.swift`.

**RichTextEditor package (`RichTextEditorUIKit`):** `Mapping/StyleSheet.swift`, `Mapping/AttributedStringMapper.swift`, `Canvas/BlockquoteUnderlay.swift` (barless variant), `Canvas/DocumentCanvasView+Decorations.swift` (pill run + geometry), a new corner-mark controls view, `Canvas/BlockBox.swift` (placeholder + insets), `Canvas/BlockStack.swift` (facing/run-edge insets), `Canvas/DocumentCanvasView+Editing.swift` + `+UITextInput.swift` (escape/backspace), `Canvas/RTFConversion.swift`, `RichTextEditorView.swift` + `RichTextEditorView+ComposerHost.swift` (`pullQuoteStyle` knob, placeholder field), `QuoteStyle.swift` sibling `PullQuoteStyle.swift`.

**App-side composer / hosts:** `ChatRichTextEditorComposer/Sources/DocumentChatInputContentBridge.swift`, `RichTextEditorMessageConversion` InstantPage builder, `ChatTextInputPanelNode` (Format submenu entry), `RichTextAttachmentScreen` / `RichTextActionBarComponent` (action-bar entry).

**Assets:** reuse `Images.xcassets/Chat/Message/ReplyQuoteIcon` (no new asset).
