# InstantPage V2 Quote Content Scale — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render quoted content — block quotes and pull quotes — one typographic step below the surrounding body, scaling fonts and every body-font-tuned spacing by `15/17`, applied once regardless of nesting depth.

**Architecture:** A pure value type `InstantPageMetrics` names every scalable geometry constant and scales them in its initializer. `LayoutContext` carries a current `theme` + `metrics` pair plus a precomputed `quoteTheme` + `quoteMetrics`; the two quote entry points swap them in and restore via `defer`. Layout functions read `context.metrics.<field>` instead of raw literals. Because the scale lives on the context, every block type a quote can contain is covered without knowing about quotes.

**Tech Stack:** Swift, Bazel (`Make.py` wrapper), `ios_unit_test` via `ios_test_runner`, UIKit/CoreText.

**Spec:** `docs/superpowers/specs/2026-08-07-instantpage-v2-quote-font-scale-design.md`

## Global Constraints

- **`InstantPageMetrics(scale: 1.0)` must be bit-identical to today's literals.** Everything outside a quote must lay out exactly as it does now. This is the invariant carrying all the risk in this change.
- **The scale is `15.0 / 17.0`**, written as that ratio (theme quote size over theme paragraph size), never as `0.882`.
- **Idempotent, never compounding.** Entering a quote *assigns* `context.quoteTheme` / `context.quoteMetrics`. Never derive the scaled theme from `context.theme`.
- **Scaling rule for every metric field:** `floorToScreenPixels(literal * scale)`. `floorToScreenPixels` comes from `Display`, already imported by every file touched here.
- **V1 (`InstantPageLayout.swift`) behaviour must not change.** It shares `spacingBetweenBlocks` and the `InstantPageShapeItem.swift` list constants; it only ever passes `InstantPageMetrics.unscaled`.
- **Do not touch `layoutTextItem`.** Its literals are font-metric-relative and follow the scaled font automatically; scaling them double-applies. Editing a number there is a defect, not an omission.
- **Excluded from scaling** (leave as raw literals): chrome identity (accent bar widths `3.0`, corner radii, quote-mark icons and their insets), hairlines (`v2TableBorderWidth`, `UIScreenPixel`), media frame geometry (`instantPageV2MediaFrame`, the 4pt edge bleed, mosaic geometry, the `min(1000, width)` cap), and minimum separations / 1–2pt optical nudges (the hardcoded `1.0` returns in `spacingBetweenBlocks`, its `+2.0` adjustments, `instantPageBulletMarkerVerticalOffset`, `instantPageV2NumberedListItemTextwardOffset`).
- **Every module here builds with `-warnings-as-errors`.** An unused variable or an always-false cast fails the build.
- **Build command** (used as the test cycle for every task after Task 1):

```bash
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion \
 --cacheDir ~/telegram-bazel-cache build \
 --configurationPath build-system/appstore-configuration.json \
 --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
 --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 --configuration=debug_sim_arm64
```

- **There is no selective per-module build.** The full app target is the only supported build, and it is the compile check for every task.
- **Do not install to the simulator.** Build, then stop. The user installs and does visual verification.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `submodules/InstantPageUI/Sources/InstantPageMetrics.swift` | The metrics value type: names every scalable constant, scales in `init(scale:)` | **Create** |
| `submodules/InstantPageUI/Tests/InstantPageMetricsTests.swift` | Bit-identity gate at scale 1.0 + scaled-value regression | **Create** |
| `submodules/InstantPageUI/BUILD` | Test lib + runner + `ios_unit_test` targets | Modify |
| `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` | `LayoutContext` seam, quote swap, all metric reads | Modify |
| `submodules/InstantPageUI/Sources/InstantPageLayoutSpacings.swift` | `spacingBetweenBlocks` takes `metrics:` | Modify |
| `submodules/InstantPageUI/Sources/InstantPageLayout.swift` | V1 passes `.unscaled` at six call sites | Modify |
| `submodules/InstantPageUI/Sources/InstantPageV2ButtonRowLayout.swift` | Button row reads metrics | Modify |
| `submodules/InstantPageUI/Sources/InstantPageRenderer.swift` | Code-block language label reads `item.languageFontSize` | Modify |

`InstantPageMetrics` gets its own file rather than living in `InstantPageV2Layout.swift` (already 4300 lines). It is a pure value type with no dependency beyond `CoreGraphics` + `Display`, which is what makes it unit-testable.

---

### Task 1: The `InstantPageMetrics` value type and its bit-identity test

Nothing consumes it yet. The deliverable is the type plus the test proving `scale: 1.0` reproduces today's literals exactly.

**Files:**
- Create: `submodules/InstantPageUI/Sources/InstantPageMetrics.swift`
- Create: `submodules/InstantPageUI/Tests/InstantPageMetricsTests.swift`
- Modify: `submodules/InstantPageUI/BUILD`

**Interfaces:**
- Produces: `struct InstantPageMetrics` with `init(scale: CGFloat)`, `static let unscaled`, and the fields listed below. Every later task reads these exact names.

- [ ] **Step 1: Write the metrics type**

Create `submodules/InstantPageUI/Sources/InstantPageMetrics.swift`:

