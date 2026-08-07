# InstantPage V2 quote content scale

Make quoted content — block quotes and pull quotes — render one typographic step below the
surrounding body: font sizes and every spacing tuned against the body font scale by `15/17`, applied
once regardless of nesting depth.

**Status:** design approved 2026-08-07; not yet implemented.

## Motivation

The two quote paths disagree about font size today.

`layoutQuoteText` — which serves pull quotes and the single-paragraph block-quote fast path — pushes
an absolute `styleStack.push(.fontSize(15.0))` over the theme's 17pt paragraph
(`InstantPageV2Layout.swift:2854`). The multi-block path, `layoutBlockQuote`, lays its children out
through `layoutBlock` with the unmodified theme, so they render at 17pt.

The result: a quote containing one paragraph renders at 15pt, and the same quote with a second
paragraph added renders at 17pt.

Fixing that by pushing 15pt in the multi-block path too would only move the problem. Everything else
inside a quote — block gaps, list gutters, code-block padding, caption pads — is tuned against a 17pt
body, so the text would shrink while the rhythm around it stayed coarse. And an absolute 15pt ignores
the full-page Instant View reader's font-size setting, which multiplies the whole theme: at the
largest setting a quote would sit at 15pt inside 21pt body text, and at the smallest it could render
*larger* than the text around it.

## Decisions

These were settled during design and the rest of the document depends on them.

**Ratio, not absolute.** The scale is `15.0/17.0` — the theme's quote size over its paragraph size —
applied as a second `sizeMultiplier` on top of whatever the theme already carries. In the chat bubble,
which hardcodes `paragraph: 17.0`
(`ChatMessageRichDataBubbleContentNode.swift:492`), this yields exactly 15pt. In the reader it tracks
the user's font-size setting, so a quote is always one step below its surroundings.

**Idempotent, not compounding.** Entering a quote *sets* the content scale rather than multiplying the
enclosing one. Every quote body is 15pt whatever its depth; nesting is conveyed by the accent bars and
indentation that already distinguish levels. Compounding would reach 11.7pt at depth three, and
markdown-composed rich messages nest quotes routinely.

**Scope: fonts plus everything tuned against the body font.** Block spacing, list metrics, code-block
padding, caption and credit pads, and the quotes' own insets all scale. Three categories are excluded
by deliberate decision, enumerated under "Excluded" below.

## Architecture

### The metrics value

```swift
struct InstantPageMetrics {
    let baseBlockSpacing: CGFloat
    let blockVerticalPadding: CGFloat
    // … full inventory below

    init(scale: CGFloat)                  // each field: floorToScreenPixels(literal * scale)
    static let unscaled = InstantPageMetrics(scale: 1.0)
}
```

Every scalable constant becomes a named field, scaled once in the initializer. Layout functions read
`context.metrics.captionTopPad` instead of `9.0`.

The point of collecting them is that **the struct is the coverage list**. This change's entire risk is
an incomplete sweep — a literal left raw renders 17pt-tuned geometry inside a 15pt quote, which no
diff review catches and no existing test covers. With the constants named in one place, "what scales,
what doesn't, and why" is reviewable in one screen instead of being an emergent property of ~100
scattered call sites.

The type is named `InstantPageMetrics`, not `...V2Metrics`, because V1 names it too — see "V1"
below.

### The context seam

`LayoutContext` gains `var metrics` alongside a now-`var theme`, plus two values computed once in
`layoutInstantPageV2` and carried read-only:

```swift
quoteTheme   = theme.withUpdatedFontStyles(sizeMultiplier: 15.0/17.0,
                                           lineSpacingFactor: 1.0,
                                           forceSerif: theme.serif)
quoteMetrics = InstantPageMetrics(scale: 15.0/17.0)
```

Both quote entry points — `layoutBlockQuote` and `layoutQuoteText` — do the same four lines:

```swift
let savedTheme = context.theme, savedMetrics = context.metrics
context.theme = context.quoteTheme       // set, not multiply — this is the idempotence
context.metrics = context.quoteMetrics
defer { context.theme = savedTheme; context.metrics = savedMetrics }
```

Three properties follow from putting the scale on the context rather than in the quote functions:

- **Every block type a quote can contain is covered without knowing about quotes** — lists, code
  blocks, tables, details, nested quotes, and formulas (`layoutFormulaBlock` reads its font size from
  `context.theme`'s paragraph attributes and bakes it into the rendered math image, so quoted math
  scales for free).
- **Idempotence is structural.** A nested quote assigns the same precomputed `quoteTheme`. Deriving
  the scaled theme from `context.theme` at each entry would compound — and would read as correct in a
  diff.
- **Restoration is lexical.** A quote inside a details body or a table cell restores via `defer`, so
  the blocks after it are unaffected.

