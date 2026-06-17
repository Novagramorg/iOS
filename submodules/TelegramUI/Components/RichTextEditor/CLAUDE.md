# RichTextEditor — project guide

A from-scratch **WYSIWYG rich-text editor for iOS** (UIKit; TextKit 2 on iOS 16+, TextKit 1 on iOS 13–15;
floor **iOS 13**) with images
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
`:RichTextEditorUIKit` — **fully compile and run down to iOS 13** as part of the app build.

**Dual layout-engine back-port (2026-06-17).** TextKit was quarantined behind a one-method-per-call seam,
`protocol BlockLayoutEngine` (`Layout/BlockLayoutEngine.swift`), so the layout engine is swappable:
`BlockLayout` (TextKit 2, `@available(iOS 16.0, *)`) on iOS 16+, and **`BlockLayoutTK1`** (TextKit 1, iOS 7+,
ungated) on iOS 13–15. `makeBlockLayout(...)` picks TK2 on iOS 16+ / TK1 below; the runtime debug toggle
`BlockLayoutBackend.forceTextKit1` (DEBUG default `true`) forces TK1 on any OS for testing the back-port. The
system edit menu likewise falls back from `UIEditMenuInteraction` (iOS 16+) to **`UIMenuController`** (iOS
13–15) — see `DocumentCanvasView+EditMenu` (shared responder actions; custom items become flat `UIMenuItem`s).

So **the UIKit target is gated `@available(iOS 13.0, *)`** (`RichTextEditorCore` is pure-Foundation,
always-available), with only genuine higher-OS APIs kept at their real floor: the TK2 `BlockLayout` type + the
4 `UIEditMenuInteraction` touch-points at **iOS 16**; the magnifier loupe (`UITextLoupeSession`) +
`inlinePredictionType` at **iOS 17**; Translate at **17.4**; `isEditable` at **18**. **TK1 trade-offs on iOS
13–15** (deliberate): no spoiler text-hiding (UIKit `NSLayoutManager` has no rendering/temporary-attribute
analog), no loupe, no inline predictions — everything else (editing, tables, lists, links, emoji, selection,
IME, edit menu) works. Full SwiftPM suite is green on both engines (TK1 via the DEBUG `forceTextKit1`). The
app-side consumers (`RichTextEditorChatInputNode`, `RichTextAttachmentScreen` + its helpers,
`StandaloneInstantPageImageView`) are also lowered to iOS 13; the editor still only appears behind the
`debugRichText` ("Debug Text") experimental flag.

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

**Public surface.** `RichTextEditorView` is the **only public** type (the façade), with the small value type
`RichTextEditorPlaceholders` (a config struct, below). `DocumentCanvasView` (the multi-block editing surface)
and everything else are **internal** — keeping them internal lets their `UITextInput` witnesses stay internal
(a public type conforming to public `UITextInput` would force every witness `public`).

**Compact-host (chat-composer) configuration knobs (added 2026-06-16, `RichTextEditorView+ComposerHost.swift`).**
The editor's defaults assume a full-page document; a compact host (the chat composer,
`ChatRichTextEditorComposer`) tunes these via the façade. **Every knob defaults to the document-editor
behavior, so the attachment screen / Demo / SwiftPM tests are unchanged.** The composer sets each in `didLoad`
*before* seeding the document so the first layout picks them up:
- `contentPageMargin` (default `CanvasMetrics.pageMargin` = 16) — the built-in horizontal page margin on each
  side (`DocumentCanvasView.pageMargin`, used by `contentLeftPad`/`contentRightPad`; `MediaBlockBox` image
  bleed keeps the static metric). Composer → 0.
- `minimumContentHeight` (default 44) — the floor `performLayout` applies to the returned content height.
  Composer → 0 (the height hugs the text; the host owns the min field height).