```swift
import Foundation
import UIKit
import Display

/// Every geometry constant that is tuned against the body font, scaled once.
///
/// This type exists to make coverage **reviewable**. The risk in a content-scale change is an
/// incomplete sweep: one literal left raw renders 17pt-tuned geometry inside a 15pt quote, which no
/// diff review catches and no test covers. Collecting the constants here makes "what scales, what
/// doesn't, and why" a single screen instead of an emergent property of ~100 call sites.
///
/// Membership IS the policy. A constant that must not scale — chrome identity (bar widths, corner
/// radii, quote marks), hairlines (`UIScreenPixel`-derived widths), media frame geometry, and
/// minimum separations or 1–2pt optical nudges — is expressed by its ABSENCE from this struct, not
/// by a numeric threshold rule applied at a call site.
///
/// `layoutTextItem` is likewise absent by design: its literals are font-metric-relative
/// (`lineSpacingFactor`, the line-height factor, the baseline slack, `lineBoxTopInset`) and already
/// follow the scaled font. Scaling them here would double-apply.
///
/// **Invariant: `InstantPageMetrics(scale: 1.0)` is bit-identical to the literals it replaced.**
/// Everything outside a quote — most of every page — must lay out exactly as it did before this
/// type existed. `InstantPageMetricsTests` is that check.
struct InstantPageMetrics {
    // Block rhythm (InstantPageLayoutSpacings.swift).
    let baseBlockSpacing: CGFloat
    /// `blockVerticalPadding` and `dividerVerticalPadding` are both 4 today and stay separate
    /// fields: they are different quantities that happen to coincide, and collapsing them would
    /// make a future change to one silently move the other.
    let blockVerticalPadding: CGFloat
    let headingVerticalPadding: CGFloat
    let dividerVerticalPadding: CGFloat
    /// The gap added for a `.details` block followed by a NON-`.details` block. Two adjacent
    /// `.details` blocks take a different arm and never see this.
    let detailsAdjacentSpacing: CGFloat

    // Caption / credit (layoutCaptionAndCredit, layoutTypedMediaWithCaption, layoutMediaWithCaption).
    let captionTopPad: CGFloat
    let creditTopPad: CGFloat
    let coverCaptionExtraPad: CGFloat

    // Quotes (layoutBlockQuote, layoutQuoteText).
    let quoteVerticalInset: CGFloat
    let pullQuoteVerticalInset: CGFloat
    let quoteLineInset: CGFloat
    let quoteLeadingInset: CGFloat
    let quoteTrailingInset: CGFloat
    let pullQuotePadding: CGFloat
    /// Body → attribution gap. Was a `3.0` duplicated at two sites; this unifies them.
    let quoteAttributionGap: CGFloat

    // Code blocks (layoutCodeBlock).
    let codeBlockVerticalInset: CGFloat
    let codeBlockHorizontalInset: CGFloat
    /// `layoutCodeBlock` overrides the theme's 14pt `codeBlock` category with an absolute 15pt.
    /// As a metric it still yields exactly 15.0 unscaled, and shrinks inside a quote instead of
    /// leaving code at full size while its surroundings scale.
    let codeBlockFontSize: CGFloat
    /// The code-block language label, built at RENDER time in `InstantPageV2CodeBlockView`. It is
    /// the only font in the V2 renderer not baked into an attributed string at layout time, so it
    /// has to travel on the item to scale at all.
    let codeBlockLanguageFontSize: CGFloat

    // Lists (layoutList; the bullet/textward values are SCALED COPIES of the
    // InstantPageShapeItem.swift globals, which stay as they are because V1 reads them).
    let listIndexSpacing: CGFloat
    let checklistMarkerSize: CGSize
    let bulletDiameter: CGFloat
    let listItemTextwardOffset: CGFloat
    let numberMarkerTextwardOffset: CGFloat

    // Tables (layoutTable).
    let tableCellInsets: UIEdgeInsets
    let tableMinCompressedColumnWidth: CGFloat

    // Details (layoutDetails).
    let detailsMinTitleHeight: CGFloat
    let detailsTitleVerticalPad: CGFloat
    let detailsChevronReserve: CGFloat
    let detailsTitleHorizontalInset: CGFloat

    // Button rows (InstantPageV2ButtonRowLayout.swift).
    let blockButtonHeight: CGFloat
    let blockButtonSpacing: CGFloat

    init(scale: CGFloat) {
        func s(_ value: CGFloat) -> CGFloat {
            return floorToScreenPixels(value * scale)
        }

        self.baseBlockSpacing = s(8.0)
        self.blockVerticalPadding = s(4.0)
        self.headingVerticalPadding = s(8.0)
        self.dividerVerticalPadding = s(4.0)
        self.detailsAdjacentSpacing = s(4.0)

        self.captionTopPad = s(9.0)
        self.creditTopPad = s(10.0)
        self.coverCaptionExtraPad = s(14.0)

        self.quoteVerticalInset = s(6.0)
        self.pullQuoteVerticalInset = s(12.0)
        self.quoteLineInset = s(9.0)
        self.quoteLeadingInset = s(9.0)
        self.quoteTrailingInset = s(16.0)
        self.pullQuotePadding = s(30.0)
        self.quoteAttributionGap = s(3.0)

        self.codeBlockVerticalInset = s(6.0)
        self.codeBlockHorizontalInset = s(9.0)
        self.codeBlockFontSize = s(15.0)
        self.codeBlockLanguageFontSize = s(11.0)

        self.listIndexSpacing = s(8.0)
        self.checklistMarkerSize = CGSize(width: s(18.0), height: s(18.0))
        self.bulletDiameter = s(instantPageBulletMarkerDiameter)
        self.listItemTextwardOffset = s(instantPageListItemTextwardOffset)
        self.numberMarkerTextwardOffset = s(instantPageV2NumberMarkerTextwardOffset)

        self.tableCellInsets = UIEdgeInsets(top: s(7.0), left: s(13.0), bottom: s(7.0), right: s(13.0))
        self.tableMinCompressedColumnWidth = s(60.0)

        self.detailsMinTitleHeight = s(36.0)
        self.detailsTitleVerticalPad = s(15.0)
        self.detailsChevronReserve = s(32.0)
        self.detailsTitleHorizontalInset = s(23.0)

        self.blockButtonHeight = s(40.0)
        self.blockButtonSpacing = s(6.0)
    }

    /// The page-level metrics. MUST equal the literals this type replaced — see the invariant above.
    static let unscaled = InstantPageMetrics(scale: 1.0)

    /// Quoted content sits one typographic step below body: the theme's quote size over its
    /// paragraph size. Written as the ratio rather than 0.882 so it stays legible as what it means.
    static let quoteScale: CGFloat = 15.0 / 17.0
}
```

- [ ] **Step 2: Write the failing test**

Create `submodules/InstantPageUI/Tests/InstantPageMetricsTests.swift`:

