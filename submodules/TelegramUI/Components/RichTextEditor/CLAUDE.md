# RichTextEditor — project guide

A from-scratch **WYSIWYG rich-text editor for iOS** (UIKit, TextKit 2, iOS 17+) with images
(captions), lists, tables, links, inline custom emoji, and Telegram-style spoilers. The **defining
requirement** is **continuous selection across the whole document, including partial selection
*through* table cells** — which (per verified spike research) is only achievable with a **custom
`UITextInput` view owning one global position model**, NOT nested text views.

## Location & status in the monorepo

Moved in-tree **2026-06-09** to `submodules/TelegramUI/Components/RichTextEditor`; the standalone
`~/Documents/RichTextEditor` repo is the **pre-move archive** — it still holds the full per-phase
spec/plan/spike/handoff history and the project's original git log, none of which migrated in-tree.
Development continues here via **SwiftPM** exactly as before.

**Now wired into the app.** `ChatTextInputPanelNode` depends on `:RichTextEditorUIKit`, so both Bazel
targets — `//submodules/TelegramUI/Components/RichTextEditor:RichTextEditorCore` and
`:RichTextEditorUIKit` — **fully compile** at the repo's iOS-13 floor as part of the app build (they
previously only `--nobuild`-analyzed). The **availability pass is done** (2026-06-09): every top-level
type/extension in the UIKit target is gated `@available(iOS 17.0, *)`; `RichTextEditorCore` is
pure-Foundation and stays always-available. The two finer annotations are preserved —
`@available(iOS 17.4, *)` (the Translate edit-menu item) and `@available(iOS 18.0, *)`
(`UITextInput.isEditable`).

**Spoiler-texture resource access is build-system-split (via `#if SWIFT_PACKAGE`).** `SpoilerDustView`
resolves the particle texture two ways: under **SwiftPM** it uses `UIImage(named: "TextSpeckle", in:
.module, …)` (the generated `.module` accessor); under **Bazel** it uses the app's **`AppBundle`** —
`UIImage(bundleImageName: "Components/TextSpeckle")`, with `//submodules/AppBundle` in the UIKit
target's Bazel `deps` — because `.module` only exists under SwiftPM (it failed the Bazel compile).
`import AppBundle` is likewise gated `#if !SWIFT_PACKAGE`. So **both build systems compile**: the
Bazel/app build *and* the SwiftPM workflow (`swift test`, `Scripts/iostest.sh`, the `Demo/` app). When
editing this resource path, keep both `#if` branches in sync.

## Build & test (SwiftPM, not Bazel) — all from this directory

- **Core (UIKit-free) tests, fast:** `swift test` (runs on macOS).
- **UIKit tests, iOS simulator:** `Scripts/iostest.sh [Class/Test filter]` — wraps
  `xcodebuild test -scheme RichTextEditor-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.
  Expects an "iPhone 17 Pro" simulator booted; override with `DEVICE=…`.
- **Demo app (visual check):** `cd Demo && xcodegen generate && xcodebuild …` then
  `xcrun simctl install/launch/io screenshot`. The generated `RichTextEditorDemo.xcodeproj` is gitignored.

All UIKit sources/tests are wrapped in `#if canImport(UIKit) … #endif` so `swift test` keeps compiling
Core on macOS while the UIKit suite runs only on the simulator. The suite is ~690 tests (Core + UIKit);
the exact number is one `grep -r 'func test' Tests` away — it isn't tracked here.

## Architecture & conventions

**Two SwiftPM targets:**
- `RichTextEditorCore` — **no UIKit**: the model (`Document`/`Block`/`TextRun`/`CharacterAttributes`/…),
  JSON (`DocumentCodec`) and `.rtdoc`-package (`DocumentPackage`) serialization, the ProseMirror-style
  **global position model** (`DocumentTree` + `PositionResolver`), the selection model (`RTSelection`),
  `TableMap`, and list numbering (`ListNumbering`). Core stays UIKit-free so it's shareable and
  `swift test`-able on macOS.
- `RichTextEditorUIKit` — the views (depends on Core).

**Public surface.** `RichTextEditorView` is the **only public** type (the façade). `DocumentCanvasView`
(the multi-block editing surface) and everything else are **internal** — keeping them internal lets their
`UITextInput` witnesses stay internal (a public type conforming to public `UITextInput` would force every
witness `public`).

**The block model.** The canvas holds a `[CanvasBlock]`; conformers are `BlockBox` (paragraph),
`ImageBlockBox` (image + a first-class caption text region), and `TableBlockBox` (grid of `[[BlockStack]]`
cells). A `BlockStack` is a vertical run of blocks that backs both the document root **and each table
cell** (so the same split/merge/edit engine serves top-level and in-cell). `leafRegions()` /
`allLeafRegions()` is the recursion workhorse — selection, caret, text, and draw all iterate it,
recursing into cells.