- `blockVerticalInset` (default `BlockBox.defaultVerticalInset` = 8) — the root stack's base inter-block
  vertical inset (`BlockStack.verticalInsetBase`; nested table-cell stacks keep the default). Composer → 0 so a
  lone paragraph hugs its one-line height.
- `placeholders` (`RichTextEditorPlaceholders`, default = "Type something…" + the two list hints) — the empty-
  paragraph placeholder strings, stamped onto top-level boxes in `stampListMarkers`; an empty string for a case
  draws nothing. Composer → all "".
- `canvasBackgroundColor` (default `.systemBackground`, the document "page") — the canvas background; the
  scroll view + `BlockBackingView`s are already clear. Composer → `nil` (transparent over the input panel).

Two host-side runtime contracts the composer had to honor (apply to any non-attachment host): **seed an initial
`document`** (the canvas starts with ZERO blocks; nothing renders/edits until the `document` setter runs), and
**re-run `update(...)` in response to `onChange`** (the view is parent-driven and does not self-layout on a
content change — without this, typed text is never laid out).

**Dynamic theme (added 2026-06-17, `Theme/RichTextEditorTheme.swift`).** `RichTextEditorView.theme:
RichTextEditorTheme` is a host-settable struct of six UIColors; assigning it updates the mapper, pushes the
accent to the caret/selection-handles/blockquote views, reloads (so boxes rebuild with the themed mapper), and
redraws. **`.default` reproduces the editor's prior hardcoded colors exactly, so the look is unchanged until a
host sets a theme.** Host wiring so far (2026-06-17): the **chat composer** wires it — `ChatTextInputPanelNode`
maps `PresentationTheme` → `ChatRichTextThemeColors` (a `UIColor`-only seam type in `ChatInputTextNode`) and
pushes it via `ChatRichTextInputNode.applyRichTextTheme`, which `RichTextEditorChatInputNode` maps to this
`theme`. `RichTextAttachmentScreen` does **not** wire a theme yet (still a follow-up). What each color drives:
- `primaryText` (default `.black`) — default foreground for runs with no explicit color.
- `secondaryText` (default `.black`) — default foreground for `.caption`-style runs.
- `placeholder` (default `.placeholderText`) — empty-paragraph, marked-text ghost, and media placeholder text.
- `accent` (default `.link`) — link text, the blockquote bar + fill, the caret, and the selection visuals
  (handles via a pushed `accentColor`; the body/cell selection *wash* reads `mapper.theme.accent` live).
- `tableBorder` (default the prior dynamic grid color) / `tableHeaderBackground` (default `white 0.5/0.1`) — the
  table grid stroke and header-row fill (the former `TableBlockBox.gridColor`/`headerRowBackground` statics).

**Round-trip invariant (load-bearing):** theme colors are applied at render time only and **never persist into the
`Document`**. `AttributedStringMapper` is symmetric — the forward pass injects the per-style default
(`secondaryText` for `.caption`, else `primaryText`) for un-colored runs; the reverse (`characterAttributes(from:
style:)` / `runs(from:style:)`) strips a foreground equal to that per-style default back to `nil`. Every
reverse-mapper caller MUST pass the run's paragraph style (`BlockBox` → its style, `MediaBlockBox` captions →
`.caption`, `+Editing` → the start box's style; `+State` reads only format flags, so its `.body` default is fine)
— a wrong style compares against the wrong default and pollutes the model. An explicit user color exactly equal to
the style default is also stripped (visually identical, re-themable). Known limitations: list markers stay
`.label`, spoiler dust + table-control chrome stay system colors, and removing a link inside a `.caption` run
under a theme where `primaryText != secondaryText` leaves an explicit foreground (latent; see `removeLink`).