```swift
import XCTest
import UIKit
@testable import InstantPageUI

final class InstantPageMetricsTests: XCTestCase {
    /// The load-bearing invariant: at scale 1.0 every field equals the literal it replaced, so
    /// every page outside a quote lays out exactly as it did before this type existed.
    func testUnscaledMetricsMatchOriginalLiterals() {
        let m = InstantPageMetrics.unscaled

        XCTAssertEqual(m.baseBlockSpacing, 8.0)
        XCTAssertEqual(m.blockVerticalPadding, 4.0)
        XCTAssertEqual(m.headingVerticalPadding, 8.0)
        XCTAssertEqual(m.dividerVerticalPadding, 4.0)
        XCTAssertEqual(m.detailsAdjacentSpacing, 4.0)

        XCTAssertEqual(m.captionTopPad, 9.0)
        XCTAssertEqual(m.creditTopPad, 10.0)
        XCTAssertEqual(m.coverCaptionExtraPad, 14.0)

        XCTAssertEqual(m.quoteVerticalInset, 6.0)
        XCTAssertEqual(m.pullQuoteVerticalInset, 12.0)
        XCTAssertEqual(m.quoteLineInset, 9.0)
        XCTAssertEqual(m.quoteLeadingInset, 9.0)
        XCTAssertEqual(m.quoteTrailingInset, 16.0)
        XCTAssertEqual(m.pullQuotePadding, 30.0)
        XCTAssertEqual(m.quoteAttributionGap, 3.0)

        XCTAssertEqual(m.codeBlockVerticalInset, 6.0)
        XCTAssertEqual(m.codeBlockHorizontalInset, 9.0)
        XCTAssertEqual(m.codeBlockFontSize, 15.0)
        XCTAssertEqual(m.codeBlockLanguageFontSize, 11.0)

        XCTAssertEqual(m.listIndexSpacing, 8.0)
        XCTAssertEqual(m.checklistMarkerSize, CGSize(width: 18.0, height: 18.0))
        XCTAssertEqual(m.bulletDiameter, 5.0)
        XCTAssertEqual(m.listItemTextwardOffset, 2.0)
        XCTAssertEqual(m.numberMarkerTextwardOffset, 5.0)

        XCTAssertEqual(m.tableCellInsets, UIEdgeInsets(top: 7.0, left: 13.0, bottom: 7.0, right: 13.0))
        XCTAssertEqual(m.tableMinCompressedColumnWidth, 60.0)

        XCTAssertEqual(m.detailsMinTitleHeight, 36.0)
        XCTAssertEqual(m.detailsTitleVerticalPad, 15.0)
        XCTAssertEqual(m.detailsChevronReserve, 32.0)
        XCTAssertEqual(m.detailsTitleHorizontalInset, 23.0)

        XCTAssertEqual(m.blockButtonHeight, 40.0)
        XCTAssertEqual(m.blockButtonSpacing, 6.0)
    }

    /// The quote scale actually shrinks, and lands on the screen-pixel grid rather than on
    /// arbitrary fractions. Values are asserted against `floorToScreenPixels` rather than hardcoded
    /// because the grid is 2x or 3x depending on the device the test runs on.
    func testQuoteScaleShrinksAndSnapsToScreenPixels() {
        let m = InstantPageMetrics(scale: InstantPageMetrics.quoteScale)
        let scale = InstantPageMetrics.quoteScale

        XCTAssertEqual(m.baseBlockSpacing, floorToScreenPixels(8.0 * scale))
        XCTAssertEqual(m.captionTopPad, floorToScreenPixels(9.0 * scale))
        XCTAssertEqual(m.codeBlockFontSize, floorToScreenPixels(15.0 * scale))
        XCTAssertEqual(m.quoteLineInset, floorToScreenPixels(9.0 * scale))

        XCTAssertLessThan(m.baseBlockSpacing, InstantPageMetrics.unscaled.baseBlockSpacing)
        XCTAssertLessThan(m.captionTopPad, InstantPageMetrics.unscaled.captionTopPad)
        XCTAssertLessThan(m.codeBlockFontSize, InstantPageMetrics.unscaled.codeBlockFontSize)
    }

    /// Idempotence is enforced at the call sites (assign, never multiply), but the arithmetic
    /// backing it belongs here: applying the quote scale twice is NOT the quote scale.
    func testQuoteScaleAppliedTwiceWouldDiffer() {
        let once = InstantPageMetrics(scale: InstantPageMetrics.quoteScale)
        let twice = InstantPageMetrics(scale: InstantPageMetrics.quoteScale * InstantPageMetrics.quoteScale)
        XCTAssertNotEqual(once.baseBlockSpacing, twice.baseBlockSpacing)
    }
}
```

`floorToScreenPixels` is `public` in `Display`, which the test lib depends on transitively through `InstantPageUI`; add `//submodules/Display:Display` to the test lib deps explicitly so the import is not incidental.

- [ ] **Step 3: Add the Bazel test targets**

Append to `submodules/InstantPageUI/BUILD`, and add the two `load` lines at the top of the file next to the existing `swift_library` load:

```python
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "InstantPageUITestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":InstantPageUI",
        "//submodules/Display:Display",
    ],
)

ios_test_runner(
    name = "InstantPageUITestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "InstantPageUITests",
    minimum_os_version = "13.0",
    runner = ":InstantPageUITestRunner",
    deps = [
        ":InstantPageUITestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
```

The runner **must** pin a real device/OS. The default runner picks an invalid device and the test process exits 15. `iPhone 17` / `26.5` matches `//submodules/TextFormat:TextFormatTests`, the only other app-side unit test.

Also confirm the `swift_library(name = "InstantPageUI")` `srcs` glob is `Sources/**/*.swift` — it is, so the new `Sources/InstantPageMetrics.swift` is picked up with no BUILD change, and `Tests/**` is outside it.

- [ ] **Step 4: Run the test**