**`+UITextInput` compile gotcha.** Any `UITextInputStringTokenizer(textInput: self)` /
`inputDelegate?.…change(self)` needs the `UITextInput` conformance to type-check, so the view class and
its `+UITextInput` extension are co-dependent and land together. Remember `import RichTextEditorCore` in
UIKit files.

## Load-bearing invariants (compiler-invisible — violating these silently breaks the editor)

- **One flat global `(anchor, head)` range, coordinate-free.** Selection is a single linear range over one
  global position axis spanning the whole document (including non-renderable structural token slots); it's
  clamped per block and the per-block `enumerateTextSegments` rects are unioned for the highlight. The
  editing engine resolves endpoints through `activeStack` / `allLeafRegions()` and is **coordinate-free** —
  all position math is validated against Core's `PositionResolver`. Geometry (views, scroll offsets,
  culling) never feeds back into the position/selection/editing model.
- **The canvas is the SOLE `UITextInput`.** Image/table/paragraph blocks render via their own pooled,
  **non-focusable** `BlockBackingView`s (the ProseMirror node-view split) — render surfaces only, never
  first responders. `caretRect`/`closestPosition`/`selectionRects`/`contentSize` derive from **box frames
  over ALL boxes**, never the realized (possibly culled) views, so off-screen view virtualization changes
  no editing/selection/nav/hit-test behavior.
- **No `UITextSelectionDisplayInteraction`; everything is own-drawn.** The canvas installs none and has
  **no `draw(_:)` override** — it is a pure container of bounded subviews (a single CALayer/CGContext can't
  back an arbitrarily tall document; GPU max-texture ~16K px). Caret (`CaretView`), selection wash
  (`SelectionHighlightView` + per-table `CellSelectionView`), and handles (`SelectionHandleView`) are
  dedicated on-top layers/views, hosted in a table's scrolling content view for cell endpoints so they
  **ride horizontal overscroll**. (Un-clamping a table's `contentOffsetX` so the OS selection UI could ride
  the bounce makes the OS text system *fight* the caret — rejected; the clamp stays and we own-draw.)
  `caretRect(for:)` must still report a **real** position even when the visible caret is hidden — it feeds
  the OS's nav/scroll/loupe/edit-menu.
- **`caretRect` is OS-facing nav geometry.** Hardware vertical arrows are driven by the OS via
  `position(from:in:direction:)` + the `selectedTextRange` setter — **not** `keyCommands` (arrow
  `keyCommands` never fire here). Vertical-nav results are `snapToRenderable`'d so the caret can't strand
  on a non-renderable structural slot.
- **Any pure `anchor`/`head` change must bracket `inputDelegate.selectionWillChange/DidChange`** — else the
  OS keeps a stale `selectedTextRange` and the next hardware arrow navigates from the wrong spot.
  (memory: `selection-changes-need-inputdelegate-bracket`)
