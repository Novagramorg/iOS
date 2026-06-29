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
`BlockLayoutBackend.forceTextKit1` forces TK1 on any OS for testing the back-port (currently `#if DEBUG &&
false` → **off** even in debug, so the running app uses TK2 on iOS 16+; flip the `&& false` to opt in). The
system edit menu likewise falls back from `UIEditMenuInteraction` (iOS 16+) to **`UIMenuController`** (iOS
13–15) — see `DocumentCanvasView+EditMenu` (shared responder actions; custom items become flat `UIMenuItem`s).

**Line-height centering (2026-06-26).** The per-style render `lineHeightMultiple` (`StyleSheet.metrics`: body/
caption/quote 1.10, headings 1.05) makes each line-fragment box — the box the selection wash + caret fill —
taller than the glyphs, and **TextKit (both engines) dumps ALL that extra leading ABOVE the glyphs** (the
baseline drops; measured ~2pt on top / 0 below for 17pt body), so the text reads as offset too low in its
rect. Both engines now **center** the glyphs in the box while keeping the box's full (spacing-preserving)
height: glyphs are raised by half the extra leading. BOTH engines apply the SAME `centeringDelta(lineHeight:)`
= `lineHeight·(1−1/m)/2` (m = the paragraph `lineHeightMultiple`) at glyph-draw / `attachmentBox` /
`firstLineBaselineFromTop` time, while caret/selection rects keep the full box. (The TextKit-1
`NSLayoutManagerDelegate.shouldSetLineFragmentRect…baselineOffset` baseline hook — the "native" way to do this
on TK1 — is **NOT invoked** under the TextKit-2-backed `NSLayoutManager` on modern iOS, verified at runtime, so
`BlockLayoutTK1` does the manual draw/geometry shift too rather than relying on it.) **Why not `baselineOffset`**
(the attribute): it's a real `CharacterAttributes` field (sub/superscript) and would round-trip into the
model — centering must stay a render-only layout concern. Verified on both engines by `LineHeightCenteringTests`
(glyph top-gap ≈ bottom-gap). This is editor-wide (document + composer), so a composer line keeps real 1.10
spacing with centered text — no composer-specific line-height knob.

So **the UIKit target is gated `@available(iOS 13.0, *)`** (`RichTextEditorCore` is pure-Foundation,
always-available), with only genuine higher-OS APIs kept at their real floor: the TK2 `BlockLayout` type + the
4 `UIEditMenuInteraction` touch-points at **iOS 16**; the magnifier loupe (`UITextLoupeSession`) +
`inlinePredictionType` at **iOS 17**; Translate at **17.4**; `isEditable` at **18**. **TK1 trade-offs on iOS
13–15** (deliberate): no spoiler text-hiding (UIKit `NSLayoutManager` has no rendering/temporary-attribute
analog), no loupe, no inline predictions — everything else (editing, tables, lists, links, emoji, selection,
IME, edit menu) works. Full SwiftPM suite is green on both engines (TK1 via the DEBUG `forceTextKit1`). The
app-side consumers (`RichTextEditorChatInputNode`, `RichTextAttachmentScreen` + its helpers,
`StandaloneInstantPageImageView`) are also lowered to iOS 13; the editor is now the **default** chat composer,
with the `forceLegacyTextInput` ("Force Legacy Text Input") experimental flag opting back out to the legacy input.

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
- `tapBelowAddsTrailingParagraph` (default `true`) — whether a tap in the empty area below the document's last
  block appends a new empty body paragraph there (the `point.y > boxes.last.frame.maxY` affordance in
  `+Interaction.swift`; see the quote-escape note below). The full-page article editor keeps it on; the compact
  composer has no "empty area below the content" to grow into, so **Composer → `false`** (a tap there just places
  the caret in the trailing paragraph). Unlike the other knobs the composer sets this in `didLoad` purely for
  behavior — it doesn't affect layout, so its timing vs. the document seed is immaterial.

Two host-side runtime contracts the composer had to honor (apply to any non-attachment host): **seed an initial
`document`** (the canvas starts with ZERO blocks; nothing renders/edits until the `document` setter runs), and
**re-run `update(...)` in response to `onChange`** (the view is parent-driven and does not self-layout on a
content change — without this, typed text is never laid out).

**Keyboard input language (added 2026-06-26).** `RichTextEditorView` exposes
`inputPrimaryLanguage` (read the live keyboard language back), `initialInputPrimaryLanguage`
(seed the language the keyboard opens in next focus), and `resetInputPrimaryLanguage()`,
forwarding to a one-time `textInputMode` override on `DocumentCanvasView` (the actual first
responder) — a verbatim port of the legacy `ChatInputTextView` mechanism so the chat composer
repopulates `interfaceState.inputLanguage` (emoji-keyword search + draft persistence).
LOAD-BEARING: the override is single-shot (first `textInputMode` query consumes the
pre-selection); UIKit queries it on `becomeFirstResponder` before any host read-back, so do not
add a separate non-side-effecting read path.

**Dynamic theme (added 2026-06-17, `Theme/RichTextEditorTheme.swift`).** `RichTextEditorView.theme:
RichTextEditorTheme` is a host-settable struct of eleven UIColors; assigning it updates the mapper, pushes the
accent to the caret/selection-handles/blockquote views, reloads — **only when the view is sized (`bounds.width >
0`)** — so boxes rebuild with the themed mapper, and redraws. **`.default` reproduces the editor's prior hardcoded colors exactly, so the look is unchanged until a
host sets a theme.** Host wiring: the **chat composer** wires it — `ChatTextInputPanelNode` maps
`PresentationTheme` → `ChatRichTextThemeColors` (a `UIColor`-only seam type in `ChatInputTextNode`) and pushes
it via `ChatRichTextInputNode.applyRichTextTheme`, which `RichTextEditorChatInputNode` maps to this `theme`.
`RichTextAttachmentScreen` now also wires a theme. What each color drives:
- `primaryText` (default `.black`) — default foreground for runs with no explicit color.
- `secondaryText` (default `.black`) — default foreground for `.caption`-style runs.
- `placeholder` (default `.placeholderText`) — empty-paragraph, marked-text ghost, and media placeholder text.
- `accent` (default `.link`) — link text, the blockquote bar + fill, the caret, the selection visuals
  (handles via a pushed `accentColor`; the body/cell selection *wash* reads `mapper.theme.accent` live),
  the table-control resize knobs, the selection-outline stroke, and the active-handle pill fill.
- `tableBorder` (default the prior dynamic grid color) / `tableHeaderBackground` (default `white 0.5/0.1`) — the
  table grid stroke and header-row fill (the former `TableBlockBox.gridColor`/`headerRowBackground` statics).
- `codeBackground` (default prior dynamic color) — code-block background fill.
- `listMarker` (default `.label`) — list bullet/number marker color.
- `inlineCodeBackground` (default `.systemGray5`) — inline-code run background pill.
- `markedTextUnderline` (default `.label`) — IME marked-text (composing) underline.
- `spoilerDust` (default `.secondaryLabel`) — spoiler particle ("dust") tint.