```bash
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion \
 --cacheDir ~/telegram-bazel-cache test \
 --configurationPath build-system/appstore-configuration.json \
 --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
 --gitCodesigningType development --gitCodesigningUseCurrent \
 --target //submodules/InstantPageUI:InstantPageUITests
```

Expected: PASS, three tests. Do **not** run the default `Tests/AllTests` suite — it references a dangling `//submodules/TgVoipWebrtc:TgCallsTests` and fails to build.

If `testUnscaledMetricsMatchOriginalLiterals` fails, a literal was transcribed wrong — fix the *type*, not the test. The test is the specification.

- [ ] **Step 5: Commit**

```bash
git add submodules/InstantPageUI/Sources/InstantPageMetrics.swift \
        submodules/InstantPageUI/Tests/InstantPageMetricsTests.swift \
        submodules/InstantPageUI/BUILD
git commit -m "feat(instantpage): add InstantPageMetrics, the scalable-constant inventory

A pure value type naming every geometry constant tuned against the body font,
scaled once in its initializer. Nothing consumes it yet.

The point is reviewable coverage: a content-scale change fails by omission, and
one literal left raw renders 17pt geometry inside a 15pt quote with no build
error and no visual diff anyone would catch. Membership in this struct IS the
policy -- chrome, hairlines, media frames and minimum separations are excluded
by being absent rather than by a rule applied per call site.

Its counterpart invariant, that scale 1.0 reproduces the literals exactly, is
what keeps every page outside a quote untouched, and is now a unit test."
```

---

### Task 2: The context seam — quote text renders at the scaled size

This is the headline behaviour: the one-paragraph vs two-paragraph split disappears. Fonts scale; spacings still don't (Tasks 3–7).

**Files:**
- Modify: `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` — `LayoutContext` (line 671), `layoutInstantPageV2` (line 474), `layoutBlockQuote` (line 2732), `layoutQuoteText` (line 2856)

**Interfaces:**
- Consumes: `InstantPageMetrics.unscaled`, `InstantPageMetrics.quoteScale`, `InstantPageMetrics(scale:)` from Task 1.
- Produces: `context.metrics` (an `InstantPageMetrics`, read by Tasks 3–7); `context.theme` now a `var`; `context.quoteTheme` / `context.quoteMetrics`.

- [ ] **Step 1: Make the context carry the pair**

In `private struct LayoutContext` (line 671), change `let theme: InstantPageTheme` to `var theme` and add four members:

```swift
private struct LayoutContext {
    /// Mutable because quoted content lays out under a scaled theme — see `quoteTheme`.
    var theme: InstantPageTheme
    /// Geometry constants for the CURRENT content scale. Swapped alongside `theme`.
    var metrics: InstantPageMetrics
    /// The theme and metrics quoted content uses, computed ONCE for the page.
    ///
    /// Precomputed rather than derived on entry so that nesting is idempotent by construction: a
    /// quote inside a quote assigns the same values instead of compounding to 11.7pt at depth
    /// three. Deriving these from `context.theme` at each entry would compound, and would read as
    /// correct in a diff.
    let quoteTheme: InstantPageTheme
    let quoteMetrics: InstantPageMetrics
    ...
}
```

- [ ] **Step 2: Build the scaled theme once, at the page root**

In `layoutInstantPageV2` (line 474), immediately before the `var context = LayoutContext(` construction:

```swift
// Quoted content sits one step below body. `lineSpacingFactor: 1.0` because that field is already
// a FACTOR on the font size and would double-apply; `forceSerif: theme.serif` preserves the
// reader's serif setting rather than silently clearing it.
//
// NOTE: `withUpdatedFontStyles` reconstructs the theme field by field, and any field it omits
// silently reverts to an `init` default. Re-read it before trusting this call — the chat bubble's
// theme carries eight theme-derived colours that would revert without a compile error.
let quoteTheme = theme.withUpdatedFontStyles(
    sizeMultiplier: InstantPageMetrics.quoteScale,
    lineSpacingFactor: 1.0,
    forceSerif: theme.serif
)
```

and pass `theme: theme, metrics: .unscaled, quoteTheme: quoteTheme, quoteMetrics: InstantPageMetrics(scale: InstantPageMetrics.quoteScale)` in the `LayoutContext(...)` call.

- [ ] **Step 3: Swap at both quote entry points**

At the top of `layoutBlockQuote` (line 2732) — **before** the single-paragraph fast-path early return, so the fast path is covered too:

```swift
    let savedTheme = context.theme, savedMetrics = context.metrics
    context.theme = context.quoteTheme       // assign, never multiply — this is the idempotence
    context.metrics = context.quoteMetrics
    defer { context.theme = savedTheme; context.metrics = savedMetrics }
```

Add the identical four lines at the top of `layoutQuoteText` (line 2856). Both need it: `layoutQuoteText` is reached directly for `.pullQuote` (from `layoutBlock`, line ~896) and via the fast path from `layoutBlockQuote`. The double-application from the fast path is harmless precisely because the swap is an assignment.

- [ ] **Step 4: Delete the absolute font push**

In `layoutQuoteText`, remove `styleStack.push(.fontSize(15.0))` (line ~2879 after the insertions above; it sits just after `setupStyleStack(styleStack, theme: context.theme, category: .paragraph, link: false)` and before the `if isPull { styleStack.push(.italic) }`).

Under the swapped theme the `.paragraph` category *is* 15pt in the bubble, so this yields the same size there and the correct ratio in the reader. Leaving it in would pin pull quotes and single-paragraph quotes to an absolute size while multi-block quotes tracked the ratio — the same split, moved to other font sizes.

- [ ] **Step 5: Build**

Run the build command from Global Constraints. Expected: `Build completed successfully`.

Two likely failures: `LayoutContext` is constructed in exactly one place, so a missing argument is a hard error pointing at line 474; and `defer` capturing `context` while it is `inout` is legal, but reordering the `defer` above the assignments would restore the wrong values — keep the order above.

- [ ] **Step 6: Commit**