**Host input hooks (added 2026-06-12 for the emoji keyboard).** The façade exposes three generic, UIKit-only
input hooks so a consumer can drive a custom input panel: `insertText(_:)` (plain text at the caret, one undo
step), `deleteBackward()`, and `customInputView: UIView?` (forwarded to the canvas's `inputView` +
`reloadInputViews()` — set an `EmptyInputView` to suppress the system keyboard *while the canvas stays first
responder*, so the caret keeps rendering under a separate panel). The actual Telegram **emoji keyboard** is
wired **consumer-side** in `RichTextAttachmentScreen` (`RichTextEmojiKeyboardController`, hosting
`ChatEntityKeyboardInputNode`) — the package itself stays free of `AccountContext`/TelegramUI. Custom emoji
insert via the existing `insertEmoji(id:altText:)` (id = the Telegram fileId string) + a host
`registerEmojiViewProvider` that renders an `InlineStickerItemLayer`.

**Parent-driven layout + state query (added 2026-06-12, branch `feature/richtext-message-serialization`).**
The façade is now driven by its host rather than self-laying-out:
- `update(size:insets:) -> CGFloat` — the parent supplies the frame `size` and scroll `insets` (it owns the
  keyboard/panel inset, e.g. from `environment.inputHeight`); returns the measured content height. The view
  set `scrollView.contentInsetAdjustmentBehavior = .never` and **removed all `UIResponder` keyboard
  observation**. A private `performLayout(size:)` sizes the scroll view/canvas; only `update` writes insets
  (so a system `layoutSubviews` pass can't clobber the parent inset). Caret-follow scrolling stays internal.
- `onChange: (() -> Void)?` — payload-free; fires on any edit, content-size change, or selection move
  (funneled from the canvas's `onContentSizeChange` + `onSelectionChange`, the latter fired unconditionally by
  `editing { }`). The host re-runs its layout (→ `update`) in response. **`update` must NOT synchronously fire
  `onChange`** (would recurse) — guarded by a regression test.
- `currentState() -> EditorState` — a pure read (bold/italic/underline/strikethrough/code, paragraphStyle,
  listMarker, link, hasSelection, isInTable, canUndo, canRedo) built from canvas internals; drives a host
  toolbar's per-action availability + selected state. Inline flags are uniform-over-selection, or the caret's
  inherited run format when collapsed. The 5 format predicates are extracted (`rangeIsBold` etc.) and shared
  by the `toggle*` commands and `currentState`.
- `deleteTable()` — removes the caret's table (one undo step; caret lands on the successor block, or a fresh
  empty paragraph if it was the only block). No-op when not in a table. (Caret-based; a structural-selection
  delete is deferred.)
- `composerSelectedRange: NSRange { get set }` — the selection in the **chat composer's flat UTF-16
  coordinate space** (the document's top-level paragraphs joined by `"\n"`, exactly the
  `ComposerDocumentBridge` flattening; non-paragraph blocks contribute nothing). Maps that flat offset
  to/from the editor's global selection axis (which carries non-renderable structural slots between blocks),
  collapsing each paragraph break to one `"\n"` so a multi-UTF-16-unit emoji + the separators line up 1:1
  with what `ChatTextInputPanelNode` inserts. **This is load-bearing for the chat composer:**
  `RichTextEditorChatInputNode.selectedRange` forwards to it, and the panel drives ALL insert/replace/caret
  moves off `selectedRange`. While it was a stub (getter = end-of-text, setter = no-op) the panel was
  selection-blind — the caret never advanced after a programmatic insert and a surrogate-pair emoji was split
  on a delete/insert cycle, leaving a stray code unit (a "service character"). The setter brackets
  `selectionWillChange/DidChange` (programmatic move). Implemented in `DocumentCanvasView+ComposerSelection`.