**Apply the theme BEFORE seeding the `document` (host-ordering invariant).** The `document` setter builds each
block's attributed string with the mapper's *current* theme (baking in the foreground color), and — per above —
the `theme` setter re-maps already-built boxes only when `bounds.width > 0`. So a host that assigns `theme`
*after* `document` while the view is still unsized (its frame set later in the same layout pass) leaves
pre-existing text in the `.default` foreground; an empty document is unaffected (later typed text uses the
by-then-themed mapper). Both hosts therefore theme before seeding — the composer in `didLoad`,
`RichTextAttachmentScreen` in its `if component == nil` init block (before `editor.document = …`). (Regressed
once: pre-existing text rendered black in dark mode, fixed 2026-06-26.)

**Round-trip invariant (load-bearing):** theme colors are applied at render time only and **never persist into the
`Document`**. `AttributedStringMapper` is symmetric — the forward pass injects the per-style default
(`secondaryText` for `.caption`, else `primaryText`) for un-colored runs; the reverse (`characterAttributes(from:
style:)` / `runs(from:style:)`) strips a foreground equal to that per-style default back to `nil`. Every
reverse-mapper caller MUST pass the run's paragraph style (`BlockBox` → its style, `MediaBlockBox` captions →
`.caption`, `+Editing` → the start box's style; `+State` reads only format flags, so its `.body` default is fine)
— a wrong style compares against the wrong default and pollutes the model. An explicit user color exactly equal to
the style default is also stripped (visually identical, re-themable). Known limitation: removing a link inside
a `.caption` run under a theme where `primaryText != secondaryText` leaves an explicit foreground (latent; see
`removeLink`).

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
- `height(forWidth:) -> CGFloat` — a stateless, side-effect-free content-height measure (the Phase-2
  follow-up to the composer's `textHeightForWidth`). Mirrors what `update(...)` returns at that width
  (same `minimumContentHeight` floor + `contentMargins`) but reflows NOTHING live: the per-block
  `measuredHeight(forWidth:)` chain reads structural insets and measures text via a reused per-engine
  scratch layout (`BlockLayoutEngine.boundingHeight(forWidth:)`). De-stateful-ized `TableBlockBox.height`
  in passing (it no longer resizes cell layouts to measure; `recompute()` owns cell layout).
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
  empty paragraph if it was the only block). No-op when not in a table. (This is the handle-menu "Delete Table"
  / caret-based path, which *joins* the surrounding content.)