`15.0/17.0` is written as a ratio against the theme's own paragraph size rather than as `0.882`, so it
stays legible as "one step below body".

`withUpdatedFontStyles` takes `lineSpacingFactor: 1.0` because that field is already a *factor* on the
font size and would otherwise double-apply. Note the warning in `InstantPageTheme.swift`: the method
reconstructs the theme field by field, and any field omitted there silently reverts to an `init`
default. We call it on a bubble theme carrying eight theme-derived colours, so re-read it at
implementation time rather than trusting it.

### The load-bearing invariant

**`InstantPageMetrics(scale: 1.0)` must be bit-identical to today's literals.** Everything outside a
quote — most of every page — must lay out exactly as it does now. This is checkable rather than
assertable: `InstantPageMetrics` is a pure value type, so a unit test can compare it field by field
against the literals.

## Inventory

| group | fields (current values) |
|---|---|
| Block rhythm (`InstantPageLayoutSpacings.swift`) | `baseBlockSpacing` 8 · `blockVerticalPadding` 4 · `headingVerticalPadding` 8 · `dividerVerticalPadding` 4 · `detailsAdjacentSpacing` 4 |
| Caption/credit (`layoutCaptionAndCredit`) | `captionTopPad` 9 · `creditTopPad` 10 · `coverCaptionExtraPad` 14 |
| Quote (`layoutBlockQuote`, `layoutQuoteText`) | `quoteVerticalInset` 6 · `pullQuoteVerticalInset` 12 · `quoteLineInset` 9 · `quoteLeadingInset` 9 · `quoteTrailingInset` 16 · `pullQuotePadding` 30 · `quoteAttributionGap` 3 |
| Code block (`layoutCodeBlock`) | `codeBlockVerticalInset` 6 · `codeBlockHorizontalInset` 9 · `codeBlockFontSize` 15 · `codeBlockLanguageFontSize` 11 |
| List (`layoutList`, `InstantPageShapeItem.swift`) | `listIndexSpacing` 8 · `checklistMarkerSize` 18×18 · `bulletDiameter` 5 · `listItemTextwardOffset` 2 · `numberMarkerTextwardOffset` 5 |
| Table (`layoutTable`) | `tableCellInsets` 7/13 · `tableMinCompressedColumnWidth` 60 |
| Details (`layoutDetails`) | `detailsMinTitleHeight` 36 · `detailsTitleVerticalPad` 15 · `detailsChevronReserve` 32 · `detailsTitleHorizontalInset` 23 |
| Button rows (`InstantPageV2ButtonRowLayout.swift`) | `blockButtonHeight` 40 · `blockButtonSpacing` 6 |

Three notes on the table:

- `blockVerticalPadding` and `dividerVerticalPadding` are both 4 today and stay separate fields. They
  are different quantities that happen to coincide; collapsing them would make a future change to one
  silently move the other.
- `detailsAdjacentSpacing` is the `+ 4.0` in `spacingBetweenBlocks`' arm for a `.details` block
  followed by a **non**-`.details` block. Two adjacent `.details` blocks return the two paddings with
  no base and are unaffected.
- `quoteAttributionGap` currently exists as a duplicated literal `3.0` at two sites —
  `InstantPageV2Layout.swift:2784` (multi-block quote) and `:2893` (`layoutQuoteText`). Making it a
  metric unifies them as a side effect.

### Two font-size overrides

`layoutCodeBlock` pushes an absolute `.fontSize(15.0)` over the theme's 14pt `codeBlock` category
(`InstantPageV2Layout.swift:2627`). Left alone it is the same leak as the quote's own push — code
inside a quote would stay 15pt while its surroundings shrank. As the metric `codeBlockFontSize` it
yields exactly 15.0 at scale 1.0 and scales inside a quote.

`layoutQuoteText`'s `.fontSize(15.0)` push needs no metric: under the scaled theme its `.paragraph`
category *is* 15pt, so the push is deleted. This is what makes the one- versus two-paragraph split
disappear.

### Excluded

