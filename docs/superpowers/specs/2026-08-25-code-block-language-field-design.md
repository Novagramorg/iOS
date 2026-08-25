# Code-block language field — design

**Date:** 2026-08-25
**Scope:** `submodules/TelegramUI/Components/RichTextEditor` (Core + UIKit), plus the two editor hosts'
placeholder strings.
**Goal:** make a code block's language authorable — an always-visible, editable text line at the top of
the code band, modelled on the quote author line.

## 1. What exists today (verified in-tree)

- `CodeBlock.language: String?` **already exists** (`RichTextEditorCore/Model/CodeBlock.swift`) and already
  round-trips end to end: `ChatInputCode.language` → `.Pre(language:)` entity and
  `InstantPageBlock.preformatted(text:language:)` → the V2 renderer's language line
  (`instantPageV2CodeLanguageDisplayText`, which lowercases). **No serialization work is needed.**
- `CodeBlockBox` already **draws** a language line at the top of the band (`languageLine`, body font +
  bold, lowercased, `codeLanguageSpacing` gap, `containerPlaceholder` colour) — but it is display-only,
  the stored `language` is never mutated after `init`, and the line is absent when the language is nil or
  empty. There is no authoring path anywhere in the app.
- The quote **author** line is the pattern to mirror: a second `BlockLayoutEngine` on the box, exposed as a
  second `LeafTextRegion` with its own `TextNodeRef` case, its own `DocumentTree` paragraph node,
  placeholder, tap routing, typing attributes, Return/Backspace branches, character-format lock-out, and
  ambient-style stripping on read-back. `DetailsBlock.title` is the precedent for a region that is
  **leading and never content-gated**.
- The legacy chat input (`ChatInputTextNode`) renders a code block's background with **no language UI at
  all**, and code blocks are entity-expressible, so they do not trip the composer's native latch.

## 2. Decisions

| Question | Decision |
|---|---|
| Control kind | An **editable text line**, author-style — not a picker. Free text; no curated language list. |
| Visibility | **Always visible**, including on a brand-new empty code block (unlike the author line, which hides while its quote is empty). Placeholder "Language" when empty. |
| Position | **Leading** — above the code text, inside the band, where the renderer already draws it. |
| Text handling | Stored **as typed**, trimmed; empty → `nil`. The editor shows what you typed; the renderer keeps lowercasing at display. Plain text only. No autocorrect, no autocapitalization, no spell check in the region. |
| Composer scope | **Native editor only.** The chat composer gets the feature by hosting the same `RichTextEditorView`. No legacy-field implementation, no change to the native-latch policy. |
| Implementation | **Leaf region on `CodeBlockBox`** (approach A), not a container-of-child-boxes refactor and not an off-axis overlay control. |

### Non-goals