**Host edit-menu hook (added 2026-06-17, `RichTextEditorView` + `DocumentCanvasView+EditMenuActions`).**
`contextMenuItemsProvider: ((_ defaultElements: [UIMenuElement]) -> [UIMenuElement])?` lets a host **transform**
the iOS-16 edit menu. The editor calls it from `editMenuInteraction(_:menuFor:suggestedActions:)` with
`defaultElements` = the system suggested actions (Cut/Copy/Paste/Select + Writing Tools) **followed by the
editor's own custom items** (the built-in "Format" submenu + Look Up / Translate / Share); the host returns the
final children. Consulted **only for a non-collapsed selection** (matches `customEditMenuElements()`' own gating)
and **only on iOS 16+** — on iOS 13–15 (`UIMenuController`) host items are NOT injected (a `UIMenuItem` needs an
Obj-C `#selector` and can't carry a closure; `UIAction` hides its handler, so the closure-based host items can't
be bridged). `nil` ⇒ the editor's default menu, unchanged. The chat composer (`ChatTextInputPanelNode`) uses it
to drop the editor's 3-item built-in Format submenu and splice in its richer 10-item one (Bold/Italic/Monospace/
Link/Strikethrough/Underline/Quote/Spoiler/Date/Code, secret-chat gated), routing each to the editor's native
engine (`toggleBold()` etc.; Quote → `setParagraphStyle(.quote)`; Date/Code are deferred no-ops); Link reuses the
host link UI (a branched `openLinkEditing` in `ChatControllerLoadDisplayNode`, using `currentLink()` /
`selectedText()` / `setLink`/`removeLink`). `selectedText() -> String` is the selected substring (for that link
editor). Spec/plan for this work were intentionally not retained in-tree.

**Load-bearing invariant — the iOS-16 edit menu needs `Display.Window1.hitTest` to forward to it.**
`UIEditMenuInteraction` hosts its menu in a top-level `_UIEditMenuContainerView` subview of the app window.
Telegram's `Window1.hitTest` (`submodules/Display/Source/WindowContent.swift`) only forwards touches to window
subviews whose class matches an allow-list; it was extended (2026-06-17) to match `"EditMenu"` (alongside the
pre-iOS-16 `"UITransitionView"` / `"ContextMenuContainerView"`). **Without that match, taps on the menu fall
through to the content below and every item is inert** — the symptom that surfaced first here because this is a
custom `UITextInput` presenting `UIEditMenuInteraction` directly. Any editor change that relies on the system
edit menu being interactive in the Telegram app depends on this allow-list entry.