- **`layoutTextItem` entirely** (35 of the file's 251 literal-bearing lines). Every number in it is
  font-metric-relative — `lineSpacingFactor` 1.12, the 0.85 line-height factor, the `- 4.0` baseline
  slack, `lineBoxTopInset`. The font already scales; these follow it. Scaling them would double-apply.
- **Minimum separations and optical nudges** — the hardcoded `1.0` returns in `spacingBetweenBlocks`
  (paragraph pairs, adjacent media), the `+2.0` adjustments, `instantPageBulletMarkerVerticalOffset`
  1, `instantPageV2NumberedListItemTextwardOffset` 1. These are floors and 1pt corrections, not sizes
  derived from a font, and `floorToScreenPixels(1.0 * 15/17)` is 0.67pt at 3x. The exclusion is
  expressed by their absence from the struct rather than by a numeric threshold rule.
- **Chrome identity** — accent bar widths 3, corner radii (quote 6, table 10), quote-mark icons 12×10
  and their 6pt inset. These read as "this is a quote", not as typography;
  `floorToScreenPixels(3 * 15/17)` is a visibly thinner 2.33pt bar for no gain.
- **Hairlines** — `v2TableBorderWidth` (`UIScreenPixel * 2`), the divider's `UIScreenPixel`. Scaling a
  pixel-quantised value either does nothing or destroys it.
- **Media frames** — `instantPageV2MediaFrame` sizing, the 4pt edge bleed, mosaic geometry, the
  `min(1000, width)` height cap. These are width-driven: media fills the band, and the band is already
  narrowed by the quote's insets, so scaling would shrink photos twice. Media *captions* scale as text.

## V1

`spacingBetweenBlocks` and the two `InstantPageShapeItem.swift` list constants are shared with the V1
renderer, which calls the spacing function from six sites in `InstantPageLayout.swift`.

- The list constants stay as they are; `InstantPageMetrics` holds scaled *copies*. V1 reads the
  globals unchanged.
- `spacingBetweenBlocks` gains a **required** `metrics:` parameter — not one defaulting to
  `.unscaled`. That is six mechanical edits in V1, which only ever passes `.unscaled`, and in exchange
  a new V2 call site cannot silently get unscaled spacing. Defaulting the parameter would reintroduce
  the silent-failure mode this whole approach was chosen to avoid.

V1's rendering is otherwise untouched.

## Render-time fonts

A view that derives a font from the page theme at render time would render quoted content unscaled
whatever the layout did. The V2 renderer reads the theme for colours only, with one exception:
`InstantPageV2CodeBlockView.update` builds the code-block language label as a hardcoded
`UIFont(name: "Menlo", size: 11.0)` (`InstantPageRenderer.swift:2136`). The item carries
`languageLabelColor` but no size.

Add `languageFontSize` to `InstantPageV2CodeBlockItem`, set from metrics at layout time. It is the
only place the scale can leak past the layout.

The following need no work — verified during design: inline custom emoji and inline images size off
the font inside `layoutTextItem` and are baked into the attributed string; `instantPageMathAttachment`
takes its size from `context.theme`; the reveal cost map, `lastTextLineFrame` and `textLineMetrics`
all derive from laid-out items; the markdown round-trip is model-level and never sees layout.

## Accepted consequences

**Quote-only bubbles get narrower.** A `fitToWidth` bubble hugs `maxLineWidth`, and the text is
smaller. Expected.

**Small categories get smaller.** The ratio applies to every text category, so inside a quote caption
goes 15 → 13pt, credit 13 → 11pt, and H1 24 → 21pt. 11pt credit under a quoted image is small. This is
accepted rather than floored: a floor means a category that stops tracking the ratio, which
reintroduces the absolute-versus-ratio split this design removes.

## Verification

1. **The bit-identity gate.** A unit test comparing `InstantPageMetrics(scale: 1.0)` field by field
   against today's literals. Precedent for the target exists — `//submodules/TextFormat:TextFormatTests`,
   run via `Make.py test --target`, with an `ios_test_runner` pinned to a real device/OS (the default
   runner picks an invalid device and the test process exits 15). If standing up an `ios_unit_test`
   for InstantPageUI proves disproportionate, the fallback is confirming a quote-free page renders
   identically — but the test is preferred, since "nothing outside a quote changed" is the claim
   carrying all the risk.
2. **Full `Make.py build`.** There is no selective per-module build.
3. **Visual matrix**, performed by the user (this project's convention is that the assistant builds
   and stops; the user installs and verifies):
   - one- versus two-paragraph quote in a bubble — these must now match, which is the originating bug;
   - a quote nested three deep — every level at 15pt;
   - a quote containing each of: list, code block, table, details, media with caption, formula;
   - a pull quote;
   - the full-page reader at the smallest and largest font-size settings, where ratio versus absolute
     is visible;
   - a page with no quote at all, which must look untouched.

## Residual risk

Coverage — a literal in one of the affected sites that keeps its raw value. The sites are
`layoutTable`, `layoutDetails`, `layoutQuoteText`, `layoutBlockQuote`, `layoutList`,
`layoutCaptionAndCredit` and `layoutCodeBlock` in `InstantPageV2Layout.swift`, plus
`InstantPageLayoutSpacings.swift` and `InstantPageV2ButtonRowLayout.swift`. `layoutTextItem` is
deliberately *not* in this list — see "Excluded"; it is the one high-literal-density function that
must be left alone, and touching it is a defect rather than an omission.

Mitigation: the struct is the checklist, plus a grep pass over those sites after the mechanical edit.