- **Any caret-moving op must fire `onSelectionChange`** so the host can scroll-follow the caret (the
  façade's `scrollCaretIntoView`). Over-firing is safe — it early-returns when already visible and scrolls
  **non-animated** (an animated scroll races the OS arrow dispatch → nondeterministic geometry).
  (memory: `caret-moves-fire-onselectionchange-for-scroll`)
- **Display-only attributes never enter the Core model.** Inline-code, link styling, the inline-prediction
  ghost, spoiler-hide, and emoji are applied as TextKit **rendering attributes** or private storage markers
  (`.rtInlineCode` / `.rtSpoiler` / `.link`); `characterAttributes(from:)` / `currentBlock()` strip them on
  read-back so the model stays markdown-clean. The two `.foregroundColor` consumers (prediction-ghost vs
  spoiler-hide) each track + remove only their own ranges so they never clobber. A render-only display
  override (`applyDisplayOverride`, the table column-alignment / header-bold pass) **must be idempotent** —
  unconditionally re-assigning `layout.attributedString` resets the spoiler-hide ranges every layout pass
  → an infinite `layoutIfNeeded` loop; only assign when the rebuilt string actually differs.
- **Emoji and the spoiler atom are a single `U+FFFC`** carrying their ref in `CharacterAttributes` — exactly
  1 UTF-16 position, so `DocumentTree`/`PositionResolver`/the editing engine/tokenizer are untouched.
  Host-provided `UIView`s are pooled by `instanceID`, hosted in the canvas overlay (body/caption) or the
  table's content view (cells, ride H-scroll), and culled.
- **Gesture arbitration is gate-only.** Handle/knob pan vs scroll pan is resolved *only* via
  `gestureRecognizerShouldBegin` — never `require(toFail:)` or forced simultaneous recognition. The
  single-tap recognizer fires immediately with manual multi-tap escalation in `handleTap` (no
  double-tap-failure delay); the host scroll view sets `delaysContentTouches = false`.
- **Word/paragraph boundaries come from the custom `DocumentTokenizer`**, which scans each leaf region's OWN
  string — not the global axis (whose structural slots the stock tokenizer mis-reads, gluing regions with
  no separator).
- **Marked text / IME is storage-backed** (body paragraphs only today): composing text is applied
  **outside** `editing{}` with one undo per composition; a system inline prediction (signalled by
  `setMarkedText` `sel:{0,0}`, ghost trailing) is **dismissed, never committed**, by our finalize
  chokepoints so the keyboard's own accept lands clean.
- **PRIVATE API risk:** `SpoilerDustView` uses `CAEmitterBehavior` (`createEmitterBehavior`) for the
  twinkle + finger-attractor explosion — App-Store-review risk, guarded by a live canary test.
- **View-frame ownership** (the repo-wide rule applies here too): a reusable component lays out against
  `self.bounds`; it never writes `self.frame` — the parent positions it.

## Known render-only trade-offs (revisit when the markdown layer separates style traits from char emphasis)

These keep the model markdown-clean at the cost of not separately preserving a user override: **(1)** a
link run's `foreground`/`underline` styling is render-only (suppressed on read-back); **(2)** down-converting
a heading to body can leave residual bold; **(3)** table **header-row** bold is render-only, so user-bold
inside a header cell isn't separately preserved.

## Status

**Done** (model + editing + rendering all in place): the Core model, global position model, and JSON/`.rtdoc`
serialization; continuous **cross-block and partial-cross-cell selection + editing** — the headline
requirement, incl. editing across stacks via `applyReplace` / `applyMultiRegionClear`; structural editing
(Enter splits / Backspace merges / cross-block delete) with snapshot undo; **lists** (rendering +
`setList` / indent / outdent), **images** (caption + gap cursor + selection highlight), **tables**
(rendering, cross-cell caret & Tab nav, in-cell editing, row/column insert-delete + per-column alignment +
header row, in-canvas row/column controls + multi-row/column range selection); **formatting**
(bold/italic/strike/inline-code/underline, paragraph styles Title/H1–H3/Body/Quote, alignment, links);
**insert** table/image; the **iOS-standard touch model** (tap-caret, double/triple select, long-press
loupe, handle-drag) + **system edit menu** (Look Up / Translate / Share / Format / basic Writing Tools);
**visual design alignment**; **inline predictive text + marked-text/IME**; **inline custom emoji**; the
**block-view architecture** (every block in its own bounded layer; per-table horizontal scroll; off-screen
**view virtualization**); and the **Telegram-style spoiler effect**.

**Next — Phase 5c, the markdown backbone: a Markdown serializer/parser (model ↔ GFM)** — pipe tables (incl.
the alignment delimiter row), ATX headings, bullet/ordered lists, emphasis, inline code, links, images,
blockquote. The editor **targets markdown editing**, so filter every new feature to what GFM can represent:
prefer bold/italic/strike/inline-code/links/headings/blockquote; **defer or treat as non-persisted** the
attributes with no markdown form (highlight/foreground color, font family/size, super/subscript baseline).

**Other open work:** Phase 5d copy/paste (rich within-doc; markdown/plain across apps; multi-line paste);
Phase 5e images toolbar (Photos/Files picker, alignment toggle, interactive drag-resize); Phase 6b new
paragraph styles (Subtitle / Code / Caption) + a Dash list marker; Phase 6c floating pill keyboard toolbar
with active-state (`currentFormatState()`), replacing the crude demo toolbar; block-view **Step 3**
(arbitrary non-focusable embeds); perf follow-ups (viewport-size the wash/chrome overlays; incremental
layout; emoji count-virtualization); spoiler a11y (VoiceOver hiding of unrevealed text) + markdown
`||spoiler||`.

## Workflow

Phase-by-phase, each its own cycle: **brainstorm (`superpowers:brainstorming`) → spec → plan → TDD /
`superpowers:subagent-driven-development` (test after each task) → holistic review →
`superpowers:finishing-a-development-branch`** on a feature branch. Commit messages end with the
`Co-Authored-By` trailer.

**Design docs are not in-tree.** The per-phase specs, plans, spike findings, and handoffs live only in the
pre-move archive at `~/Documents/RichTextEditor/docs/superpowers/{specs,plans,spikes,handoffs}/`. The
foundational two: the main design spec (`2026-05-30-ios-rich-text-editor-design.md`) and the
table-selection **spike findings** (`2026-05-30-table-selection-spike-findings.md` — the API learnings that
drove the single-`UITextInput` architecture and its caveats).