**Deferred:** pending caret formatting (inline toggles at a *collapsed* caret are currently inert — they show
the inherited state but don't affect the next typed char); table structural selection; code-block paragraph
style + timestamp-entity model (the composer's Code/Date menu items are no-ops until these land).

The host action bar (12 icon actions + ContextUI context menus) lives in the separate `RichTextAttachmentScreen`
module, not this package. Full session handoff: `~/Documents/RichTextEditor/docs/superpowers/handoffs/2026-06-12-richtext-session-handoff.md`.

**Session updates (2026-06-13 → 06-16, branch `feature/richtext-message-serialization`).** All TDD'd, full
SwiftPM suite green (657 UIKit tests + Core). No runtime/app pass yet; the conversion + `RichTextAttachmentScreen`
+ Demo edits are Bazel/xcodegen (not SwiftPM-compiled) so verified by inspection only. The later items
(edit-menu auto-dismiss, Select-All-image delete, quote affordances, content margins, the parent-driven layout
sweep) extend this block below; the layout sweep also has a spec/plan pair in
`docs/superpowers/{specs,plans}/2026-06-16-richtext-parent-driven-layout*`.
- **Type scale + `Title` removed.** `ParagraphStyleName` is now `heading1, heading2, heading3, body, caption,
  quote` (no `title`; no backwards-compat decode shim — a persisted `"title"` simply fails to decode). Sizes
  (`StyleSheet`): H1 24 / H2 21 / H3 19 **serif**, Body 17 sans, Caption 15 sans, Quote 17 sans. **`caption`
  is a render-only style** (media-block captions, 15pt) — never offered in the picker, never persists as a
  paragraph style (a caption serializes as the MediaBlock's runs); `MediaBlockBox` lays the caption out as
  `.caption`. Exhaustive `switch ParagraphStyleName` sites (StyleSheet ×2, conversion ×2) all carry `.caption`.
- **`DocumentMetadata` removed entirely** → `Document { schemaVersion, blocks }` (it had become a vestigial
  single-`title` wrapper that nothing read; the doc's title is a `.heading1` block). `DocumentCodec` dropped
  its now-dead ISO-8601 date strategy.
- **First-responder callbacks** on the façade: `onBecameFirstResponder` / `onResignedFirstResponder`, each
  fires **once on the genuine transition** (the canvas `becomeFirstResponder()`/`resignFirstResponder()`
  capture `wasFirstResponder` before `super`), so a repeat tap while already focused doesn't re-fire.
- **Taps land anywhere in the unobscured editor**, not only on text. `performLayout` floors the canvas height
  at the **visible** viewport (`size.height − contentInset.top − bottom`, read from the just-applied insets),
  so the canvas (which owns the tap/long-press/loupe recognizers) covers the empty area below a short doc;
  `closestGlobalPosition` maps such taps to the nearest position (doc end), matching UITextView. Flooring at
  the *visible* (not full-frame) height keeps `scrollView.contentSize == visible area` for a short doc → zero
  scrollable range (no phantom bounce over the inset bands) and it re-flows when insets change. `update`
  returns the real **content** height (unchanged contract).
- **`contentMargins` (`UIEdgeInsets`) is distinct from the scroll insets.** Insets are non-interactable bands
  the content scrolls UNDER (nav bar / keyboard / input panel, applied via `update(size:insets:)` →
  `scrollView.contentInset`). Margins are interior padding that is PART of the content: on the canvas, the text
  lays out inset by them — `root.layout(origin: (pageMargin + margins.left, margins.top), …)`, content width
  `= bounds.width − (pageMargin + left) − (pageMargin + right)` (additive to the built-in 16pt `pageMargin`),
  and `intrinsicContentSize.height` grows by `top + bottom`. Because the margin sits INSIDE the canvas, its
  area still hit-tests (a tap there places the caret at the nearest position) — unlike an inset. Both
  `setParagraphsWidthIfNeeded` and `layoutSubviews` derive width from the shared `contentWidth(forWidth:)`
  helper so they can't drift. **Applied via `RichTextEditorView.update(size:insets:contentMargins: = .zero)`**,
  alongside `insets` — NOT a side-effecting property. General rule (project convention): any setting that
  triggers re-load / re-layout / re-draw belongs in `update`, not a property whose setter hides a layout pass.
  `contentMargins` is a **plain stored value** on the canvas (read by `layoutContent()` / `intrinsicContentSize`,
  persisted across system passes); the setter does NOT `setNeedsLayout()` and does NOT fire
  `onContentSizeChange`/`onChange`. Instead the `update` that sets it re-runs `performLayout`, which lays the
  canvas out **explicitly** via `canvas.layoutContent()` (the body of `layoutSubviews`, factored out) rather
  than `layoutIfNeeded()` — so the new value takes effect even when the canvas frame is unchanged (e.g. a short
  doc whose height is floored to the viewport, where only top/bottom margins changed). A test asserts
  `update(...contentMargins:)` does not synchronously fire `onChange`.

  **Layout convention.** The parent drives layout explicitly (`performLayout` → `canvas.layoutContent()`)
  and a view never `setNeedsLayout()`s itself for a content-height change — it calls `notifyContentSizeChanged()`
  (fires `onContentSizeChange` → the host's `onChange`, which re-calls `update`). Every height-affecting path
  follows this: `editing { }`, the IME marked-text commit/update, `setBlocks`, and the undo block call
  `notifyContentSizeChanged()` only; the façade's `onContentSizeChange` is a **pure relay** (`onChange` only),
  and where the façade needs fresh geometry synchronously it lays out explicitly — `scrollCaretIntoView` and
  the `document` setter call `performLayout(size: bounds.size)`. The old `invalidateIntrinsicContentSize()`
  override is gone (its only job was firing `onContentSizeChange`, and it carried an implicit UIKit layout
  schedule). **Canvas-direct tests** that read post-edit geometry install `simulateParentLayout()` (a test-only
  hook that re-lays-out on the content-size notification, simulating the real parent) instead of relying on the
  UIKit `needsLayout` flag. **Out of scope** (do NOT affect content height, kept as UIKit-internal mechanism):
  `setNeedsDisplay` (repaint), `syncSpoilers`' reveal re-layout, and the parent→child `view.setNeedsLayout()` /
  `tv.layoutIfNeeded()` on block/table backing views.
- **Backspace at a media block's leading gap no longer deletes the media** (`deleteBackward`): a tap-SELECTED
  media atom still deletes (gated on `imageSelection != nil`); a plain caret at the gap acts on the previous
  paragraph instead — non-empty → move the caret to its end (no delete), empty → delete that paragraph
  (`deleteBlock(at:parkingCaretAtGapOf:)`, caret stays at the media gap); first block / non-paragraph previous
  → move to the previous caret slot (no-op at doc start).
- **Select All + backspace removes a covered image, even a leading/trailing one** (`applyReplace` cross-block).
  A media endpoint is now dropped when the selection covers its **whole node** (leading gap + entire caption:
  `lo <= box.nodeStart && hi >= box.textStart + box.textLength`), so the merge path's `replaceSubrange(start...
  end)` clears it like a covered MIDDLE image already was. A **partially**-covered media endpoint (selection
  starts/ends partway through a caption) still truncates-and-keeps (the Phase 2c behavior). Previously only
  middle images were dropped; an image at a selection endpoint (which Select All always makes of the first/last
  block) was truncate-kept, so CMD+A then Backspace left the image behind. The paragraph↔paragraph merge is the
  same path generalized: a fully-covered media endpoint contributes no runs, and the merged paragraph inherits
  the start block's style (else the end's, else a fresh body paragraph when both endpoints were media).
- **Quote-block escape/delete affordances** (a `quote` is a `BlockBox` with `style == .quote`). Three behaviors,
  each top-level only (an in-table quote keeps the cell behaviors): **(A)** Backspace in an **empty** quote
  un-quotes it (`style = .body; restyle`) instead of doing nothing — an empty quote, especially the document's
  FIRST block, otherwise matched no `deleteBackward` branch and was undeletable. Mirrors empty-list-item Return.
  A non-empty quote's backspace still just deletes a char. **(B)** Tapping in the empty area **below a trailing
  quote** (`point.y > boxes.last.frame.maxY` && last is a `.quote`) inserts a new empty body paragraph after it
  (`insertEmptyBodyParagraph(at:)`) — the only way to start a normal paragraph after a quote that ends the doc.
  **(C)** **Shift+Return** inside a quote EXITS it with a new empty body paragraph (caret there): **ABOVE** the
  quote when the caret is on its first visual (wrapped) line (`caretIsOnFirstLine` — compares the caret's `minY`
  to offset 0's), else **BELOW** it. So a single-line / empty quote (caret always on its first line) exits
  ABOVE; a multi-line quote exits above only from the first wrapped line, else below. Outside a quote it falls
  back to a normal paragraph break. Wired via a new `UIKeyCommand(input: "\r", modifierFlags: .shift)` —
  hardware-keyboard only, so the key-command dispatch is runtime-unverified (the `performShiftReturn` logic is
  unit-tested; if "\r" doesn't match, Shift+Return falls back to `insertText("\n")`).
- **"Type something…" placeholder shows only on the document's LAST block** (`BlockBox.isLastBlock`, stamped
  in `stampListMarkers` like `isTopLevelBlock`); an empty body paragraph elsewhere shows no placeholder (list
  hints are unaffected). An empty non-last paragraph still reserves its line + caret — only the hint is gone.
- **Selection highlight is UITextView-style** via a NEW draw-only `DocumentCanvasView.selectionHighlightRects`
  + `BlockLayout.selectionFillRects(start:end:fillTrailingLine:)` (used ONLY by `drawNonTableSelectionHighlight`).
  A line covered to its end fills to the container trailing edge; a line covered from its beginning fills to
  the leading edge (x=0) — so an indented quote/list fills full-width on covered lines (first line included,
  via `start == 0`) instead of hugging the indent; an empty line spanned by the selection gets a synthesized
  full-width row. The glyph-hugging **`selectionRects` is unchanged** — it still feeds the OS witness,
  edit-menu position, spoiler-dust geometry, and marked-text underline. (Body/caption only; table-cell
  selection still uses glyph-hugging rects — a deferred consistency follow-up.)
- **Edit menu auto-dismisses on any text/selection change** (native UITextView behavior). The canvas owns its
  own `UIEditMenuInteraction`, which — once presented — does NOT self-dismiss on a selection change (it just
  repositions via `targetRectFor`), so the canvas must call `dismissMenu()` itself. A new
  `dismissEditMenuForSelectionOrTextChange()` is called from the three selection setters (`setCaret` /
  `setSelectionHead` / `setSelectionAnchor`), the UITextInput **`selectedTextRange` setter** (the system path:
  keyboard cursor-drag / autocorrect / predictive text), and the `editing { }` text-mutation wrapper — so
  typing, deleting, programmatic + gesture + system caret moves, and boundary-move backspaces all close the menu.
  The dismiss is **UNCONDITIONAL — NOT gated on `editMenuVisible`**: the system flips that flag to false on a
  touch-down BEFORE the gesture's setter runs, so gating on it skipped the dismiss exactly when the user moved
  the cursor (the bug); `dismissMenu()` on a non-presented interaction is a harmless no-op. The
  present-after-change gesture flows — Select / Select All / double-/triple-tap / handle-drag `.ended` /
  long-press `.ended` — are unaffected because they change the selection via `applySelection` (deliberately
  NOT a dismiss point) and call `presentEditMenu()` AFTER any setter. `applySelection` stays out of the hook
  for exactly this reason.

**Compiler-invisible invariant (block-view repaint gate).** `bindRealizedView` forces a repaint when the box
**instance** bound to a realized view changes (`view.box !== box`), in addition to the `renderSignature` gate.
A structural edit (Enter-split / Backspace-merge) keeps a surviving block's `BlockID` but swaps its `BlockBox`
for a brand-new one whose fresh `BlockLayout` resets `renderVersion` to 0 — and `renderVersion` is per-instance,
so comparing it across the replacement is meaningless (a same-height/style upper half collided with the old
signature and skipped the repaint, leaving the pre-split full-text bitmap). The lower half always gets a new
`BlockID` → fresh view → always repaints, which is why only the surviving (upper) half went stale.

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
  (memory: `selection-changes-need-inputdelegate-bracket`) **This includes EDITS**, not just pure selection
  moves: `editing { }` and the undo closure bracket BOTH `text*` and `selection*` (like `reload`), because
  every edit also moves the caret. Omitting the selection bracket is invisible under system-keyboard typing
  (UIKit owns the selection there) but breaks **programmatic** inserts — e.g. the custom emoji keyboard:
  the caret appeared not to advance and a re-insert dropped a stray bare `U+FFFC` "service character".
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
- **Caret placement snaps to composed-character boundaries — never mid-emoji.** `closestOffset(toPoint:)`
  (both `BlockLayout` and `BlockLayoutTK1`) skips offsets INSIDE a composed character sequence (surrogate
  pair / ZWJ / variation-selector emoji), so a tap can only land on a grapheme boundary. Without this a tap
  near an emoji places the caret mid-cluster, and the next insert/delete (incl. via the chat composer's
  `selectedRange`) splits the cluster → a stray code unit (the "service character"). Pairs with the
  grapheme-aware `deleteBackward` below — both keep the editor surrogate-safe.
- **Range delete/replace expands to whole grapheme clusters.** `applySelectionReplace` (THE chokepoint for
  every selection-replacing edit — delete, type-over, paste, `replace(_:withText:)`) runs
  `rangeExpandedToGraphemeBoundaries` first, so a range covering only PART of a composed sequence is widened
  to the whole cluster. This is load-bearing for the **chat composer**: the OS delivers backspace there as a
  RANGE delete (`selFrom≠selTo`) that can cover just one half of a surrogate-pair emoji — deleting it verbatim
  left a lone surrogate (rendered `U+FFFD`), the composer "service character". The collapsed-caret
  `deleteBackward` grapheme snap did NOT cover this path; the expansion does.
- **Left/right arrow navigation moves a whole grapheme, not one UTF-16 unit.** The OS drives horizontal
  arrows through `position(from:in:direction:)` → `nextTextPosition`/`prevTextPosition`; the within-region
  step advances by `rangeOfComposedCharacterSequence`, so one press crosses a whole emoji. Stepping one
  UTF-16 unit lands the caret mid-surrogate (renders at the same glyph edge → looks stuck), so crossing an
  emoji took two presses. (The OS also *probes* `position(from:offset:±1)`, which is NOT grapheme-aware and
  can return a mid-surrogate offset, but it doesn't drive the caret — the move is `position(in:direction:)` +
  the `selectedTextRange` setter with grapheme-aligned values. A latent follow-up if shift+arrow selection
  ever needs sub-grapheme hardening.)
- **Backspace deletes a whole grapheme cluster, not one UTF-16 unit.** `deleteBackward`'s in-place delete
  (both the top-level and in-cell branches) removes `graphemeClusterLengthBeforeCaret(global:)` units, not a
  hardcoded 1 — so a *standard* Unicode emoji typed from the system keyboard (surrogate-pair scalar, ZWJ
  sequence, skin-tone / flag / variation-selector combo, all multi-UTF-16-unit) is removed as one unit
  instead of leaving an orphaned half. Computed via `rangeOfComposedCharacterSequence` on the leaf region's
  own string (the global axis is 1:1 with UTF-16 inside a region; a grapheme never spans regions). A
  custom-emoji `U+FFFC` and any plain BMP char are single-unit clusters, so it's a no-op for them.
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
link run's `foreground`/`underline` styling is render-only (suppressed on read-back); **(2)** table
**header-row** bold is render-only, so user-bold inside a header cell isn't separately preserved.

Headings are **regular weight by default** (`StyleSheet.font` does not force bold for them — they read as
larger serif); bold is a pure user-emphasis toggle that round-trips uniformly across every style. (This
replaced the earlier behavior where headings baked bold into their font, which leaked `**bold**` into the
model and left residual bold on a heading→body down-convert.) Type scale (2026-06-13): H1 24 / H2 21 / H3 19
serif, Body 17 sans, Caption 15 sans, Quote 17 sans — see the 2026-06-13 session block above.

## Status

**Done** (model + editing + rendering all in place): the Core model, global position model, and JSON/`.rtdoc`
serialization; continuous **cross-block and partial-cross-cell selection + editing** — the headline
requirement, incl. editing across stacks via `applyReplace` / `applyMultiRegionClear`; structural editing
(Enter splits / Backspace merges / cross-block delete) with snapshot undo; **lists** (rendering +
`setList` / indent / outdent), **images** (caption + gap cursor + selection highlight), **tables**
(rendering, cross-cell caret & Tab nav, in-cell editing, row/column insert-delete + per-column alignment +
header row, in-canvas row/column controls + multi-row/column range selection); **formatting**
(bold/italic/strike/inline-code/underline, paragraph styles H1–H3/Body/Quote, alignment, links);
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
paragraph styles (Subtitle / Code) + a Dash list marker (Caption landed 2026-06-13 as a render-only style); Phase 6c floating pill keyboard toolbar
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