```bash
git add submodules/InstantPageUI/Sources/InstantPageV2Layout.swift
git commit -m "feat(instantpage): scale quoted content's theme, closing the 15-vs-17pt split

LayoutContext carries a theme+metrics pair and a precomputed quoteTheme /
quoteMetrics; both quote entry points assign them and restore via defer.

This fixes the originating bug directly: layoutQuoteText pushed an absolute
15pt over the theme's 17pt paragraph while layoutBlockQuote laid its children
out with the theme untouched, so a quote with one paragraph rendered at 15pt
and the same quote with a second paragraph rendered at 17pt. The push is
deleted -- under the swapped theme the paragraph category IS 15pt in a bubble,
and tracks the reader's font-size setting elsewhere, which an absolute size
cannot.

Putting the scale on the context rather than in the quote functions means every
block type a quote can contain is covered without knowing about quotes,
including formulas, whose math image bakes its size from context.theme.

Spacings still read raw literals; subsequent commits move them onto metrics."
```

---

### Task 3: Block rhythm — `spacingBetweenBlocks` takes metrics

**Files:**
- Modify: `submodules/InstantPageUI/Sources/InstantPageLayoutSpacings.swift` — `InstantPageBlockSpacing` (line 23), `spacingBetweenBlocks` (line 79)
- Modify: `submodules/InstantPageUI/Sources/InstantPageLayout.swift` — six call sites: lines 500, 817, 1001, 1009, 1144, 1153
- Modify: `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` — five call sites: lines 708, 747, 2777, 3131, 3240

**Interfaces:**
- Consumes: `context.metrics` (Task 2), `InstantPageMetrics.unscaled` (Task 1).
- Produces: `spacingBetweenBlocks(upper:lower:kind:metrics:)` and `InstantPageBlock.spacing(metrics:)` — both now require the metrics argument.

- [ ] **Step 1: Take metrics in the spacing model**

`InstantPageBlockSpacing`'s `verticalPadding` default and the per-case values move onto metrics. Change the struct's default and the `spacing` computed property into a method:

```swift
struct InstantPageBlockSpacing {
    var verticalPadding: CGFloat
    var flushAbove: Bool = false
    var flushBelow: Bool = false

    init(verticalPadding: CGFloat, flushAbove: Bool = false, flushBelow: Bool = false) {
        self.verticalPadding = verticalPadding
        self.flushAbove = flushAbove
        self.flushBelow = flushBelow
    }
}

extension InstantPageBlock {
    func spacing(metrics: InstantPageMetrics) -> InstantPageBlockSpacing {
        switch self {
        case .anchor:
            return InstantPageBlockSpacing(verticalPadding: 0.0, flushAbove: true, flushBelow: true)
        case .cover, .channelBanner:
            return InstantPageBlockSpacing(verticalPadding: metrics.blockVerticalPadding, flushAbove: true)
        case .relatedArticles:
            return InstantPageBlockSpacing(verticalPadding: metrics.blockVerticalPadding, flushBelow: true)
        case .heading:
            return InstantPageBlockSpacing(verticalPadding: metrics.headingVerticalPadding)
        case .divider:
            return InstantPageBlockSpacing(verticalPadding: metrics.dividerVerticalPadding)
        case let .image(_, caption, _, _, _), let .video(_, caption, _, _, _), let .document(_, caption), let .audio(_, caption), let .slideshow(_, caption), let .collage(_, caption), let .map(_, _, _, _, caption):
            if caption.credit != .empty && caption.credit != .plain("") {
                return InstantPageBlockSpacing(verticalPadding: metrics.blockVerticalPadding, flushAbove: true, flushBelow: false)
            } else {
                return InstantPageBlockSpacing(verticalPadding: metrics.blockVerticalPadding, flushAbove: true, flushBelow: true)
            }
        default:
            return InstantPageBlockSpacing(verticalPadding: metrics.blockVerticalPadding)
        }
    }
}
```

The `verticalPadding: CGFloat = 4.0` default is deliberately removed: with metrics in play, a defaulted padding is a literal that silently ignores the scale. Every construction site now states it.

- [ ] **Step 2: Thread metrics through the function**

Change the signature to `func spacingBetweenBlocks(upper: InstantPageBlock?, lower: InstantPageBlock?, kind: BlockSequenceKind, metrics: InstantPageMetrics) -> CGFloat`.

There are **four** `.spacing` reads, not two — the two in the both-present branch (lines 81–82) and one in each single-sided edge branch (lines 174, 183). All four become `.spacing(metrics: metrics)`.

Replace `instantPageBaseBlockSpacing` with `metrics.baseBlockSpacing` at its two use sites (the `.paragraph`→`.heading` arm and the final `return`).

Replace the `.details`-upper arm's literal: `return upperSpacing.verticalPadding + metrics.detailsAdjacentSpacing + lowerSpacing.verticalPadding`.

**Leave these literals exactly as they are** — they are minimum separations and optical nudges, not body-font-derived sizes: the `return 1.0` for adjacent raw media, the `return 1.0` for two paragraphs, the `max(1.0, … + 1.0)` arms, the `+ 2.0` credit adjustment, and the `+ 2.0` at both sequence edges.

The parameter is **required, not defaulted**. Defaulting it to `.unscaled` would let a new V2 call site silently get page-scale spacing inside a quote — the exact silent-failure mode this whole design was chosen to avoid.

`let instantPageBaseBlockSpacing: CGFloat = 8.0` stays in the file as the source literal that `InstantPageMetrics` scales; reference it from the metrics init instead of repeating `8.0` if you prefer — either is fine, but do not delete it.

- [ ] **Step 3: Update V1's six call sites**

At `InstantPageLayout.swift` lines 500, 817, 1001, 1009, 1144, 1153, add `, metrics: .unscaled` to each `spacingBetweenBlocks(...)` call. V1 has no content scale and must not change behaviour.

- [ ] **Step 4: Update V2's five call sites**

At `InstantPageV2Layout.swift` lines 708, 747 (`layoutBlockSequence`), 2777 (`layoutBlockQuote`), 3131 and 3240 (`layoutList`), add `, metrics: context.metrics`.