- No language picker, autocomplete, or curated language list.
- No change to the legacy chat input field, and no change to which content latches the composer to native.
- No change to the renderer, to `.Pre` serialization, or to how a sent message displays a language.
- No syntax highlighting.
- The author line's hard-coded `"Add author"` placeholder stays hard-coded; only the new placeholder is
  localized (fixing the author's is out of scope).

## 3. Core: model and position shape

`CodeBlock` gains one derived member beside the existing `language`:

```swift
public var languageUTF16Count: Int { (language?.utf16.count) ?? 0 }   // mirrors PullQuote.authorUTF16Count
```

`TextNodeRef` gains `case codeLanguage(BlockID)`.

`DocumentTree.node(for:)` maps `.code` from a bare paragraph node to a **container with two paragraph
children** — the mirror image of `.pullQuote`'s `[text, author]`, with the extra region leading, and
**never content-gated** (always emitted, like `.details`' title):

```swift
case .code(let cb):
    return .blockQuote(id: cb.id, children: [
        .paragraph(id: cb.id, children: [.text(length: cb.languageUTF16Count, ref: .codeLanguage(cb.id))]),
        .paragraph(id: cb.id, children: [.text(length: cb.utf16Count,         ref: .code(cb.id))]),
    ])
```

`.blockQuote` here is only a **token-shape container**: `PositionMapping` / `PositionResolver` are generic
over `children`/`nodeSize`/`isLeaf` and special-case only `.text`, and the canvas-side
`isInsideBlockQuote(_:)` tests `box is BlockQuoteBox` (a *box class*, not a DocNode case), so reusing the
case does **not** make code-block positions "inside a block quote".

Resulting arithmetic (canvas convention: `nodeStart` is the container's first inner position):

| Quantity | Before | After |
|---|---|---|
| `nodeSize` | `len + 2` | `len + langLen + 6` |
| language text start | — | `nodeStart + 1` |
| code text start | `nodeStart` | `nodeStart + langLen + 3` |

The code text start is the one real hazard: `CodeBlockBox.textStart == globalStart` is true today and every
position-touching code path inherits it. See §6.

The language is **off the flat plainText axis**, exactly like the author line: a plain-text copy of a code
block yields the code, not the language name. Rich copy carries it inside the `Block.code` fragment, which
already encodes `language`.

## 4. UIKit: `CodeBlockBox`

Replace the static `languageLine: NSAttributedString?` with a real editable layout:

- **`languageLayout: BlockLayoutEngine`**, built the same way the display line is built today — body spec +
  bold via `FontResolver.font(spec:mapper.styleSheet.metrics.body, bold: true, …)` — but **not lowercased**
  (as-typed), coloured `theme.codeLanguageText`.
- **`languageLineExtent` becomes unconditional**: `max(languageLayout.correctedBoundingHeight,
  languageEmptyLineHeight) + mapper.styleSheet.codeLanguageSpacing`. It already feeds `height`,
  `measuredHeight(forWidth:)` and `textOrigin`, so all three shift for every code block.
- **`leafRegions()` returns `[language, code]`, in document order** (see §6 — this is load-bearing).
- **`closestPosition(toCanvasPoint:)`** routes a point above the code's `textOrigin.y` into the language
  region, mirroring `PullQuoteBox`'s author branch inverted, so the placeholder is directly tappable.
- **`currentCode()`** reads the language back from `languageLayout.attributedString.string`, trimmed;
  empty → `nil`. Runs stay plain (`CodeBlock.runs` is unchanged).
- **`languageTypingAttributes()`** — bold body + language colour — so the first character typed into an
  empty language line is not 17pt body text that then pollutes the model on read-back (the exact bug the
  author line's `authorTypingAttributes()` exists to prevent).
- **Placeholder** drawn in `theme.codeLanguagePlaceholder` when the region is empty, from
  `placeholders.codeLanguage`.

**Theme:** add `codeLanguageText` and `codeLanguagePlaceholder`, defaulting (like `quoteAuthorText` /
`quoteAuthorPlaceholder` do) to the colours in use today — `containerPlaceholder` and `placeholder` — so no
existing rendering shifts.

**Accepted consequence:** an empty-language code block is now ~one line taller in the editor than the
message it renders to, because the renderer draws no language line when there is none. This is the same
authoring-vs-rendered gap the "Add author" placeholder already has, and it is the direct cost of the
"always visible" decision. It does not affect InstantPage V2 parity for blocks that *do* carry a language.

## 5. Editing semantics

All of these mirror the author line unless the **leading** position forces otherwise.

| Interaction | Behaviour |
|---|---|
| Typing into an empty language line | `languageTypingAttributes()` (bold body + language colour). |
| Bold / italic / link / colour / spoiler / custom emoji / formula | Inert when the selection lies entirely in a `.codeLanguage` region — the `selectionIsEntirelyInAuthorRegion` lock-out pattern. The region is plain text. |
| Paste into the region | Plain text; formatting dropped, newlines stripped. |
| Return | Move the caret to the start of the code text. No newline, no split. (Diverges from the author, which splits — the author is trailing, the language is leading, and a `.Pre` language has no second line.) |
| Backspace at the start of the region | If the whole block is empty (no language text **and** no code text) → convert to a body paragraph. This is today's empty-code rule relocated to the block's new first position. Otherwise → step the caret out to the previous block's end via `prevTextPosition`; when the code block is the document's first block there is nowhere to step, so it is a no-op. Never merges the language into anything; never deletes a non-empty block. |
| Forward-delete at the end of the region | Move the caret to the code start; no text change. It must not pull the first code character up into the language. |
| Arrow keys | Nothing bespoke: two ordered leaf regions traverse generically. **The empty language region is NOT skipped** — unlike `isEmptyAuthorRegion`, which makes an empty author line arrow-unreachable. The language line is always present and always visible, so skipping it when empty would leave it reachable only by tap. This is the one deliberate divergence from the author's navigation treatment. |
| Spell check / text services | No `.codeLanguage` case in `+SpellCheck`'s `blockID(for:)` (so it is skipped, as `.code` already is), and the region reports no-autocapitalize / no-autocorrect traits — otherwise iOS turns `swift` into `Swift`. |
| Code toggle **off** (`Format ▸ Code` on an existing code block) | The language is dropped; the code text becomes the paragraph's text. |
| Code toggle **on** | New block starts with `language == nil` and the caret **in the code text**, not in the language line. |

## 6. The structural guard, and the sites to re-point

Two facts collide here, and the collision is the most dangerous part of this change:

1. **`leafRegions()` must be in document order** — `DocumentCanvasView+Navigation` states it
   ("regions are in document order") and `nextTextPosition` / `prevTextPosition` / vertical nav index
   `allLeafRegions()` positionally. So the code box must return `[language, code]`.
2. **`leafRegions().first` is used elsewhere as "the box's primary text region"** — notably
   `activeStack(at:)` (`+Editing:814`), `+ComposerSelection:77`, `TableBlockBox:483/504/525`, and a dozen
   `…leafRegions().first?.globalStart` caret-placement sites after conversions.

For every existing box those two readings coincide. For the code box they stop coinciding, and if nothing
is done, `activeStack` resolves a caret in the **language** line to the code box with a **language-relative
`local`** — and every caller that then touches `active.box.textLayout` (which is the *code* layout) writes
at the wrong offset. `insertCodeBlockNewline` would splice a newline into the code text at the language's
offset. This compiles, and nothing in the diff looks wrong.

**The guard:** `CanvasBlock`'s `textStart` / `textLength` / `textRef` already mean *the box's primary text
region*, and for the code box they keep meaning **the code region**. Change `activeStack(at:)`'s leaf test
(`+Editing:814`) from "the box's first leaf region" to "the box's **primary** leaf region — the one that
starts at `textStart`":

```swift
// Match by the PRIMARY text region, not leafRegions().first: a code box's FIRST region is its
// LANGUAGE line, and resolving a language position to the box would hand every caller a
// language-relative `local` to use against the box's CODE layout.
if let primary = b.leafRegions().first(where: { $0.globalStart == b.textStart }),
   pos >= primary.globalStart, pos <= primary.globalStart + primary.length {
    return (stack, b, pos - primary.globalStart, i)
}
```

Behaviour is unchanged for every existing box, for two different reasons, and both matter:

- **Leaf boxes** (`BlockBox`, `MediaBlockBox`, `PullQuoteBox`, and `CodeBlockBox` today) have their primary
  region *as* their first region, so `first(where:)` selects exactly what `first` selected. A caption-less
  `MediaBlockBox` has no regions at all and still matches nothing.
- **Container boxes** (`BlockQuoteBox`, `DetailsBox`, `TableBlockBox`) report a *degenerate*
  `textStart == nodeStart, textLength == 0`, and no child region begins at `nodeStart` (children start at
  `nodeStart + 1` or deeper). So they match nothing here — which is what happens today too, since this
  branch is only reached for a container at its `nodeStart` / `nodeStart + nodeSize` boundary, where its
  first child region does not contain `pos` either. **The naive form `pos >= b.textStart, pos <= b.textStart
  + b.textLength` would NOT be equivalent**: it would newly match every container box at exactly
  `pos == nodeStart` and return the container with `local == 0`, where today that position correctly falls
  through to the fallback (which explicitly refuses container boxes, `+Editing:826-827`).

With the guard in place, a language-region position returns **nil** from `activeStack` — exactly as an
author-region position already does (see the fallback's comment at `+Editing:823-825`). Every legacy `box is
CodeBlockBox` branch — `insertCodeBlockNewline`, `codeBlockDoubleReturnExit`, `exitCodeBlockToBodyParagraph`,
the empty-code Backspace at `+UITextInput:1127`, `startsEmptyContainer`, block-formula insertion at
`+Formula:24` — is then **inert in the language line by construction**, rather than by each site
remembering to ask which region. The new language-line semantics in §5 are implemented on the
`leafRegion(containingGlobal:)` path, which is how the author line is already handled.

**Sites that must still be re-pointed or re-read explicitly:**

- `DocumentCanvasView:1961` — `blockID(for:)` gains the `.codeLanguage` case.
- `+ParagraphFormat:80` (code creation) and any `…leafRegions().first?.globalStart` used to park a caret
  "at the start of this box": for a code box that is now the **language** line. Every such site that means
  "start typing code here" must use the code region explicitly.
- `+ComposerSelection:77` — decide explicitly whether the composer's selection mapping covers the language
  region (it should follow the plainText-axis decision: it does not).
- `+Editing:588-591` / `coverableContentStart(_:)` / `coverableContentEnd(_:)` — whole-block coverage must
  span the language region, or a select-all-then-type over a code block leaves an orphan language.
- `+State:56` `isCodeBlock` — stays true with the caret in the language line (it is still a code block),
  but the format menu's character-format items must be disabled there per §5.
- `+Lists:55` — code→list conversion reads the code text; confirm it ignores the language.
- `+SpellCheck:11` — deliberately gets **no** case (skip).
- `+Navigation:12` `isEmptyAuthorRegion` — deliberately **not** extended to `.codeLanguage` (§5).

None of these fail to compile if missed. Each gets a test.

## 7. Hosts and localization

- `RichTextEditorPlaceholders` gains `codeLanguage: String` (default `"Language"`).
- Both hosts pass a new localized string alongside the ones they already pass:
  `RichTextEditorChatInputNode.swift:174` and `RichTextAttachmentScreen.swift:1365` →
  `strings.RichText_PlaceholderCodeLanguage`. Add the entry to the app's `.strings`.
- `CodeStyle.languageSpacing` already exists per host; no new host knob.
- No composer-side change: the chat composer gets the feature by hosting the same editor view.

## 8. Testing

**Core (`RichTextEditorCoreTests`)**

- `CodeBlockPositionTests` — updated: `documentSize == len + langLen + 6`; position `nodeStart+1` resolves
  to `.codeLanguage` at the right offset; `nodeStart + langLen + 3` resolves to `.code`; a nil-language
  block still has a zero-length language region (present, empty).
- Model round-trip: as-typed casing preserved; trimming; empty → `nil`.

**UIKit (`RichTextEditorUIKitTests`)**

- Geometry: `height` / `measuredHeight` include the language extent when the language is empty
  (`CodeBlockBoxTests`, `CanvasBlockMeasureTests` shift); `textOrigin` sits below the language line.
- Tap routing: a point in the language band resolves into `.codeLanguage`; a point in the code band into
  `.code`.
- One test per row of §5: Return, both Backspace-at-start branches, forward-delete at end, format
  lock-out, empty-region typing attributes, read-back trimming/nil, arrows entering an empty language line.
- Regression guard for §6: with the caret in the language line, `activeStack(at:)` returns nil, and
  `insertCodeBlockNewline()` is a no-op (this is the silent-corruption case).

**Build**

`swift test` for the package, then the full Bazel app build — a new `TextNodeRef` case only surfaces
exhaustive-switch breaks at the app build (`Block.code` did exactly this once already, per the
RichTextEditor CLAUDE.md).

## 9. Load-bearing invariants to carry into the plan

1. `leafRegions()` is **document order** (navigation indexes it positionally); `textStart`/`textLength`/
   `textRef` are the **primary region**. For the code box these differ — that is the whole hazard of §6.
2. `.code`'s DocNode container is a token shape only; it must not make code positions read as
   "inside a block quote" (verified: `isInsideBlockQuote` is box-class based).
3. The language region is off the flat plainText axis (mirrors the author).
4. The empty language region is navigable (deliberately unlike the empty author region).
5. The renderer is untouched; the editor is intentionally taller than the rendered message for a
   language-less code block.