- **Backspace with a table structural (row/column) selection** (`deleteTableStructuralSelection`, hooked at the
  top of `deleteBackward` since the parked caret would otherwise hit the in-cell delete) deletes the selected
  rows / columns — routing to the existing `deleteTableRow` / `deleteTableColumn` (which already read
  `structuralRowRange()` / `structuralColumnRange()`). When the selection covers EVERY row or EVERY column
  (`lowerBound <= 0 && upperBound >= rowCount/columnCount − 1`) — which would empty the table — it removes the
  whole table block instead, replacing it **in place** with an empty body paragraph (caret there). Distinct from
  `deleteTable()` above (which joins): full-selection backspace leaves an empty paragraph where the table was.
  The structural selection is cleared afterward (mirrors the handle menu's `structuralAction`).
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

**Composer bridge round-trip — custom emoji / mention / date (added 2026-06-19, `feature/richtext-composer-bridge-gaps`).**
`ComposerDocumentBridge` (`ChatRichTextEditorComposer`) and `EntityMessageBuilder` (`RichTextEditorMessageConversion`)
convert the composer's `Document` to/from the chat `NSAttributedString` currency. They now round-trip three inline
features that previously dropped: **custom emoji** (`ChatTextInputAttributes.customEmoji` ↔ `CharacterAttributes.emoji`
as a one-`U+FFFC` run; the original placeholder text is kept in `EmojiRef.altText` and re-emitted, since the Document
interior must stay a single `U+FFFC`), and **mention/date**, which are stored in the Document's existing
`CharacterAttributes.link` field as `tg://user?id=` / `tg://timestamp?t=` markers — **no new `CharacterAttributes`
field** (keeps Core markdown-clean). The encode/decode + the chat-attribute emit are centralized in the shared
`TextFormat` codec `MentionDateMarkers.swift` (`mentionMarkdownURL`/`parseMentionPeerId`, `dateMarkdownURL`/`parseDate`,
`classifyChatLink`, `chatInputLinkAttribute`) so the three sites (`document(from:)` / `attributedString(from:)` /
`buildEntityMessage`) + `composerContentEqual` can't drift; unit-tested in `//submodules/TextFormat:TextFormatTests`
(the repo's first `ios_unit_test`). The send path is automatic — the builder stamps the chat attributes and
`generateChatInputTextEntities` already emits `.CustomEmoji`/`.TextMention`/`.FormattedDate`. **Creation is unchanged**
(the Date menu item remains a no-op — this is preservation only; **code-block round-tripping + creation landed in the
follow-up note below**). **Known accepted limitation:** a `textUrl` whose string equals a
`tg://` marker (via markdown/paste/edit) is reinterpreted as a mention/date on round-trip — low-probability,
documented in `MentionDateMarkers.swift`. Spec/plan in `docs/superpowers/{specs,plans}/2026-06-18-richtext-composer-bridge-gaps*`.

**Load-bearing invariant — the iOS-16 edit menu needs `Display.Window1.hitTest` to forward to it.**
`UIEditMenuInteraction` hosts its menu in a top-level `_UIEditMenuContainerView` subview of the app window.
Telegram's `Window1.hitTest` (`submodules/Display/Source/WindowContent.swift`) only forwards touches to window
subviews whose class matches an allow-list; it was extended (2026-06-17) to match `"EditMenu"` (alongside the
pre-iOS-16 `"UITransitionView"` / `"ContextMenuContainerView"`). **Without that match, taps on the menu fall
through to the content below and every item is inert** — the symptom that surfaced first here because this is a
custom `UITextInput` presenting `UIEditMenuInteraction` directly. Any editor change that relies on the system
edit menu being interactive in the Telegram app depends on this allow-list entry.

**Deferred:** pending caret formatting (inline toggles at a *collapsed* caret are currently inert — they show
the inherited state but don't affect the next typed char). (Table structural row/column selection + its
delete-via-Backspace now landed — see `deleteTableStructuralSelection` above.) **Code blocks landed**
(2026-06-19, `feature/richtext-code-block`) as a first-class multi-line `Block.code` — see the dedicated note
below; they now losslessly round-trip and Format▸Code creates one. Dates now *round-trip* via the link scheme
(see the composer-bridge note above), but the Date menu item remains a creation no-op (no native
timestamp-creation UI yet).

**Composer code blocks — first-class `Block.code` (added 2026-06-19, `feature/richtext-code-block`).** A
multi-line code block is now a first-class `Block.code(CodeBlock)` (`Core/Model/CodeBlock.swift`: `id` +
`language: String?` + plain `runs` whose text may contain interior `"\n"`), rendered by a new
`CodeBlockBox: CanvasBlock` (`Canvas/CodeBlockBox.swift`) — a monospace `BlockLayoutEngine` drawn in a filled
rounded-rect (themeable `RichTextEditorTheme.codeBackground`) with an optional language label. **It reuses the
existing position model unchanged:** `Block.code` maps to a `.paragraph` `DocNode` carrying a `TextNodeRef.code`
leaf, sized `content + 2` exactly like a wrap-heavy paragraph — multi-line interior `"\n"`s need **no** new
position/selection/tokenizer machinery (they're a linear UTF-16 range TextKit wraps). `currentBlock()` reads
back the **plain** layout string (display-only monospace attrs never enter the model). Editing affordances
mirror quotes (`+UITextInput`/`+Editing`/`+Interaction`): **Enter** inserts an interior newline via
`insertCodeBlockNewline()` (replacing any selection), and **exits** to a new body paragraph on an empty
trailing line (`exitCodeBlockToBodyParagraph`); **Backspace** in a fully-empty code block un-codes it to body;
a **tap below** a trailing code block appends a body paragraph; **cross-block** edits treat a code endpoint
like media (truncate-and-keep partial coverage, drop full coverage) in `applyReplace`. **Creation:**
`makeCodeBlock()` (`+ParagraphFormat`, façade-forwarded) toggles the touched top-level paragraphs into one code
block (joining BOTH paragraph and existing-code text, refusing a selection that spans a non-text block) and
toggles back to body paragraphs split on `"\n"`; wired to the composer's Format▸Code via
`performFormatAction(.code)`. The chat round-trip is the **bridge** (`ComposerDocumentBridge` two-pass
`document(from:)` + emit) and **send** (`EntityMessageBuilder` → `.Pre`), centralized through `TextFormat`
`CodeBlockMarkers.swift` (`chatInputCodeBlockAttribute` / `codeBlockRanges`, unit-tested); the `composerParagraphs`
flat-mapping counts a code block's interior. Full SwiftPM suite green (Core 102 + UIKit 714); the app build +
`TextFormatTests` are green; **no logged-in-sim pass yet** (non-gating). The composer flat-coordinate mapping
and the position axis were the load-bearing reuse points — code blocks added zero new invariants there. Spec/plan:
`docs/superpowers/{specs/2026-06-19-richtext-code-block-design.md,plans/2026-06-19-richtext-code-block.md}`.

**Floating cursor — hold-spacebar-to-move-cursor (added 2026-06-23, runtime-verified 2026-06-24, `feature/richtext-floating-cursor`, phase 1 of 2).**
The iOS keyboard-as-trackpad gesture is implemented on the canvas (the bare sole `UITextInput`, which own-draws
everything and installs NO `UITextSelectionDisplayInteraction`) via the three optional `UITextInput` methods
`begin`/`update`/`endFloatingCursor` (`DocumentCanvasView+FloatingCursor.swift`). **Two runtime discoveries
corrected the original spec's assumptions** (the spec's relative-delta + hide-steady-caret design did NOT match
how iOS actually drives a bare `UITextInput` — both are wrong; see the spec's "Runtime corrections" addendum):

1. **The `point` is an ABSOLUTE canvas (content) coordinate**, not a relative delta — it already tracks the cursor
   across the whole document. So `update` feeds it straight to `closestGlobalPosition` (no delta, no viewport
   clamp). The clamp in the first cut froze the caret mid-text and couldn't reach the document start.
2. **`begin`/`update` fire fine on the bare `UITextInput` (no `UITextInteraction` needed), BUT during the gesture
   iOS ALSO pushes selection RANGES** (anchored at the gesture-start position) through the **`selectedTextRange`
   setter**; applying them turns the cursor MOVE into a text SELECTION (the headline bug). The setter therefore
   **ignores writes while `floatingCursorActive`** (`DocumentCanvasView+UITextInput`) — the floating handlers own
   the caret. **This is the load-bearing invariant of the feature.**

Visual model (matches iOS): a **bright gliding shadow** (`TransientCaretView`) follows the finger **continuously**
(`moveFloatingCaret(toGlobal:shadowX:)` positions it at the raw `point.x`, clamped to host bounds — only the
*underlying* caret snaps to a grapheme position), while the **steady `CaretView` becomes a dimmed (alpha 0.4)
"landing" indicator** at the snapped position via the `floatingCursorActive` branch in `updateCaretView` (NOT
hidden — the early design hid it, leaving no landing cue). On `end` the shadow fades and the steady caret returns
to full alpha + blink at the landing. Each `update` moves the caret through a **lightweight bracketed path**
(`moveFloatingCaret`) that brackets `inputDelegate.selectionWillChange/DidChange` but **deliberately suppresses
the host scroll-follow** (`onSelectionChange`/`scrollCaretIntoViewIfNeeded`) per-update — the gesture owns
scrolling via a `CADisplayLink` **vertical auto-scroll** driver (mirrors the table-drag auto-scroll, advances the
stored `floatingCursorPoint` by the scroll delta); `onSelectionChange` fires once on `end`. `TransientCaretView`
and the steady caret both host via the extracted `caretHostPlacement(forGlobal:)`/`hostOverlay(_:at:)`, so they
ride table-cell horizontal scroll. Document-wide landing (body/caption/code/table cells). An interrupted gesture
(resign-FR / window-removal) is torn down by `cancelFloatingCursor` (invalidates the self-retaining display link).
**`TransientCaretView` is built generically so phase 2 (text drag-and-drop drop caret via
`UITextCursorDropPositionAnimator`, iOS 17+, a separate cycle) can adopt it as the animator's `cursorView`.**
Status: **runtime-verified in the chat composer** (smooth glide, visible landing caret, reaches both ends, no
stray selection); full SwiftPM suite green (Core 102 + UIKit; incl. `TransientCaretViewTests` + the rewritten
`FloatingCursorTests`) and the full Bazel app build is green. (Per the module convention, the per-phase
design spec/plan are not retained in-tree; this note is the in-tree record.)

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
  **Table cells render body/quote at a smaller base — 15pt, not 17 (2026-06-26).** `StyleSheet` gained a
  `bodyBaseSize` (default 17) read by `baseSize(.body/.quote)` and a `static let tableCells` variant (15);
  `AttributedStringMapper.tableCellVariant()` copies a mapper onto it preserving theme/emojiScale. Each
  `TableBlockBox` derives a cell mapper once and builds every cell box with it. To keep edits consistent, a
  box created as a split/merge replacement **inherits its source box's mapper** (`CanvasBlock` now exposes
  `mapper { get }`; the three cell-capable creators — `applyReplace` merge, `insertParagraphBreak` split,
  `mergeParagraphs` — pass `start.box.mapper`/`p.mapper`/`upper.mapper` instead of the canvas mapper), and the
  empty-cell typing path (`typingAttributeDict`'s empty-storage branch) resolves the owning box via
  `activeStack` and uses **its** mapper — so an empty cell's first typed character is 15pt too. Headings keep
  their fixed sizes in cells. (An explicit run `fontSize` still wins; read-back pins the rendered 15pt.)
  **Paired cell-padding mechanism fix.** Cell vertical padding is now an explicit cell metric
  (`TableBlockBox.cellVerticalPadding = 14`) applied at the CELL level (`recompute` content origin +
  row-height math), parallel to the horizontal `cellPadding` (6) — and the cell `BlockStack` carries NO block
  inset (`verticalInsetBase = 0`). Previously the cell's 14pt vertical gap came *incorrectly* from
  `cellPadding` (6) + the document's 8pt inter-block inset (`BlockBox.defaultVerticalInset`) leaking into the
  cell stack; that coupling tied cell padding to document-body block spacing (font-independent), so the
  smaller 15pt text looked under-filled / vertically centered. The **visual is unchanged from before the font
  change** (14pt top/bottom), but it's now decoupled from `defaultVerticalInset` and lives in one cell metric.
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
- **Backspace targeting a media block replaces it with an empty body paragraph IN PLACE** (2026-06-27, supersedes
  the older per-case media-backspace rules). `replaceMediaWithEmptyParagraph(at:)` removes the media block and
  drops a fresh empty `.body` paragraph in its slot, caret there — NOT the old delete-and-merge-into-the-block-above
  (`deleteImageBox`) nor the old "act on the previous paragraph" gap behavior. It unifies every way a Backspace
  "lands on" a media block, reached on FOUR paths in `deleteBackward` / `applySelectionReplace`:
  - **collapsed caret at the media's leading gap** (`mediaBox(atGap: head)` branch);
  - **collapsed caret at the start of the caption** (`pos.box is MediaBlockBox, pos.local == 0`) — empty OR
    non-empty caption (the caption text is **discarded**);
  - **a selection whose bounds EXACTLY equal a media node's span** (`from == nodeStart && to == textStart +
    textLength`) in `applySelectionReplace` (deliberate select-the-image-then-delete);
  - **the iOS object-replacement RANGE of a tap-selected media — the LOAD-BEARING, compiler-invisible case**
    (device-log-verified). Tapping a media runs `selectImage` (collapsed caret at the gap, `imageSelection` set),
    but the `selectedTextRange` setter clears `imageSelection` and, right before Backspace, **iOS OVERRIDES the
    selection to a RANGE whose head sits at the media's gap yet ANCHORS IN THE PRECEDING BLOCK** — iOS's
    object-replacement geometry is offset from our position model, so the range does NOT cover the media node. A
    naive `selFrom != selTo` delete erases the *preceding* text and KEEPS the media ("cursor moves into the
    paragraph above"). So the setter stashes the just-cleared image into **`imageObjectDeletePending`** (a
    `BlockID?` on the canvas), and `deleteBackward` consumes it at the top — when the selection touches that
    media's gap — to replace the media. `insertText` and any non-matching `deleteBackward` clear the flag so it
    can't go stale. **Lesson (reinforced): a bare custom `UITextInput` receives OS-driven `selectedTextRange`
    writes that turn a tap into an *offset* object-replacement range — unit tests that set the caret/selection
    directly miss it; capture the real sequence from the device (`NSLog` + `xcrun simctl spawn <udid> log
    stream`), don't hypothesise twice.**

  A media delete never leaves a zero-block document (a lone-block replace yields the empty paragraph). The image
  edit-menu **"Delete"** still fully REMOVES the block (`deleteImageBox`, merges up) — only Backspace was
  respecified. (`deleteBlock(at:parkingCaretAtGapOf:)` was removed with its sole caller.)
- **Backspace at the start of a paragraph AFTER a non-text block deletes the empty paragraph, never the block**
  (`deleteBackward`, the mirror of the leading-gap rule above). A collapsed caret at the start (`local == 0`) of
  a paragraph whose previous block is a non-text **atom** — an image (`MediaBlockBox`), a table (`TableBlockBox`),
  or a code block (`CodeBlockBox`), unified via `isNonParagraphAtom(_:)` — must NOT delete that block (you can't
  merge text into it): an **empty** paragraph is removed (`removeBlock(at:parkingCaretAt:)`, so *"deleting the
  last paragraph" is always possible*), a **non-empty** one is kept; either way the caret steps back to the
  block's nearest text slot via `prevTextPosition` (an image's caption end, a table's last cell end, a code
  block's end) — never the block's degenerate node-start boundary. Previously the image branch called
  `deleteImageBox(at: pos.index - 1)` and silently destroyed the image; the table branch moved the caret but
  *kept* the empty paragraph (undeletable); the code branch left the empty paragraph in place. Text blocks
  (body/heading/quote/list paragraphs) still take the normal merge path below. (Select All + backspace still
  removes a covered image — that goes through `applyReplace`, below.)
- **An audio media block (`MediaKind.audio`) is a CAPTION-LESS atom** (2026-06-27) — unlike image/video/location it
  has **no caption** (not rendered, editable, or in the position model). `DocumentTree` emits `mediaBlock([mediaAtom])`
  (nodeSize 3, no caption paragraph), and `MediaBlockBox` is **dual-moded on `kind == .audio`** — `textLayout` →
  `emptyLayout`, `textLength 0`, `nodeSize 3`, `textStart == nodeStart`, `leafRegions() == []` (the FIRST block with
  zero leaf text regions — the caret/nav/selection machinery routes media via `mediaBox(atGap:)`/`isGapPosition`, not
  caption regions, so an empty `leafRegions` is tolerated), `height == verticalInset + audioRowHeight + verticalInset`,
  `closestPosition → nodeStart`, `currentBlock()` caption `[]` (an incoming caption is dropped), and no caption
  draw/placeholder. The non-audio (captioned) path is byte-unchanged. `insertMedia(kind: .audio)` lands the caret in a
  **following body paragraph** (created if the audio is last / followed by a non-paragraph atom) since there's no
  caption to land in. The Select-All / covered-range delete checks (`endpointFullyCovered`, the exact-node-span
  backspace) route through `coverableContentEnd(_:)` — audio → `nodeStart + 1` (the atom span), else
  `textStart + textLength` — because audio's `textStart + textLength` collapses to `nodeStart`. Backspace targeting
  audio still replaces it with an empty paragraph via the gap path (below); the caption-start branch never fires
  (no caption position exists).
- **Inserting a table or image on an EMPTY paragraph replaces it; mid-paragraph it splits** (`insertTable`,
  `insertMedia`). Both share one branch order: an **empty** caret paragraph (`pos.box as? BlockBox` with
  `textLength == 0`) is **replaced** by the new block (`replaceSubrange(pos.index...pos.index)`) so no stray
  empty paragraph is left beside it — even between content (`A | empty | B` → `A | block | B`); a caret strictly
  **interior** to a non-empty paragraph (`0 < local < textLength`) **splits** it into upper + block + lower;
  caret at the **start** of a non-empty paragraph inserts the block **before** it, at the **end** inserts
  **after**. The empty-replace check must run FIRST (an empty paragraph is both `local == 0` and
  `local == textLength`, so it would otherwise fall into the insert-before branch and survive). Replacing the
  document's only block is fine — a lone `[table]`/`[image]` is a valid document (the caret lands in the first
  cell / caption; tap-below re-adds a paragraph). The empty-replace only targets `BlockBox` paragraphs, so it
  never replaces an image caption / code block the caret happens to sit in.
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
  A non-empty quote's backspace still just deletes a char. **(B)** Tapping in the empty area **below the
  document's last block** (`point.y > boxes.last.frame.maxY`) inserts a new empty body paragraph after it
  (`insertEmptyBodyParagraph(at:)`) — so you can always start a normal paragraph below the final block, whatever
  its type (image / table / quote / code / non-empty paragraph). **The one exception:** when the last block is
  ALREADY an empty body paragraph, the tap is let through to the normal caret-placement path (no redundant empty
  is stacked). This started as a quote/code-only escape hatch and was generalized 2026-06-25 (paired with the
  *"deleting the last paragraph"* backspace rule above, so a tapped-in trailing paragraph is also removable).
  **Gated on `tapBelowAddsTrailingParagraph` (added 2026-06-28, default `true`):** the article editor keeps it;
  the chat composer sets it `false` (a compact field has no empty area below the content to grow into) — see the
  compact-host knob list above.
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

## RTL / writing direction (added 2026-06-28)

RTL paragraphs (Arabic/Hebrew/…) lay out per-paragraph, **auto-detected by default**, with a persisted
**whole-document override**. Auto-detected direction is **render-only**; only the override persists.

- **Model.** `TextAlignment` gained `.natural` (leading) and it is the **default** for new paragraphs (absolute
  `.left/.center/.right/.justified` stay explicit overrides). `Document.layoutDirection`
  (`.auto/.leftToRight/.rightToLeft`, default `.auto`) is the override (Core; `DocumentCodec` defaulted decode →
  `.auto`). Both pure-Foundation; the Core→UIKit `NSWritingDirection` mapping is UIKit-side.
- **Detection.** `BlockLayoutEngine.baseDirection(atOffset:)` — one protocol-extension default impl over the
  engine's `attributedString` using `CTRunGetStatus(firstRun).contains(.rightToLeft)` (the same first-run
  heuristic as `TextNode`/`InstantPageV2Layout`, so the editor agrees with how the sent message renders). Both
  engines inherit it; nil on empty.
- **Resolution + reporting** (`DocumentCanvasView+WritingDirection.swift`): `resolvedDirection(forGlobal:)` =
  forced override → content detection → `typingWritingDirection`; `typingWritingDirection` = forced → keyboard
  language (`Locale.characterDirection`) → app `effectiveUserInterfaceLayoutDirection`. `applyWritingDirectionOverride`
  sets `layoutDirectionModel` + `mapper.baseWritingDirection` (`.auto`→`.natural`). `baseWritingDirection(for:in:)`
  returns the resolved direction; **`setBaseWritingDirection` is a deliberate no-op** — the whole-document override
  is the single manual control (per-range UIKit writes are ignored).
- **Layout.** `StyleSheet.paragraphStyle(…baseWritingDirection:)` sets `ps.baseWritingDirection` (threaded via
  `AttributedStringMapper.baseWritingDirection`; 11 call sites). `selectionFillRects(…isRTL:)` flips the
  leading/trailing physical edge for RTL lines (both engines; `isRTL:false` is byte-identical to the old LTR math).
- **Empty-paragraph caret** follows `typingWritingDirection`: `refreshEmptyBoxWritingDirections()` sets
  `BlockBox.writingDirectionOverride` on empty top-level boxes (all modes), whose `didSet` pushes
  `BlockLayoutEngine.emptyTextCaretDirection`; both engines' `caretRect(atOffset:)` return `x ≈ containerWidth-2`
  for empty + `.rightToLeft` (LTR/non-empty unchanged). Refreshed from `reload`, `becomeFirstResponder`, and
  **`UITextInputMode.currentInputModeDidChangeNotification`** (so the caret re-flips live on a keyboard/globe-key
  change or first keyboard appearance).
- **Façade + host.** `RichTextEditorView.layoutDirectionOverride` (modeled like `theme`; round-trips through
  `document`). `RichTextAttachmentScreen` has an Auto/LTR/RTL action-bar control; the chat composer relies on
  auto-detect (no manual toggle this round).
- **LOAD-BEARING — font FAMILY is display-only and must NOT round-trip.** `NSTextStorage` font-fixing substitutes a
  script font into a run's `.font` **in storage** when the style font can't render the glyphs (Arabic/Hebrew/CJK).
  `characterAttributes(from:)` must therefore **not** capture `fontFamily` from the rendered font — it once did, so
  the substituted family round-tripped and the font visibly changed on a backspace **merge** (`mergeParagraphs` →
  `currentParagraph()`). Font **size** IS still pinned on read-back (the 15pt table-cell round-trip needs it);
  bold/italic round-trip via font traits; forward `font(for:)` still honors an explicit import-set `fontFamily`.
- **Deferred:** gutter-ornament mirroring (list markers / quote bar / checklist / indents to the right gutter),
  table-column direction, a composer override UI, and mapping the override → rich-message `InstantPage.rtl`.

## DEBUG layout overlay (added 2026-06-28, `RichTextEditorView+DebugOverlay.swift`)

`RichTextEditorView.debugShowLayoutOverlay` (`#if DEBUG`, **ON by default in DEBUG**; set `false` to hide) draws a
non-interactive topmost overlay: the field frame (red outline), scroll insets (blue bands), content margins (green
ring), and per-block frames (orange, indexed), with inset/margin numeric labels. Refreshed from `performLayout` /
`scrollViewDidScroll`; reads geometry via `bounds` / `debugContentInset` / `canvas`. Compiled out of release entirely.

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
  double-tap-failure delay); the host scroll view sets `delaysContentTouches = false`. **Both scroll views
  yield near a grip** via `GripYieldingScrollView` (a `UIScrollView` subclass overriding
  `gestureRecognizerShouldBegin` to return `false` when `canvas.isSelectionDragTouch(point)` — its testable
  seam is `yieldsToGrip(at:)`): used for the per-table inner scroll AND the **outer** document scroll
  (`RichTextEditorView.scrollView`, `canvas` wired in init). Before the outer scroll adopted it, a vertical
  knob pull raced the document scroll and the knob "felt dead" (2026-06-29).
- **The single-tap "inside the selection/caret" test (`tapOutcome`) is VISUAL, not offset-based.** A tap
  toggles the edit menu only when its *point* lands on the rendered selection (`selectionRects().contains`)
  — NOT merely when `closestGlobalPosition` resolves to an offset within `[selFrom, selTo]`. A tap in the
  empty area beside a selection resolves to a *boundary* offset inside the range but is visually outside, so
  it must collapse the selection + place the caret (the composer "tap-to-deselect doesn't work" bug). The
  collapsed-caret branch keeps the offset test (`resolved == head`).
- **A FOCUSING tap only places the caret — it never opens the menu** (`menuToggleAction`'s `wasFirstResponder`
  gate). The focus transition is captured by `didJustBecomeFirstResponder` (set in `becomeFirstResponder`,
  consumed by the next `performSingleTap`), **not** by reading `isFirstResponder` at touch-up: the chat
  composer focuses the editor on touch-**down** (`ChatTextInputPanelNode`'s `ensureFocusedOnTap`), so by the
  time the tap handler runs `isFirstResponder` is already true and can't distinguish the focusing tap.
  Otherwise the empty composer (caret at 0, a focusing tap resolves to 0 == `head` → `.toggleMenu`) pops the
  menu on the first tap. A second tap on the caret of the now-focused field toggles it normally.
- **Gesture-driven RANGE selections fire `onSelectionChange`** (`applySelection`, shared by `selectWord` /
  `selectParagraph` / `selectAllText`), exactly like `setCaret`. The chat composer tracks the editor selection
  through this hook; without it a double-tap word-selection never reaches the panel's interface state and the
  next `setInputContent` re-apply collapses it back to the stale caret (the double-tap "flash then deselect"
  bug). Pairs with the repo-wide invariant *"any caret-moving op must fire `onSelectionChange`."*
- **Word/paragraph boundaries come from the custom `DocumentTokenizer`**, which scans each leaf region's OWN
  string — not the global axis (whose structural slots the stock tokenizer mis-reads, gluing regions with
  no separator).
- **Marked text / IME is storage-backed** (body paragraphs only today): composing text is applied
  **outside** `editing{}` with one undo per composition; a system inline prediction (signalled by
  `setMarkedText` `sel:{0,0}`, ghost trailing) is **dismissed, never committed**, by our finalize
  chokepoints so the keyboard's own accept lands clean.
- **`text(in:)` MUST emit a `"\n"` at every top-level paragraph boundary** (`DocumentCanvasView+UITextInput`),
  exactly like a `UITextView` over a `"\n"`-joined string — because the global axis carries NO newline char
  between blocks, only a structural token gap. The system keyboard reads document context through `text(in:)`,
  and **not every IME drives `setMarkedText` on this view** — the Hangul (and other CJK) keyboard composes via
  `insertText` + a ranged `selectedTextRange`-set + `deleteBackward` + `insertText`, tracking positions itself
  and reading `text(in:)` for context. Without the separator it sees two stacked paragraphs as ONE continuous
  line and recomposes a syllable **across the invisible line break** — the trailing consonant of the lower line
  migrates onto the line above (the reported Korean-deletion bug). The `"\n"` is emitted for each crossed
  boundary, **including a range that lands entirely inside the inter-block gap** (the read the keyboard makes
  immediately before a lower line's first character). **Table-cell boundaries stay glued** (a table is one
  editing surface; cells don't compose marked text, and `CanvasCrossCellEditTests`/`test_copy_acrossCells…`
  rely on the un-separated cross-cell read). Covered by `CanvasTextInputTests.test_textInRange_*`.
- **PRIVATE API risk:** `SpoilerDustView` uses `CAEmitterBehavior` (`createEmitterBehavior`) for the
  twinkle + finger-attractor explosion — App-Store-review risk, guarded by a live canary test.
- **View-frame ownership** (the repo-wide rule applies here too): a reusable component lays out against
  `self.bounds`; it never writes `self.frame` — the parent positions it.

## Known render-only trade-offs

These keep the model markdown-clean at the cost of not separately preserving a user override: **(1)** a
link run's `foreground`/`underline` styling is render-only (suppressed on read-back); **(2)** table
**header-row** bold is render-only, so user-bold inside a header cell isn't separately preserved.

Headings are **regular weight by default** (`StyleSheet.font` does not force bold for them — they read as
larger serif); bold is a pure user-emphasis toggle that round-trips uniformly across every style. (This
replaced the earlier behavior where headings baked bold into their font, which leaked `**bold**` into the
model and left residual bold on a heading→body down-convert.) Type scale (2026-06-13): H1 24 / H2 21 / H3 19
serif, Body 17 sans, Caption 15 sans, Quote 17 sans — see the 2026-06-13 session block above. **Inside table
cells body/quote drop to a 15pt base (2026-06-26)** via a per-cell `StyleSheet.tableCells` mapper variant — see
the type-scale bullet in that session block.

**Interactive checklist / task list (added 2026-06-26).** A first-class checklist marker
(`ListMarker.checklist` + `ListMembership.checked: Bool?`, Core). **Creation:** the list picker offers
"Checklist"; `setList(.checklist)` seeds `checked: false` (re-applying `.checklist` to an already-checked item
PRESERVES its state). **Interactive checkbox — `CheckNode` via a host hook (the editor package stays
`CheckNode`/AsyncDisplayKit-free):** `RichTextEditorView.registerChecklistMarkerViewProvider(_ : (checked, size)
-> (UIView & RichTextChecklistMarkerView)?)` supplies a `CheckNode`-backed checkbox; both hosts wire it — the chat
composer threads checkbox colors through the `ChatRichTextThemeColors` seam (sourced from
`theme.list.itemCheckColors` in `ChatTextInputPanelNode.makeRichTextThemeColors`), `RichTextAttachmentScreen`
reads `appliedTheme.list.itemCheckColors`. The editor hosts/pools/culls the view in the marker gutter (mirrors the
inline-emoji machinery, `DocumentCanvasView+ChecklistMarkers.swift`), SUPPRESSES the Unicode glyph for `.checklist`
(`BlockBox.hostsChecklistCheckbox`, stamped in `stampListMarkers` + folded into `renderSignature` so a late
provider repaints), and a tap on the marker hit-rect toggles `checked` as ONE undo step (`toggleChecklistItem`,
caret-neutral, animates the hosted view). **Marker geometry** (`BlockBox.checklistMarkerCanvasRect()`): side =
`StyleSheet.checklistMarkerSize(for:)` (`font.capHeight.rounded()`) × `checklistMarkerScale` (1.4), bottom on the
text baseline (grows top/bottom/right, left edge anchored at the gutter), `floorToScreenPixels`-snapped; the list
text inset reserves the scaled width + a gap. **Return** continues the list with a fresh `checked:false` item
(empty-item Return exits the list; indent/outdent preserve `checked`). **Message round-trip (composer):** sends as
a rich message — `ChatInputContent` gained `.checklist` + `checked: Bool?` (the draft currency → draft persistence
free; raw enum value appended, optional Codable back-compat), threaded through `DocumentChatInputContentBridge`
(both directions) and BOTH `Document→InstantPage` builders (`ChatInputContentInstantPage` for the composer +
`RichTextEditorMessageConversion/InstantPageBuilder` for the attachment-screen send) into `InstantPageListItem.checked`.
Recipient checkboxes are display-only/static; the SENDER can re-edit (falls out of the reverse bridge). No
strikethrough on checked text (matches the InstantPage rendering). Default-on (legacy via `forceLegacyTextInput`); runtime-verified.

## Configurable quote geometry + collapsed quotes (added 2026-06-28)

Two related quote features. **(1) Per-host quote geometry** — a `QuoteStyle` value (leading/trailing inset,
spacing before/after, bar width, corner radius, fill alpha) set via `RichTextEditorView.quoteStyle` and applied
through `DocumentCanvasView.applyQuoteStyle` (rebuilds the mapper stylesheet); the full-page article editor and the
compact chat composer pass different values. **(2) Collapsed quotes** — a first-class
`Block.collapsedQuote(CollapsedQuote)` atom (legacy chat-input parity) reusing the AUDIO-media DocNode shape
(`mediaBlock`+`mediaAtom`, nodeSize 3, caption-less; the leading gap is the caret slot). `CollapsedQuoteBox` draws
the folded preview + a corner expand glyph; `collapseQuoteRun(atIndex:)` folds a run of consecutive quotes into one
atom, `expandCollapsedQuote(atIndex:)` restores them — caret relocation on collapse/expand is conditional (only a
caret that was INSIDE the run moves). Composer round-trip: one flat char + `ChatTextInputTextQuoteAttribute(
isCollapsed: true)` via `ComposerDocumentBridge`, sent through the InstantPage builder. Available in both hosts
(the composer is the default rich-text input; `forceLegacyTextInput` opts out). Runtime-verified.

**Collapsed-quote atom — caret/nav/delete invariants (compiler-invisible, device-log-verified).** The collapsed
quote behaves like a caption-less media atom: it owns NO leaf region (`leafRegions() == []`), so it routes through
the same gap machinery as audio media via `collapsedQuoteBox(atGap:)` (mirroring `mediaBox(atGap:)`).
- **Caret** at the gap draws at the quote's leading edge (`caretRect` / `caretHostPlacement`); a range covers it
  (`coverableContentEnd == nodeStart + 1`). **Tap** the body to place the caret at the gap; tap the corner glyph to
  expand.
- **Horizontal nav** stops on the gap (`nextTextPosition` / `prevTextPosition` via `atomGap`); `snapToRenderable`
  treats the gap as renderable.
- **Vertical nav MUST step THROUGH the gap** — `verticalPosition` has an explicit `collapsedQuoteBox(atGap:)` branch
  (Down → block after, Up → end of block above), mirroring the media-gap branch. Without it a multi-line move (the
  OS's `position(from:in:.up/.down, offset: 2)`) STALLS on the gap (offset:2 == offset:1); the OS reads "no
  progress", abandons `position(from:in:)`, and falls back to its own line geometry that SKIPS the captionless atom
  (the intermittent "arrow jumps over the quote" bug).
- **Backspace** at the gap acts on the PREVIOUS block, never the quote: a non-empty previous paragraph loses its
  last grapheme, an EMPTY one is removed (caret stays on the quote's gap), a LEADING collapsed quote (nothing
  before) expands. LOAD-BEARING: iOS delivers this Backspace as an object-replacement RANGE anchored at the
  previous block's end (`selFrom = prevTextPosition(before: gap)`, `selTo = gap`) — exactly like a media atom — so
  the handler fires on `selTo` being a collapsed gap AND `selFrom >= prevTextPosition(before: selTo)` (admits the
  range AND the collapsed caret; excludes a genuine selection that merely ends at the gap), NOT on `selFrom ==
  selTo`. (Same "capture the device log, don't hypothesise twice" lesson as the media object-replacement-range case.)

## Selection-handle drag — touch offset, outer-scroll yield, host knob config (added 2026-06-29)

Three fixes to the selection-handle ("knob") drag, runtime-verified in the chat composer.

- **The drag keeps its starting touch→knob offset (not line-centered).** The knob is drawn OFFSET from the text
  line (`SelectionHandleView.boundingFrame`: a knob 2·`knobRadius` past the caret's open end), so mapping the raw
  finger point snapped the dragged endpoint to whatever line sat under the finger. `handleSelectionHandlePan`
  `.began` now captures `selectionDragGrabOffset = caretCenter(draggedEndpoint) − touch`
  (`captureSelectionDragOffset`), and every drag map — the `.changed` branch AND the auto-scroll re-extend tick —
  goes through `selectionDragPosition(forTouch:)` = `closestGlobalPosition(to: touch + offset)`. Anchoring on the
  caret CENTER makes the first map (touch ≈ grab point) land exactly on the grabbed endpoint (no jump at grab) and
  the constant offset is preserved for the rest of the drag — the iOS handle-tracking feel.

- **`GripYieldingScrollView` (generalized from the old `TableScrollView`).** See the gesture-arbitration invariant
  above: the OUTER document scroll now yields its pan near a grip (it never did before — the root cause of the
  "knobs feel dead, only the line drags" report; the gate was already covering the knobs, but the un-gated outer
  scroll won the vertical pull). Same class backs the per-table inner scroll.

- **Handle views are hit-testable + host-configurable, so a knob drag isn't hijacked by interactive
  dismiss/transition gestures.** `SelectionHandleView` is now `isUserInteractionEnabled = true` with a
  `point(inside:)` hit area = `caretLocalRect.insetBy(-dragHitTolerance)` (the SAME ±22pt zone as
  `isSelectionDragTouch`, fed via `setCaretLocalRect` in `positionHandle`) — **it adds NO recognizers; the drag is
  still the canvas pan, which receives the touch as an ancestor.** Being the window hit-test result for a knob
  touch lets a host set Display's gesture flags on it (Display walks UP from the hit-test view), scoping the effect
  to knob interaction — NOT the whole editor surface (setting them there was rejected). The package can't import
  Display, so the new façade hook `RichTextEditorView.configureSelectionHandleView: ((UIView) -> Void)?` (invoked
  once per handle view, applied in the canvas `didSet`) lets the host apply them. The three flags:
  `disablesInteractiveTransitionGestureRecognizer` (the navigation back-swipe a HORIZONTAL knob drag triggers — the
  load-bearing one, gated at `WindowContent.doesViewTreeDisableInteractiveTransitionGestureRecognizer`, distinct
  from the keyboard check), `disablesInteractiveModalDismiss` (the attachment sheet), and
  `disablesInteractiveKeyboardGestureRecognizer`. **Scope differs by host:** the **compact composer**
  (`RichTextEditorChatInputNode`) uses ONLY the per-knob hook (editor-wide was rejected — it would kill normal
  scroll/dismiss in the small field); the **full-page attachment editor** (`RichTextAttachmentScreen`) sets the
  hook AND the same three flags editor-wide on `editor` (a full-page editor shouldn't back-swipe/dismiss from any
  in-editor interaction while editing). **Compiler-invisible:** the per-knob flag is consulted only when the knob
  is the window hit-test result, so the handle MUST stay hit-testable and its hit area MUST track the caret —
  verified on device (the hit test lands on `SelectionHandleView`).

## Status

**Done** (model + editing + rendering all in place): the Core model, global position model, and JSON/`.rtdoc`
serialization; continuous **cross-block and partial-cross-cell selection + editing** — the headline
requirement, incl. editing across stacks via `applyReplace` / `applyMultiRegionClear`; structural editing
(Enter splits / Backspace merges / cross-block delete) with snapshot undo; **lists** (rendering +
`setList` / indent / outdent, incl. an **interactive checklist** — tappable `CheckNode` checkbox + message
round-trip + emoji external share, see the note above), **images** (caption + gap cursor + selection highlight), **tables**
(rendering, cross-cell caret & Tab nav, in-cell editing, row/column insert-delete + per-column alignment +
header row, in-canvas row/column controls + multi-row/column range selection); **formatting**
(bold/italic/strike/inline-code/underline, paragraph styles H1–H3/Body/Quote, alignment, links);
**insert** table/image; the **iOS-standard touch model** (tap-caret, double/triple select, long-press
loupe, handle-drag) + **system edit menu** (Look Up / Translate / Share / Format / basic Writing Tools);
**visual design alignment**; **inline predictive text + marked-text/IME**; **inline custom emoji**; the
**block-view architecture** (every block in its own bounded layer; per-table horizontal scroll; off-screen
**view virtualization**); and the **Telegram-style spoiler effect**.

**The editor is full-WYSIWYG — markdown abandoned.** There is no markdown serializer, and none is planned. Cross-app interchange uses **RTF** (see Phase 5d below).

**Phase 5d rich copy/paste — done.** Within-app fidelity via the private pasteboard UTI `org.telegram.richtexteditor.fragment` carrying a JSON-encoded `Document` fragment (inline formatting incl. custom emoji / mention / date, and paragraph/quote/code/list block structure — preserved across any editor instance, including between chat composers). Cross-app via **RTF** read+write (`public.rtf`) plus a plain-text fallback (`public.utf8-plain-text`) always written/accepted. Multi-line plain paste splits into paragraphs (replaced the old newline→space flattening). Fragment scope = paragraph family + inline; tables and media (images) are NOT carried in a fragment (deferred); image-paste-to-attachment in the composer is a host concern, wired via the paste-media hooks (see below). The extract/splice are pure Core (`Document.extractFragment` / `Document.insertingFragment` in `RichTextEditorCore/Model/DocumentFragment.swift`); the `copy`/`cut`/`paste` responders + the three-representation pasteboard write are in `DocumentCanvasView+Clipboard.swift`; RTF conversion is `RTFConversion.swift`.

**Checklist external share — emoji (added 2026-06-26).** Checklist items serialize to the EXTERNAL RTF +
plain-text reps as an emoji checkbox prefix (`⬜ ` U+2B1C unchecked / `✅ ` U+2705 checked) and are auto-detected
(emoji-only, optional VS16, strips exactly one) on import/paste, via the pure-Core `ChecklistEmojiMarker` codec
(`prefix(checked:)` / `strippingMarker(_:)`) + `externalChecklistPlainText([Block])`. Injected at the export sites
(`RTFConversion.rtfData` prefix + the `NSAttributedString`-fallback per-line detect; the plain rep via
`pasteboardItem` → `externalChecklistPlainText`) and the import sites (`RTFImport.flushParagraph` text + `\listtext`
detect; `plainTextFragment` per-line detect). The in-app private fragment round-trips `checked` losslessly
(`blockPlainText` / `text(in:)` stay marker-free). Accepted limitation: a paragraph the user literally typed
starting with `✅ `/`⬜ ` is read as a checklist on external paste.

**Paste never leaves a spurious empty paragraph (load-bearing, `Document.insertingFragment`).** The multi-block
splice assembles `[headBlock] + middle + [tailPara]`, where head/tail are the host paragraph split at the caret;
it inline-merges a fragment block into a split half ONLY when that block is body/heading (`isInlineMergeable`).
Pasting a NON-inline-mergeable LAST block — a **list item (checklists), quote, or code block** — at a paragraph
END (empty tail) would otherwise leave the empty host tail as a trailing empty paragraph (symmetric leading case at
a paragraph start). It now drops an empty OUTERMOST split-half (`headBlock`/`tailPara` only — keyed on
`text.isEmpty`, keeps ≥1 block; INTERIOR fragment empties live in `middle` and are preserved), with the caret →
end of the last pasted block when the tail is dropped. This is the true fix for the "paste adds a trailing empty
paragraph" bug (a trailing empty *in the fragment* — handled earlier at higher layers — was a different, narrower
case; the host-tail empty is the general one and lives here in Core, shared by both editors).

**Paste-media-to-send is host-delegated (2026-06-25).** The editor never embeds pasted media inline — images/GIF/video/stickers go to the chat *send* flow. Two façade hooks (`RichTextEditorView.canPasteMedia` / `onPasteMedia`, both `(() -> Bool)?`, forwarded to `DocumentCanvasView`): `paste(_:)` pastes a TEXT rep if one exists (fragment/RTF/plain — **text wins**), else calls `onPasteMedia?()`; `clipboardCanPerformAction(.paste)` also offers Paste when `canPasteMedia?()` is true (so the menu shows for an image-only clipboard). The editor stays Telegram-UTI-agnostic — the hooks are plain closures the host fills. The chat composer wires them (`ChatTextInputPanelNode.loadTextInputNode`) to a shared `handlePastedMedia(perform:)` (the gif/mp4/heics/png-sticker/jpeg detection extracted from the legacy `chatInputTextNodeShouldPaste`, so both the old and new composers route media identically), restoring the legacy paste-to-send the new composer had lost.

**RTF export is hand-rolled and emits real tables (2026-06-25, `RTFConversion.swift`).** iOS has **no `NSTextTable` / `NSParagraphStyle.textBlocks`** (AppKit-only) — confirmed by spike — so `NSAttributedString` cannot represent or round-trip a real RTF table; a genuine table can only be produced by emitting the control words by hand. So `rtfData(from:)` now builds the **entire** RTF document by hand for ALL documents (one path; the old `NSAttributedString` export is gone) via one shared inline-run encoder (`inlineRTF`) + `escapeRTFText` (UTF-16 `\u<signed-16>?` escaping). Tables emit `\trowd`/`\trhdr`/`\cellx<cumulative-twips>`/`\intbl`/`\cell`/`\row` (`tableRTF`), so a Telegram table copied into Word/Pages/Notes becomes a **real table**. Parity kept on export (not added): no list markers, no foreground/theme colors, media-in-cell dropped, cell background colors dropped. Custom emoji ride the `tg://emoji?id=<id>&n=<seq>` hyperlink marker (the `&n=` per-export sequence stops adjacent identical emoji from coalescing). Spec/plan: `docs/superpowers/{specs/2026-06-25-richtext-rtf-tables-design.md,plans/2026-06-25-richtext-rtf-tables.md}`.

**RTF import is a custom pure-Foundation parser in Core (2026-06-25, `RichTextEditorCore/Serialization/RTFTokenizer.swift` + `RTFImport.swift`).** Because iOS `NSAttributedString` flattens all block structure (no `NSTextTable`/`textLists`), a custom lexer (`RTFTokenizer`: groups, control words, `\'XX` cp1252, `\uN` signed-16 + surrogate + `\uc` skip, escapes) feeds a group-state document builder (`RTFDocumentParser`) that **reconstructs tables / headings / code / lists** + inline runs/links/emoji from third-party RTF (Word/Pages/web). `fragment(fromRTF:)` (UIKit) tries `RTFImport.document(fromRTF:)` **first** and falls back to the old `NSAttributedString` path only on hard failure (not-RTF / zero blocks) — so exotic RTF is never worse than the flatten, and the editor's own export→import now **round-trips structure losslessly** (the `RTFConversionTests` round-trip suite is the parse-compat gate; pure-Foundation parser is `swift test`-able on macOS via `RTFImportTests`/`RTFImportCorpusTests`). Heuristics (text always survives, only block style may differ): heading by font size (`\fsN/2` ≥23→H1/20–22→H2/18–19→H3), all-mono paragraph→code block, best-effort lists (`\ilvl`/`\listtext` marker→`.bullet`/`.ordered`+level). Non-goals: colors, nested tables, full Word list-table fidelity, images, codepage beyond cp1252. Graceful degradation: unknown control words → no-op; unknown/`{\*\…}` destinations consumed to their `}`; never crashes. **Paragraph breaks (load-bearing, fixed 2026-06-26 — the "pasting removes newlines" bug):** Cocoa/AppKit (TextEdit, Notes, Safari, Mail, Pages — i.e. *every* rich-app copy) serializes a paragraph break as a **backslash immediately followed by a literal CR/LF** (`a\⏎b`), which the RTF spec defines as equivalent to `\par` — NOT a literal `\par` (only the editor's own export and hand-written test RTF use literal `\par`, which is why this slipped the original suite). `RTFTokenizer` therefore maps `\`+CR/LF (CRLF collapsed to one) to a `\par` token; without it every cross-app paste glued all paragraphs into one. **Empty paragraphs survive:** an explicit `\par` is a paragraph *terminator*, so `flushParagraph(allowEmpty:)` emits an empty body paragraph for two consecutive `\par` (a blank line); the implicit end-of-document flush passes `allowEmpty:false`, so a doc with no trailing `\par` gains no spurious empty final paragraph. (Raw, un-backslashed CR/LF stays ignored per spec; `\line` is still a soft in-paragraph break.) Regression-guarded by `RTFImportTests.test_backslash*`/`test_*Par*` + `RTFImportCorpusTests.test_cocoaStyle_*`. Spec/plan: `docs/superpowers/{specs/2026-06-25-richtext-rtf-import-design.md,plans/2026-06-25-richtext-rtf-import.md}`.

**Other open work:** Phase 5e images toolbar (Photos/Files picker, alignment toggle, interactive drag-resize); Phase 6b new
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