Line 2777 is the blockquote child spacing — inside a quote `context.metrics` is already the swapped value from Task 2, which is exactly the point.

- [ ] **Step 5: Build**

Run the build command. Expected: `Build completed successfully`. Every call site is a compile error until updated, which is the design working — that is why the parameter has no default.

- [ ] **Step 6: Commit**

```bash
git add submodules/InstantPageUI/Sources/InstantPageLayoutSpacings.swift \
        submodules/InstantPageUI/Sources/InstantPageLayout.swift \
        submodules/InstantPageUI/Sources/InstantPageV2Layout.swift
git commit -m "feat(instantpage): scale block rhythm with the content scale

spacingBetweenBlocks and InstantPageBlock.spacing take metrics. The parameter is
required rather than defaulted to .unscaled: a default would let a new V2 call
site silently get page-scale spacing inside a quote, which is the failure mode
this design exists to prevent, and it costs six mechanical edits in V1 -- which
only ever passes .unscaled and is otherwise untouched.

InstantPageBlockSpacing's verticalPadding loses its 4.0 default for the same
reason: with metrics in play a defaulted padding is a literal that ignores the
scale.

The hardcoded 1.0 returns and 2.0 adjustments stay put. They are minimum
separations and optical nudges rather than sizes derived from a font, and
floorToScreenPixels(1.0 * 15/17) is 0.67pt."
```

---

### Task 4: Caption, credit and quote insets

**Files:**
- Modify: `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` — `layoutCaptionAndCredit` (line 2070), `layoutTypedMediaWithCaption`, `layoutMediaWithCaption`, `layoutCollage`, `layoutBlockQuote` (line 2732), `layoutQuoteText` (line 2856)

**Interfaces:**
- Consumes: `context.metrics` (Task 2).
- Produces: no new API.

- [ ] **Step 1: Caption and credit pads**

In `layoutCaptionAndCredit`, replace the three literals: the caption branch's `totalHeight += 9.0` / `y += 9.0` become `metrics.captionTopPad`; in the credit branch the `captionIsEmpty` arm's `9.0` becomes `captionTopPad` and the else arm's `10.0` becomes `creditTopPad`. Read them from `context.metrics` at the top of the function into a local `let metrics = context.metrics` — `context` is `inout` and repeated member reads through it are noisy.

In `layoutTypedMediaWithCaption`, `layoutMediaWithCaption` and `layoutCollage`, replace the `isCover` extra padding literal `14.0` with `context.metrics.coverCaptionExtraPad`.

Do **not** touch the `offset:` arguments those three pass to `layoutCaptionAndCredit`. They pass the media's bottom edge unmodified and the 9pt pad is the whole gap — see the invariant already written in `layoutCaptionAndCredit`'s doc comment.

- [ ] **Step 2: Quote insets**

In `layoutBlockQuote`, replace `let verticalInset: CGFloat = 6.0` with `let verticalInset = context.metrics.quoteVerticalInset`, `let lineInset: CGFloat = 9.0` with `context.metrics.quoteLineInset`, and the caption branch's `contentHeight += 3.0` with `context.metrics.quoteAttributionGap`.

In `layoutQuoteText`, replace `let pullQuotePadding: CGFloat = 30.0` with `context.metrics.pullQuotePadding`; `let verticalInset: CGFloat = isPull ? 12.0 : 6.0` with `isPull ? context.metrics.pullQuoteVerticalInset : context.metrics.quoteVerticalInset`; `leadingInset` `isPull ? pullQuotePadding : 9.0` with `... : context.metrics.quoteLeadingInset`; `trailingInset` `isPull ? pullQuotePadding : 16.0` with `... : context.metrics.quoteTrailingInset`; and `contentHeight += 3.0` with `context.metrics.quoteAttributionGap`.

**Leave alone** in both: the accent bar width `3.0`, the corner radius `6.0`, `fillAlpha 0.10`, the quote-mark `markSize` `12.0 × 10.0` and `markInset` `6.0`, and the `instantPageV2BlockQuoteIcon` geometry. Chrome identity, excluded by decision.

Note that inside these two functions `context.metrics` is already the quote metrics (Task 2 swapped it at the top), so the quote's own insets scale too — which is intended: a 15pt quote should not carry 17pt-tuned padding.

- [ ] **Step 3: Build**

Run the build command. Expected: `Build completed successfully`.

- [ ] **Step 4: Commit**

```bash
git add submodules/InstantPageUI/Sources/InstantPageV2Layout.swift
git commit -m "feat(instantpage): scale caption, credit and quote insets

The quotes' own insets scale along with their contents, since a 15pt quote
carrying 17pt-tuned padding is the mismatch this change exists to remove. Bar
width, corner radius and the quote marks stay fixed -- they read as identity
rather than typography, and a 2.33pt bar is just thinner.

quoteAttributionGap also collapses a 3.0 that had been duplicated across the
two quote paths."
```

---

### Task 5: Code blocks, including the render-time language label

**Files:**
- Modify: `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` — `layoutCodeBlock` (line 2612), `InstantPageV2CodeBlockItem` (line 170)
- Modify: `submodules/InstantPageUI/Sources/InstantPageRenderer.swift` — `InstantPageV2CodeBlockView.update` (line ~2125)

**Interfaces:**
- Consumes: `context.metrics` (Task 2).
- Produces: `InstantPageV2CodeBlockItem.languageFontSize: CGFloat`, read by `InstantPageV2CodeBlockView.update`.

- [ ] **Step 1: Add the field to the item**

In `struct InstantPageV2CodeBlockItem` (line 170), add:

```swift
    /// Point size for the language label the VIEW builds at render time. It has to travel on the
    /// item because it is the only font in the V2 renderer not baked into an attributed string at
    /// layout time — so it is the only place the content scale could leak past the layout.
    let languageFontSize: CGFloat
```

The memberwise initializer is used at one site (`layoutCodeBlock`), so this is a compile error there and nowhere else.

- [ ] **Step 2: Scale the code block's own geometry**

In `layoutCodeBlock`, replace `let verticalInset: CGFloat = 6.0` with `context.metrics.codeBlockVerticalInset`, and both `let leadingInset: CGFloat = 9.0` / `let trailingInset: CGFloat = 9.0` with `context.metrics.codeBlockHorizontalInset`.

Replace `styleStack.push(.fontSize(15.0))` with `styleStack.push(.fontSize(context.metrics.codeBlockFontSize))`. This keeps the existing 15pt override outside a quote (the theme's `codeBlock` category is 14pt and the override is deliberate) while letting it scale inside one.

Pass `languageFontSize: context.metrics.codeBlockLanguageFontSize` in the `InstantPageV2CodeBlockItem(...)` construction.

**Leave alone:** the accent `barWidth: 3.0`, the corner radius, and `fillAlpha`.

- [ ] **Step 3: Read it in the view**

In `InstantPageV2CodeBlockView.update` (`InstantPageRenderer.swift:~2136`), change:

```swift
                .font: UIFont(name: "Menlo", size: 11.0) ?? Font.regular(11.0),
```

to:

```swift
                .font: UIFont(name: "Menlo", size: item.languageFontSize) ?? Font.regular(item.languageFontSize),
```

Leave the label's `8.0` / `2.0` frame offsets — chrome.

- [ ] **Step 4: Build**

Run the build command. Expected: `Build completed successfully`.

- [ ] **Step 5: Commit**

```bash
git add submodules/InstantPageUI/Sources/InstantPageV2Layout.swift \
        submodules/InstantPageUI/Sources/InstantPageRenderer.swift
git commit -m "feat(instantpage): scale code blocks, including the render-time language label

layoutCodeBlock's absolute .fontSize(15.0) override of the theme's 14pt
codeBlock category becomes a metric: still exactly 15pt outside a quote, and
scaled inside one instead of leaving code at full size while its surroundings
shrink.

The language label is the only font in the V2 renderer built at render time
rather than baked into an attributed string at layout time, so it is the only
place the content scale can leak past the layout. It now travels on the item."
```

---

### Task 6: List metrics

**Files:**
- Modify: `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` — `layoutList` (line 3006) and the marker-frame helper it calls (`instantPageV2ListMarkerFrame`, around line 3340)

**Interfaces:**
- Consumes: `context.metrics` (Task 2).
- Produces: no new API.

- [ ] **Step 1: Replace the list literals**

In `layoutList`:

In `layoutList`:

- line ~3034 `let checklistMarkerSize = CGSize(width: 18.0, height: 18.0)` → `let checklistMarkerSize = context.metrics.checklistMarkerSize`
- line ~3108 `let indexSpacing: CGFloat = 8.0` → `let indexSpacing = context.metrics.listIndexSpacing`
- line ~3095 `maxIndexWidth = max(maxIndexWidth, instantPageBulletMarkerDiameter)` → `context.metrics.bulletDiameter`
- line ~3116 `let contentGutter = indexSpacing + maxIndexWidth + instantPageListItemTextwardOffset` → `... + context.metrics.listItemTextwardOffset`

The marker-frame helper (the function ending at line ~3360 that takes `kind:maxIndexWidth:horizontalInset:checklistMarkerSize:lineMidY:rtl:boundingWidth:`) reads two globals directly. It already takes its other sizes as parameters, so follow that pattern — add two more:

```swift
    bulletDiameter: CGFloat,
    numberMarkerTextwardOffset: CGFloat,
```

and inside it replace `size = CGSize(width: instantPageBulletMarkerDiameter, height: instantPageBulletMarkerDiameter)` with `bulletDiameter` on both axes, and `textwardOffset = instantPageV2NumberMarkerTextwardOffset` with the new parameter. Pass `bulletDiameter: context.metrics.bulletDiameter, numberMarkerTextwardOffset: context.metrics.numberMarkerTextwardOffset` at both call sites in `layoutList` (lines ~3203 and ~3289).

**Leave alone, deliberately:**

- `instantPageBulletMarkerVerticalOffset` (1pt) and `instantPageBulletMarkerTextwardOffset` (2pt) — optical nudges, and the bullet's own `verticalOffset` is applied to a `floorToScreenPixels`'d centre where a 1.76pt value buys nothing.
- `instantPageV2NumberedListItemTextwardOffset` (1pt) — same.
- The number marker's `height: 20.0` box. It is a container the renderer vertically centres its (already-scaled) digits inside, not a body-font-tuned size; scaling it would move nothing visible. This is a decision, not an oversight — leave a one-line comment saying so, or the next sweep will "fix" it.

The globals in `InstantPageShapeItem.swift` are **not** modified — `InstantPageMetrics` holds scaled copies, and V1 keeps reading the raw globals.

- [ ] **Step 2: Build**

Run the build command. Expected: `Build completed successfully`.

Watch for `-warnings-as-errors` here: if replacing a use makes `instantPageBulletMarkerDiameter` unreferenced in this file that is fine (it is a module-level `let` used by V1), but an unused *local* will fail the build.

- [ ] **Step 3: Commit**

```bash
git add submodules/InstantPageUI/Sources/InstantPageV2Layout.swift
git commit -m "feat(instantpage): scale list marker column and gutters

The bullet diameter and textward offset are scaled COPIES of the
InstantPageShapeItem globals; the globals stay as they are because V1 reads
them and must not change. The 1pt optical nudges are left alone."
```

---

### Task 7: Tables, details and button rows

**Files:**
- Modify: `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` — `layoutTable` (line 1523), `layoutDetails` (line 1328)
- Modify: `submodules/InstantPageUI/Sources/InstantPageV2ButtonRowLayout.swift`

**Interfaces:**
- Consumes: `context.metrics` (Task 2).
- Produces: `instantPageV2LayoutButtonRow(...)` gains a `metrics: InstantPageMetrics` parameter.

- [ ] **Step 1: Tables**

`v2TableCellInsets` has **11** use sites and `v2TableMinCompressedColumnWidth` has **2**; find them with:

```bash
grep -n "v2TableCellInsets\|v2TableMinCompressedColumnWidth" submodules/InstantPageUI/Sources/InstantPageV2Layout.swift
```

Replace each with `context.metrics.tableCellInsets` / `context.metrics.tableMinCompressedColumnWidth`. Several sites are inside the `finalizeCell` closure and the column solver, which capture rather than take `context` — bind `let metrics = context.metrics` before the closure and capture that, since `context` is `inout` and cannot be captured by an escaping closure.

**Leave alone:** `v2TableBorderWidth` (`UIScreenPixel * 2.0` — a hairline) and `v2TableCornerRadius` (chrome).

Keep the module-level `let`s in place as the source literals.

- [ ] **Step 2: Details**

In `layoutDetails`, replace `- 32.0` (chevron reserve) with `- context.metrics.detailsChevronReserve`; `max(36.0, titleTextItem.frame.height + 15.0)` with `max(context.metrics.detailsMinTitleHeight, titleTextItem.frame.height + context.metrics.detailsTitleVerticalPad)`; and both `23.0` title-x terms with `context.metrics.detailsTitleHorizontalInset`.

- [ ] **Step 3: Button rows**

Add a `metrics: InstantPageMetrics` parameter to `instantPageV2LayoutButtonRow` and the two private helpers it delegates to (`instantPageV2LayoutJustifiedButtonRow`, `instantPageV2LayoutHuggingButtonRow`), replacing `instantPageBlockButtonHeight` with `metrics.blockButtonHeight` and `instantPageBlockButtonSpacing` with `metrics.blockButtonSpacing` inside them. Pass `metrics: context.metrics` from the `.buttonRow` arm of `layoutBlock`.

Leave `instantPageBlockButtonsPerRow` (a count, not a size).

- [ ] **Step 4: Build**

Run the build command. Expected: `Build completed successfully`.

- [ ] **Step 5: Commit**

```bash
git add submodules/InstantPageUI/Sources/InstantPageV2Layout.swift \
        submodules/InstantPageUI/Sources/InstantPageV2ButtonRowLayout.swift
git commit -m "feat(instantpage): scale table cells, details header and button rows

Table border width and corner radius stay fixed -- a hairline and chrome. The
per-row button count is a count, not a size."
```

---

### Task 8: Coverage sweep, docs, and handoff

**Files:**
- Modify: `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` (only if the sweep finds something)
- Modify: `docs/superpowers/specs/2026-08-07-instantpage-v2-quote-font-scale-design.md` (status line)

- [ ] **Step 1: Sweep for raw literals left behind**

```bash
cd /Users/isaac/build/telegram/telegram-ios
awk '/^(private )?func layout(Table|Details|QuoteText|BlockQuote|List|CaptionAndCredit|CodeBlock)\(/{f=1;name=$0} /^}/{f=0} f && /[^A-Za-z0-9_.][0-9]+\.[0-9]+/{print name": "FNR": "$0}' \
  submodules/InstantPageUI/Sources/InstantPageV2Layout.swift
```

For each hit, confirm it is one of: an excluded constant (chrome / hairline / media frame / minimum separation), a ratio or multiplier (`0.5`, `2.0` as a divisor, alphas), or a font-metric-relative value. Anything else is a missed metric — add it to `InstantPageMetrics`, extend `testUnscaledMetricsMatchOriginalLiterals` with its unscaled assertion, and use it.

`layoutTextItem` is deliberately absent from that pattern. Do not sweep it.

- [ ] **Step 2: Re-run the unit test**

```bash
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion \
 --cacheDir ~/telegram-bazel-cache test \
 --configurationPath build-system/appstore-configuration.json \
 --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
 --gitCodesigningType development --gitCodesigningUseCurrent \
 --target //submodules/InstantPageUI:InstantPageUITests
```

Expected: PASS.

- [ ] **Step 3: Full build**

Run the build command from Global Constraints. Expected: `Build completed successfully`.

- [ ] **Step 4: Mark the spec implemented**

In `docs/superpowers/specs/2026-08-07-instantpage-v2-quote-font-scale-design.md`, change the status line to `**Status:** implemented <date>; runtime verification pending.`

- [ ] **Step 5: Commit**

```bash
git add -A submodules/InstantPageUI docs/superpowers/specs
git commit -m "chore(instantpage): quote content scale coverage sweep

Confirms every remaining literal in the seven affected functions is an excluded
constant, a ratio, or font-metric-relative."
```

- [ ] **Step 6: Hand the visual matrix to the user**

Do **not** install to the simulator. Report the build result and ask the user to check:

- a one-paragraph quote and a two-paragraph quote in a bubble — **these must now match**, which is the originating bug;
- a quote nested three deep — every level at 15pt, not 13.2 and 11.7;
- a quote containing each of: list, code block, table, details, media with caption, formula;
- a pull quote;
- the full-page Instant View reader at the smallest and largest font-size settings, where ratio versus absolute is visible;
- **a page with no quote at all — it must look untouched.** This is the bit-identity invariant; the unit test covers the constants, but only the eye covers their use.

---

## Notes for the implementer

**Why the parameter threading looks repetitive.** `spacingBetweenBlocks`, the button-row helpers and several marker/cell helpers take `metrics` explicitly rather than reading a global or an ambient value. That is the design: a helper that reads a global cannot be inside a quote, and the compiler is the only thing that will tell you that you forgot.

**`context` is `inout` throughout.** Reading `context.metrics` repeatedly is legal but noisy; bind `let metrics = context.metrics` at the top of a function when you use it more than twice. Do not bind it *before* the quote swap in Tasks 2's two functions.

**If a build fails with "unused variable".** Every module here compiles with `-warnings-as-errors`. Replacing a literal's last use often orphans a local `let`; delete it rather than adding `_ = `.

**Do not rename or delete the module-level source literals** (`instantPageBaseBlockSpacing`, `v2TableCellInsets`, `instantPageBulletMarkerDiameter`, …). V1 reads several of them, and the ones it doesn't still document where the metric's value came from.
