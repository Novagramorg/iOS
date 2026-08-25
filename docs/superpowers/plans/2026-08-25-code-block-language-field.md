# Code-Block Language Field Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a code block's language authorable — an always-visible, editable text line at the top of the code band, in the RichTextEditor and (via the same editor view) the native chat composer.

**Architecture:** `CodeBlockBox` gains a second `BlockLayoutEngine` for the language, exposed as a second `LeafTextRegion` with a new `TextNodeRef.codeLanguage` case, and `DocumentTree` maps `.code` to a two-child container — the mirror image of how a pull quote carries its author, with the extra region leading and never content-gated. The box's `textStart`/`textLength`/`textRef` keep meaning the **code** region, which is what makes every existing code-block edit path stay correct.

**Tech Stack:** Swift 5.9, UIKit, TextKit 2 (`BlockLayout`) / TextKit 1 (`BlockLayoutTK1`) behind the `BlockLayoutEngine` seam, SwiftPM package built into the app by Bazel, XCTest.

**Spec:** `docs/superpowers/specs/2026-08-25-code-block-language-field-design.md` — read it before Task 1. The plan argues from it.

## Global Constraints

- **iOS floor is 13.0.** Every new type/extension in `RichTextEditorUIKit` carries `@available(iOS 13.0, *)`, matching its neighbours. No API newer than iOS 13 without an `#available` guard.
- **`RichTextEditorCore` is UIKit-free.** `Sources/RichTextEditorCore/` must not import UIKit; Core files that need platform types use Foundation only. (`RichTextEditorUIKit` files are wrapped in `#if canImport(UIKit)`.)
- **New UIKit test files must be wrapped in `#if canImport(UIKit)`** or the macOS `swift test` run fails to compile them.
- **`-warnings-as-errors` is on for the app build.** Unused variables, always-false `is` checks and always-failing `as?` casts fail the Bazel build even though `swift test` tolerates them.
- **Never lowercase the language in the editor.** Storage and display are as-typed; only the renderer lowercases (`instantPageV2CodeLanguageDisplayText`).
- **`leafRegions()` is document order.** `DocumentCanvasView+Navigation` indexes `allLeafRegions()` positionally. The language region is index 0 for a code box, the code region index 1.
- **`textStart` / `textLength` / `textRef` on `CodeBlockBox` keep meaning the CODE region.** This is load-bearing (Task 3).
- The renderer, `.Pre` serialization and the legacy chat input are **out of scope** and must not be touched.

### Commands used throughout

Run from the repo root unless stated otherwise.

Core tests (fast, macOS, no simulator):

```bash
cd submodules/TelegramUI/Components/RichTextEditor && swift test --filter CodeBlockPositionTests
```

UIKit tests (iOS simulator; K3 is a dedicated sim — the bare name `iPhone 17 Pro` is ambiguous across 7 sims and hangs the run):

```bash
cd submodules/TelegramUI/Components/RichTextEditor && \
  DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/CodeBlockBoxTests
```

Full app build (the only check that surfaces exhaustive-switch breaks from the new `TextNodeRef` case):

```bash
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion \
 --cacheDir ~/telegram-bazel-cache build \
 --configurationPath build-system/appstore-configuration.json \
 --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
 --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 --configuration=debug_sim_arm64 --continueOnError
```

---

## File Structure

**Core (`Sources/RichTextEditorCore/`)**
- `Model/CodeBlock.swift` — add `languageUTF16Count` (Task 1).
- `Position/TextNodeRef.swift` — add `case codeLanguage(BlockID)` (Task 1).
- `Position/DocumentTree.swift` — `.code` becomes a two-child container (Task 2).

**UIKit (`Sources/RichTextEditorUIKit/`)**
- `Canvas/CodeBlockBox.swift` — the language layout, geometry, spans, regions, drawing, read-back (Task 2).
- `Theme/RichTextEditorTheme.swift` — `codeLanguageText` / `codeLanguagePlaceholder` (Task 2).
- `Canvas/BlockBox.swift` — `RichTextEditorPlaceholders.codeLanguage` (Task 2; the struct lives in this file).
- `Canvas/DocumentCanvasView+Editing.swift` — `activeStack`'s primary-region guard (Task 3).
- `Canvas/DocumentCanvasView+State.swift` — `isCodeBlock` stays true in the language line (Task 3).
- `Canvas/DocumentCanvasView+UITextInput.swift` — typing attributes, insert routing, Return, Backspace (Tasks 4, 5).
- `Canvas/DocumentCanvasView+MarkedText.swift` — region-aware autocorrect/autocapitalize traits (Task 4).
- `Canvas/DocumentCanvasView.swift` — `blockID(ofRef:)` case (Task 1); trait reload on region crossing (Task 4).
- `Canvas/DocumentCanvasView+CharacterFormat.swift` — the format lock-out (Task 6).

**Hosts**
- `Components/Chat/ChatRichTextEditorComposer/Sources/RichTextEditorChatInputNode.swift` and
  `Components/RichTextAttachmentScreen/Sources/RichTextAttachmentScreen.swift` — pass the localized placeholder (Task 8).

**Tests**
- `Tests/RichTextEditorCoreTests/CodeBlockPositionTests.swift` (modified), `CodeBlockTests.swift` (modified).
- `Tests/RichTextEditorUIKitTests/CodeBlockBoxTests.swift` (modified), `CodeBlockEditingTests.swift` (modified),
  and a new `CodeLanguageRegionTests.swift` (Tasks 3–7).

---

### Task 1: Core model and the new text-node ref

**Files:**
- Modify: `submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorCore/Model/CodeBlock.swift`
- Modify: `submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorCore/Position/TextNodeRef.swift`
- Test: `submodules/TelegramUI/Components/RichTextEditor/Tests/RichTextEditorCoreTests/CodeBlockTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `CodeBlock.languageUTF16Count: Int` and `TextNodeRef.codeLanguage(BlockID)`. Task 2 uses both.

`TextNodeRef` has exactly **two** exhaustive switches, both in `RichTextEditorUIKit`, both inside this package (grep confirms no consumer outside it): `spellCheckableRef(_:)` in `DocumentCanvasView+SpellCheck.swift` and `blockID(ofRef:)` in `DocumentCanvasView.swift`. Adding the case breaks both immediately — `swift test` builds the UIKit target too — so this task fixes them. Nothing else changes behaviour here; the position-shape change lands as one coherent commit in Task 2.

- [ ] **Step 1: Write the failing test**

Append to `Tests/RichTextEditorCoreTests/CodeBlockTests.swift`, inside the existing `final class CodeBlockTests: XCTestCase { … }`:

```swift
    // The language line's UTF-16 length — the axis the position model counts in. Mirrors
    // `PullQuote.authorUTF16Count`. A nil AND an empty language are both zero-length: "no language"
    // and "an empty language line" are the same state, and `currentCode()` normalizes "" back to nil.
    func test_languageUTF16Count_isZeroForNilAndEmpty() {
        XCTAssertEqual(CodeBlock(id: BlockID("c"), language: nil).languageUTF16Count, 0)
        XCTAssertEqual(CodeBlock(id: BlockID("c"), language: "").languageUTF16Count, 0)
    }

    func test_languageUTF16Count_countsUTF16UnitsNotCharacters() {
        XCTAssertEqual(CodeBlock(id: BlockID("c"), language: "swift").languageUTF16Count, 5)
        // A non-BMP scalar is TWO UTF-16 units; the position axis counts units, so this must be 2.
        XCTAssertEqual(CodeBlock(id: BlockID("c"), language: "\u{1F600}").languageUTF16Count, 2)
    }

    func test_textNodeRef_codeLanguageIsDistinctFromCode() {
        XCTAssertNotEqual(TextNodeRef.codeLanguage(BlockID("c")), TextNodeRef.code(BlockID("c")))
        XCTAssertEqual(TextNodeRef.codeLanguage(BlockID("c")), TextNodeRef.codeLanguage(BlockID("c")))
    }
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd submodules/TelegramUI/Components/RichTextEditor && swift test --filter CodeBlockTests
```

Expected: FAIL to compile — `value of type 'CodeBlock' has no member 'languageUTF16Count'` and `type 'TextNodeRef' has no member 'codeLanguage'`.

- [ ] **Step 3: Add the derived property**

In `Sources/RichTextEditorCore/Model/CodeBlock.swift`, directly after the existing `utf16Count` property:

```swift
    /// Total UTF-16 length of the language line. Mirrors `PullQuote.authorUTF16Count` — the language is a
    /// second editable region on the block, so the position model needs its length. nil and "" are both 0.
    public var languageUTF16Count: Int { language?.utf16.count ?? 0 }
```

- [ ] **Step 4: Add the text-node ref case**

In `Sources/RichTextEditorCore/Position/TextNodeRef.swift`, after the `case code(BlockID)` line:

```swift
    /// The language line of a code block — a second, always-present editable region above the code text.
    case codeLanguage(BlockID)
```

- [ ] **Step 5: Fix the two exhaustive switches the new case breaks**

In `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+SpellCheck.swift`, add `.codeLanguage` to the **nil** arm of `spellCheckableRef(_:)`:

```swift
        case .code, .quoteAuthor, .codeLanguage: return nil
```

and extend that function's doc comment to name it:

```swift
    /// The block key for a CHECKABLE region, else nil. Prose is checked (`paragraph`/`caption`/`pullQuote`);
    /// code, code-LANGUAGE and quote-author regions are skipped (a language name is an identifier, not
    /// prose — iOS would underline `kotlin`; author is metadata).
```

In `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView.swift`, add the case to `blockID(ofRef:)`:

```swift
        case .paragraph(let id), .caption(let id), .code(let id),
             .pullQuote(let id), .quoteAuthor(let id), .detailsTitle(let id),
             .codeLanguage(let id): return id
```

Do **not** add a `default:` to either switch — their exhaustiveness is what surfaced these two sites.

- [ ] **Step 6: Run the tests to verify they pass**

```bash
cd submodules/TelegramUI/Components/RichTextEditor && swift test --filter CodeBlockTests
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add submodules/TelegramUI/Components/RichTextEditor/Sources submodules/TelegramUI/Components/RichTextEditor/Tests
git commit -m "richtext: add CodeBlock.languageUTF16Count and TextNodeRef.codeLanguage"
```

---

### Task 2: The language region — position shape, layout, drawing, read-back

**Files:**
- Modify: `Sources/RichTextEditorCore/Position/DocumentTree.swift` (the `case .code` arm)
- Modify: `Sources/RichTextEditorCore/Model/DocumentFragment.swift` (four `.code` text-start sites)
- Modify: `Sources/RichTextEditorUIKit/Canvas/CodeBlockBox.swift`
- Modify: `Sources/RichTextEditorUIKit/Theme/RichTextEditorTheme.swift`
- Modify: `Sources/RichTextEditorUIKit/Canvas/BlockBox.swift` (the `RichTextEditorPlaceholders` struct at the top)
- Test: `Tests/RichTextEditorCoreTests/CodeBlockPositionTests.swift`
- Test: `Tests/RichTextEditorUIKitTests/CodeBlockBoxTests.swift`

**Interfaces:**
- Consumes: `CodeBlock.languageUTF16Count`, `TextNodeRef.codeLanguage(_:)` (Task 1).
- Produces:
  - `CodeBlockBox.languageLayout: BlockLayoutEngine`, `.languageLength: Int`, `.languageOrigin: CGPoint`,
    `.languageLineExtent: CGFloat`, `static func languageAttributes(mapper:) -> [NSAttributedString.Key: Any]`,
    `static func languageAttributedString(for:mapper:) -> NSAttributedString`.
  - `CodeBlockBox.nodeSize == length + languageLength + 6`; `textStart == globalStart + languageLength + 3`;
    the language region's `globalStart == globalStart + 1`.
  - `RichTextEditorPlaceholders.codeLanguage: String` (default `"Language"`).
  - `RichTextEditorTheme.codeLanguageText`, `.codeLanguagePlaceholder`.

The DocumentTree change and the box change land together: the canvas computes spans from `nodeSize` while Core computes them from `DocumentTree`, and the two must agree at every commit.

- [ ] **Step 1: Write the failing Core test**

Replace the whole body of `Tests/RichTextEditorCoreTests/CodeBlockPositionTests.swift` with:

```swift
import XCTest
@testable import RichTextEditorCore

final class CodeBlockPositionTests: XCTestCase {
    // A code block is a CONTAINER of two paragraph children — the language line and the code text —
    // so it contributes container(2) + (lang + 2) + (code + 2) tokens. Interior "\n"s count, as before.
    func test_codeBlock_sizeIncludesLanguageAndInteriorNewlines() {
        let text = "a\nbb"                          // 4 UTF-16 units incl. the "\n"
        let doc = Document(blocks: [.code(CodeBlock(id: BlockID("c1"), language: "swift", runs: [TextRun(text: text)]))])
        XCTAssertEqual(DocumentTree.documentSize(doc), 4 + 5 + 6)
    }

    // The language region is NEVER content-gated (unlike a quote author): a language-less block still
    // carries a zero-length language region, so the code text's offset does not move when a language is
    // added or cleared.
    func test_codeBlock_languageRegionIsPresentEvenWhenAbsent() {
        let doc = Document(blocks: [.code(CodeBlock(id: BlockID("c1"), language: nil, runs: [TextRun(text: "ab")]))])
        XCTAssertEqual(DocumentTree.documentSize(doc), 2 + 0 + 6)
    }

    func test_codeBlock_languagePositionMapsToCodeLanguageRef() {
        let doc = Document(blocks: [.code(CodeBlock(id: BlockID("c1"), language: "swift", runs: [TextRun(text: "ab")]))])
        let root = DocumentTree.build(from: doc)
        // Position 2 = container open (0) + language paragraph open (1) + 1 char in.
        let tp = PositionResolver.textPosition(at: 2, in: root)
        XCTAssertEqual(tp?.ref, .codeLanguage(BlockID("c1")))
        XCTAssertEqual(tp?.offset, 1)
    }

    func test_codeBlock_textPositionMapsToCodeRef() {
        let doc = Document(blocks: [.code(CodeBlock(id: BlockID("c1"), language: "swift", runs: [TextRun(text: "ab")]))])
        let root = DocumentTree.build(from: doc)
        // Code text starts at container(1) + languageParagraph(1 + 5 + 1) + codeParagraph open(1) = 9.
        let tp = PositionResolver.textPosition(at: 9 + 1, in: root)
        XCTAssertEqual(tp?.ref, .code(BlockID("c1")))
        XCTAssertEqual(tp?.offset, 1)
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd submodules/TelegramUI/Components/RichTextEditor && swift test --filter CodeBlockPositionTests
```

Expected: FAIL — sizes come back as `len + 2` (e.g. `6` instead of `15`), and position 2 resolves to `.code`.

- [ ] **Step 3: Change the DocumentTree mapping**

In `Sources/RichTextEditorCore/Position/DocumentTree.swift`, replace the whole `case .code(let cb):` arm with:

```swift
        case .code(let cb):
            // A code block is a CONTAINER of two paragraph children: the always-present language line and
            // the code text. `.blockQuote` is reused purely as a TOKEN SHAPE (`PositionMapping` /
            // `PositionResolver` are generic over `children`/`nodeSize`/`isLeaf` and special-case only
            // `.text`), exactly as `.pullQuote` reuses it for [text, author]. Canvas-side
            // `isInsideBlockQuote(_:)` tests `box is BlockQuoteBox`, so this does NOT make code positions
            // read as "inside a block quote".
            // The language child is NEVER content-gated — unlike a quote author, which appears only once
            // its quote has content. The field is always visible, so it is always on the axis, and the
            // code text's offset therefore does not shift when a language is added or cleared.
            return .blockQuote(id: cb.id, children: [
                .paragraph(id: cb.id, children: [.text(length: cb.languageUTF16Count, ref: .codeLanguage(cb.id))]),
                .paragraph(id: cb.id, children: [.text(length: cb.utf16Count, ref: .code(cb.id))]),
            ])
```

- [ ] **Step 4: Run the Core test to verify it passes**

```bash
cd submodules/TelegramUI/Components/RichTextEditor && swift test --filter CodeBlockPositionTests
```

Expected: PASS. Then run the whole Core suite — the position change can ripple:

```bash
cd submodules/TelegramUI/Components/RichTextEditor && swift test
```

Expected: PASS. If `PositionMapTests` or `DocNodeTests` fail on a code-block case, update the expected numbers to the new shape (`len + lang + 6`); do not change the mapping.

- [ ] **Step 5: Fix the four Core sites that hard-code a code block's text start**

`DocumentFragment.swift` walks the position axis with `let textStart = cursor + 1`, which was right for a code block while it was a bare paragraph node. It is now a container, so its **code** text sits three tokens deeper: container open (`cursor`) → language paragraph open (`cursor+1`) → language text (`cursor+2`) → language close (`cursor+2+lang`) → code paragraph open (`cursor+3+lang`) → **code text at `cursor+4+lang`**.

This is the same correction the pull quote already carries (`cursor + 2`, with a comment at `extractFragment`'s `.pullQuote` arm explaining exactly this failure). Miss one of these and copy/paste through a code block silently slices the wrong UTF-16 range.

Add this helper to the same file, next to `blockPlainText`:

```swift
/// The global offset from a top-level block's own start to its editable CODE text. A code block is a
/// container of [languagePara, codePara] (see `DocumentTree.node(for:)`), so its code text sits three
/// tokens past where a bare paragraph's would: language open + language text + language close + code open.
func codeTextStartOffset(_ code: CodeBlock) -> Int { 4 + code.languageUTF16Count }
```

Then, in each of the four `.code` arms, replace the shared `textStart` with `cursor + codeTextStartOffset(c)`:

1. `topLevelTextLocus(globalCaret:)` (~line 213):

```swift
            case .code(let c):
                // The LANGUAGE line is deliberately not a locus here: a fragment paste into it falls
                // through to the caller's plain-text flatten, which is what the language line accepts.
                let codeStart = cursor + codeTextStartOffset(c)
                if caret >= codeStart && caret <= codeStart + c.utf16Count { return (i, caret - codeStart) }
```

2. `nearestTopLevelTextPosition(to:)` (~line 239):

```swift
            case .code(let c):
                let codeStart = cursor + codeTextStartOffset(c)
                if firstStart == nil { firstStart = codeStart }
                lastTextEnd = codeStart + c.utf16Count
```

3. `globalTextStart(ofBlockAt:)` (~line 262) — add a `.code` arm beside the existing `.pullQuote` one, and extend its doc comment to mention code:

```swift
        if case .code(let c) = blocks[index] {
            return cursor + codeTextStartOffset(c)
        }
```

4. `extractFragment(globalFrom:globalTo:carryingNonTextBlocks:)` (~line 431):

```swift
            case .code(let c):
                // Container now, like a pull quote: the code text starts past the language line, NOT at
                // the shared `textStart`. A partial copy carries the language, which is block metadata
                // rather than flat text — the same rule the pull quote applies to its author.
                let codeStart = cursor + codeTextStartOffset(c)
                let a = max(lo, codeStart), b = min(hi, codeStart + c.utf16Count)
                if a < b {
                    let r = sliceRuns(c.runs, fromUTF16: a - codeStart, toUTF16: b - codeStart)
                    out.append(.code(CodeBlock(id: .generate(), language: c.language, runs: r)))
                }
```

- [ ] **Step 6: Write and run a Core test for the fragment axis**

Append to `Tests/RichTextEditorCoreTests/CodeBlockPositionTests.swift`:

```swift
    // The fragment/paste axis must agree with the position axis: a code block's text locus is now three
    // tokens deeper than a paragraph's. Getting this wrong slices the wrong UTF-16 range on copy and
    // inserts at the wrong offset on paste — silently.
    func test_topLevelTextLocus_findsTheCodeTextPastTheLanguage() {
        let doc = Document(blocks: [.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "abc")]))])
        let codeStart = doc.globalTextStart(ofBlockAt: 0)
        XCTAssertEqual(codeStart, 9)                                     // 0 + 4 + 5
        XCTAssertEqual(doc.topLevelTextLocus(globalCaret: codeStart + 1)?.local, 1)
        XCTAssertEqual(doc.topLevelTextLocus(globalCaret: codeStart + 1)?.index, 0)
    }

    func test_extractFragment_slicesCodeTextFromTheRightBase() {
        let doc = Document(blocks: [.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "abc")]))])
        let codeStart = doc.globalTextStart(ofBlockAt: 0)
        let frag = doc.extractFragment(globalFrom: codeStart, globalTo: codeStart + 2)
        guard case let .code(c) = frag.blocks[0] else { return XCTFail("expected a code block") }
        XCTAssertEqual(c.text, "ab")
        XCTAssertEqual(c.language, "swift")
    }

    func test_insertingFragment_pastesIntoTheCodeTextNotTheLanguage() {
        let doc = Document(blocks: [.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "ac")]))])
        let codeStart = doc.globalTextStart(ofBlockAt: 0)
        let frag = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "b")]))])
        let result = doc.insertingFragment(frag, atGlobal: codeStart + 1)
        guard case let .code(c) = result!.document.blocks[0] else { return XCTFail("expected a code block") }
        XCTAssertEqual(c.text, "abc")
        XCTAssertEqual(c.language, "swift")
    }
```

Run:

```bash
cd submodules/TelegramUI/Components/RichTextEditor && swift test --filter CodeBlockPositionTests
```

Expected: PASS. Then re-run the whole Core suite; `DocumentFragmentTests` exercises these paths heavily and any code-block case there needs its expected offsets moved by `4 + languageLength` (from `1`).

- [ ] **Step 7: Add the theme colours**

In `Sources/RichTextEditorUIKit/Theme/RichTextEditorTheme.swift`, add two stored properties directly after `quoteAuthorPlaceholder`:

```swift
    /// A code block's language-line text colour. Defaults to `containerPlaceholder` — the colour the
    /// display-only language label already used — so making the line editable changes nothing visually.
    public var codeLanguageText: UIColor
    /// The "Language" placeholder colour on an EMPTY language line. Mirrors `quoteAuthorPlaceholder`.
    public var codeLanguagePlaceholder: UIColor
```

Add two parameters to `init`, directly after `quoteAuthorPlaceholder: UIColor? = nil,`:

```swift
        codeLanguageText: UIColor? = nil,
        codeLanguagePlaceholder: UIColor? = nil,
```

and two assignments directly after `self.quoteAuthorPlaceholder = quoteAuthorPlaceholder ?? placeholder`:

```swift
        self.codeLanguageText = codeLanguageText ?? containerPlaceholder
        self.codeLanguagePlaceholder = codeLanguagePlaceholder ?? placeholder
```

- [ ] **Step 8: Add the placeholder string field**

In `Sources/RichTextEditorUIKit/Canvas/BlockBox.swift`, in `struct RichTextEditorPlaceholders`: add the property after `codeBlock`:

```swift
    /// Shown on a code block's EMPTY language line (the line is always visible).
    public var codeLanguage: String
```

add the parameter to `init` after `codeBlock: String = "Type code here",`:

```swift
                codeLanguage: String = "Language",
```

add the assignment after `self.codeBlock = codeBlock`:

```swift
        self.codeLanguage = codeLanguage
```

and add `codeLanguage: "Language",` to the `static let default` initializer after its `codeBlock:` line.

- [ ] **Step 9: Write the failing box test**

Create `Tests/RichTextEditorUIKitTests/CodeLanguageRegionTests.swift`:

```swift
#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
@testable import RichTextEditorCore

/// The code block's language line as an editable leaf region: spans, geometry, regions, read-back.
@available(iOS 13.0, *)
final class CodeLanguageRegionTests: XCTestCase {
    private func makeMapper() -> AttributedStringMapper { AttributedStringMapper() }

    /// Same construction the existing `CodeBlockEditingTests` uses.
    func makeCanvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks(blocks, width: 320)
        return c
    }

    private func makeBox(language: String?, code: String, width: CGFloat = 300) -> CodeBlockBox {
        let box = CodeBlockBox(code: CodeBlock(id: BlockID("c"), language: language, runs: [TextRun(text: code)]),
                               mapper: makeMapper(), width: width)
        box.frame = CGRect(x: 0, y: 0, width: width, height: box.height)
        return box
    }

    // The box's token contribution must equal what DocumentTree computes for the same block, or the
    // canvas's span math and the model's position math disagree and every caret past this block is off.
    func test_nodeSize_matchesDocumentTree() {
        let block = CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])
        let box = CodeBlockBox(code: block, mapper: makeMapper(), width: 300)
        XCTAssertEqual(box.nodeSize, DocumentTree.documentSize(Document(blocks: [.code(block)])))
    }

    // Regions are in DOCUMENT order — navigation indexes allLeafRegions() positionally, so the language
    // line (which is drawn above the code) must be index 0.
    func test_leafRegions_areLanguageThenCodeInDocumentOrder() {
        let box = makeBox(language: "swift", code: "ab")
        box.nodeStart = 0
        let regions = box.leafRegions()
        XCTAssertEqual(regions.count, 2)
        XCTAssertEqual(regions[0].ref, .codeLanguage(BlockID("c")))
        XCTAssertEqual(regions[0].globalStart, box.nodeStart + 1)   // the container's first child's text
        XCTAssertEqual(regions[0].length, 5)
        XCTAssertEqual(regions[1].ref, .code(BlockID("c")))
        // language text (lang) + its close token + the code paragraph's open token → +3, mirroring
        // PullQuoteBox's author at `nodeStart + length + 3`.
        XCTAssertEqual(regions[1].globalStart, box.nodeStart + box.languageLength + 3)
        XCTAssertEqual(regions[1].globalStart, box.textStart)
    }

    // textStart/textLength/textRef stay the CODE region — Task 3's guard depends on it.
    func test_primaryRegionIsStillTheCode() {
        let box = makeBox(language: "swift", code: "ab")
        box.nodeStart = 0
        XCTAssertEqual(box.textRef, .code(BlockID("c")))
        XCTAssertEqual(box.textLength, 2)
    }

    // The line is ALWAYS shown: an empty language still reserves its line, so the box is taller than the
    // code alone. (Consequence: a language-less block is ~1 line taller in the editor than the rendered
    // message, which draws no language line. Accepted — see the design doc.)
    func test_emptyLanguage_stillReservesItsLine() {
        let withLanguage = makeBox(language: "swift", code: "ab")
        let without = makeBox(language: nil, code: "ab")
        XCTAssertEqual(without.height, withLanguage.height, accuracy: 0.5)
        XCTAssertGreaterThan(without.languageLineExtent, 0)
        XCTAssertEqual(without.textOrigin.y - without.frame.minY,
                       without.topInset + without.languageLineExtent, accuracy: 0.01)
    }

    // A tap on the language line resolves into the language region, so the "Language" placeholder is
    // directly tappable; a tap on the code resolves into the code.
    func test_tapRoutesToTheRegionUnderTheFinger() {
        let box = makeBox(language: "swift", code: "ab")
        box.nodeStart = 0
        let inLanguage = CGPoint(x: box.languageOrigin.x + 1, y: box.languageOrigin.y + 1)
        let inCode = CGPoint(x: box.textOrigin.x + 1, y: box.textOrigin.y + 1)
        XCTAssertLessThan(box.closestPosition(toCanvasPoint: inLanguage), box.textStart)
        XCTAssertGreaterThanOrEqual(box.closestPosition(toCanvasPoint: inCode), box.textStart)
    }

    // Read-back: as-typed casing survives, surrounding whitespace is trimmed, empty becomes nil.
    func test_currentCode_readsTheLanguageBackAsTyped() {
        let box = makeBox(language: "Swift", code: "ab")
        XCTAssertEqual(box.currentCode().language, "Swift")
    }

    func test_currentCode_trimsAndNilsAnEmptyLanguage() {
        let box = makeBox(language: "  ", code: "ab")
        XCTAssertNil(box.currentCode().language)
    }
}
#endif
```

- [ ] **Step 10: Run it to verify it fails**

```bash
cd submodules/TelegramUI/Components/RichTextEditor && \
  DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/CodeLanguageRegionTests
```

Expected: FAIL to compile — `CodeBlockBox` has no `languageOrigin` / `languageLineExtent`.

- [ ] **Step 11: Rebuild `CodeBlockBox` around the editable language layout**

In `Sources/RichTextEditorUIKit/Canvas/CodeBlockBox.swift`:

**(a)** Delete the stored `var language: String?` property and the `private(set) var languageLine: NSAttributedString?` property together with the `static func languageLine(for:mapper:)` helper. The language now lives in its own layout and is read back from it.

**(b)** Add the layout property beside `layout`:

```swift
    /// The language line's own TextKit layout — the editable "Language" region. ALWAYS present, even when
    /// the language is nil/empty (unlike a quote's author region, which appears only once its quote has
    /// content): the field is always visible, which is also what keeps the code text's offset stable.
    let languageLayout: BlockLayoutEngine
```

**(c)** Replace the two `languageLine` helpers with:

```swift
    /// Attributes the language line renders with: sans + bold at the BODY size — the same derivation the
    /// quote author uses — so it cannot be set to something the renderer disagrees with. NOT lowercased:
    /// the field shows what the author typed. The renderer lowercases at display
    /// (`instantPageV2CodeLanguageDisplayText`), so casing is a display concern there, not a model one.
    static func languageAttributes(mapper: AttributedStringMapper) -> [NSAttributedString.Key: Any] {
        let font = FontResolver.font(spec: mapper.styleSheet.metrics.body, bold: true, italic: false, family: nil)
        return [.font: font, .foregroundColor: mapper.theme.codeLanguageText]
    }

    static func languageAttributedString(for language: String?, mapper: AttributedStringMapper) -> NSAttributedString {
        NSAttributedString(string: language ?? "", attributes: languageAttributes(mapper: mapper))
    }
```

**(d)** In `init`, replace the `self.language = code.language` and `self.languageLine = …` lines with:

```swift
        self.languageLayout = makeBlockLayout(
            attributedString: CodeBlockBox.languageAttributedString(for: code.language, mapper: mapper),
            width: max(width - mapper.styleSheet.codeHorizontalInset * 2, 1))
```

**(e)** Replace `languageLineExtent` and add the language geometry beside it:

```swift
    var languageLength: Int { languageLayout.length }

    /// A single empty line's height in the language font. The line is always shown, so an empty language
    /// still reserves a line — that is where the "Language" placeholder is drawn.
    private var languageEmptyLineHeight: CGFloat {
        guard languageLayout.length == 0 else { return 0 }
        return (CodeBlockBox.languageAttributes(mapper: mapper)[.font] as? UIFont)?.lineHeight ?? 0
    }

    /// Height the language line occupies above the code, gap included. UNCONDITIONAL — a language-less
    /// code block still reserves it, and is therefore about one line taller in the editor than the message
    /// it renders to (which draws no language line at all). That is the cost of an always-visible field.
    var languageLineExtent: CGFloat {
        max(languageLayout.correctedBoundingHeight, languageEmptyLineHeight) + mapper.styleSheet.codeLanguageSpacing
    }

    /// Canvas origin of the language line: the band's top-left text position, above the code.
    var languageOrigin: CGPoint { CGPoint(x: frame.minX + horizontalInset, y: frame.minY + topInset) }
```

**(f)** Replace `currentCode()`:

```swift
    func currentCode() -> CodeBlock {
        // Trim, and normalize an all-whitespace/empty line back to nil — "" and nil are the same state
        // (`languageUTF16Count` treats them identically, and the renderer draws no line for either).
        let typed = languageLayout.attributedString.string.trimmingCharacters(in: .whitespacesAndNewlines)
        return CodeBlock(id: id, language: typed.isEmpty ? nil : typed,
                         runs: [TextRun(text: layout.attributedString.string)])
    }
```

**(g)** In the `CanvasBlock` conformance, replace the span members:

```swift
    /// container(2) + language paragraph(lang + 2) + code paragraph(code + 2). Matches `DocumentTree`'s
    /// `.code` mapping — `CodeLanguageRegionTests.test_nodeSize_matchesDocumentTree` is that check.
    var nodeSize: Int { length + languageLength + 6 }
    var textLayout: BlockLayoutEngine { layout }
    /// The PRIMARY region stays the CODE text — `activeStack` resolves boxes by it, which is what keeps
    /// every existing code-block edit path inert in the language line. See `DocumentCanvasView+Editing`.
    var textStart: Int { globalStart + languageLength + 3 }
```

**(h)** Replace `setWidth(_:)`, `leafRegions()` and `closestPosition(toCanvasPoint:)`:

```swift
    func setWidth(_ width: CGFloat) {
        let inner = max(width - horizontalInset * 2, 1)
        layout.setWidth(inner)
        languageLayout.setWidth(inner)
    }
    func closestPosition(toCanvasPoint point: CGPoint) -> Int {
        // A tap above the code text routes into the language region, so the always-visible "Language"
        // placeholder is directly tappable. Mirrors `PullQuoteBox`'s author branch, inverted — the
        // language line is LEADING, so the comparison is `<` against the code's origin, not `>=`.
        if point.y < textOrigin.y {
            return (globalStart + 1) + languageLayout.closestOffset(
                toPoint: CGPoint(x: point.x - languageOrigin.x, y: point.y - languageOrigin.y))
        }
        return textStart + layout.closestOffset(toPoint: CGPoint(x: point.x - textOrigin.x, y: point.y - textOrigin.y))
    }
    func leafRegions() -> [LeafTextRegion] {
        // DOCUMENT ORDER — language first. `DocumentCanvasView+Navigation` indexes `allLeafRegions()`
        // positionally, so a wrong order breaks arrow-key traversal. Note this makes `leafRegions().first`
        // the LANGUAGE region for a code box: any caller that means "the box's primary text" must use
        // `textStart`, not `.first` (see `activeStack`).
        [LeafTextRegion(layout: languageLayout, globalStart: globalStart + 1, length: languageLength,
                        ref: .codeLanguage(id), canvasOrigin: languageOrigin,
                        emptyLineLeadingIndent: 0, emptyLineHeight: languageEmptyLineHeight),
         LeafTextRegion(layout: layout, globalStart: textStart, length: length,
                        ref: .code(id), canvasOrigin: textOrigin,
                        emptyLineLeadingIndent: 0, emptyLineHeight: emptyLineHeight)]
    }
```

**(i)** In `draw(in:imageProvider:)`, replace the `if let line = languageLine { … }` block with:

```swift
        languageLayout.drawText(in: ctx, at: languageOrigin)
        if languageLength == 0, !placeholders.codeLanguage.isEmpty {
            var attrs = CodeBlockBox.languageAttributes(mapper: mapper)
            attrs[.foregroundColor] = mapper.theme.codeLanguagePlaceholder
            NSAttributedString(string: placeholders.codeLanguage, attributes: attrs).draw(at: languageOrigin)
        }
```

- [ ] **Step 12: Run the new tests, then the whole UIKit suite**

```bash
cd submodules/TelegramUI/Components/RichTextEditor && \
  DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/CodeLanguageRegionTests
```

Expected: PASS. Then:

```bash
cd submodules/TelegramUI/Components/RichTextEditor && \
  DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh
```

Expected: `CodeBlockBoxTests`, `CanvasBlockMeasureTests` and `CodeBlockEditingTests` may fail on heights and offsets that now include the language line. Update those expectations to the new geometry — a code box is taller by `languageLineExtent` and its text starts `languageLength + 3` past `nodeStart`. Do **not** weaken an assertion to make it pass; if a failure is not explained by those two shifts, stop and investigate.

- [ ] **Step 13: Commit**

```bash
git add submodules/TelegramUI/Components/RichTextEditor/Sources submodules/TelegramUI/Components/RichTextEditor/Tests
git commit -m "richtext: make a code block's language line an editable leaf region"
```

---

### Task 3: The primary-region guard (the silent-corruption fix)

**Files:**
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+Editing.swift:813-816` (`activeStack`'s leaf branch)
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+State.swift` (`isCodeBlock`)
- Test: `Tests/RichTextEditorUIKitTests/CodeLanguageRegionTests.swift`

**Interfaces:**
- Consumes: `CodeBlockBox.leafRegions()` order and `textStart` from Task 2.
- Produces: `activeStack(at:)` returns `nil` for any position in a `.codeLanguage` region. Tasks 4–6 rely on this: it is what keeps every legacy code-block branch inert in the language line.

Without this, `activeStack` resolves a caret in the language line to the code box with a **language-relative** `local`, and callers then apply it to `box.textLayout` — the *code* layout. `insertCodeBlockNewline()` would splice a newline into the code text at the wrong offset. It compiles and looks right.

- [ ] **Step 1: Write the failing test**

Append to `CodeLanguageRegionTests` (it already has the `makeCanvas(_:)` helper from Task 2):

```swift
    // THE SILENT-CORRUPTION GUARD. `activeStack` resolves a box by its PRIMARY region; a code box's
    // primary region is its CODE text. A caret in the LANGUAGE line must therefore resolve to nil, exactly
    // as a quote-author caret already does — otherwise every `box is CodeBlockBox` branch would run with a
    // language-relative offset against the code layout.
    func test_caretInLanguageRegion_doesNotResolveToAnActiveStack() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])),
        ])
        let languageStart = canvas.boxes[0].nodeStart + 1
        XCTAssertNil(canvas.activeStack(at: languageStart + 1))
        // …while a caret in the CODE text still resolves.
        XCTAssertNotNil(canvas.activeStack(at: canvas.boxes[0].textStart + 1))
    }

    // The consequence that matters: the code-block newline primitive cannot touch the code text while the
    // caret is in the language line.
    func test_insertCodeBlockNewline_isInertInTheLanguageRegion() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 2)
        canvas.insertCodeBlockNewline()
        guard case let .code(code) = canvas.currentBlocks()[0] else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.text, "let x = 1")
        XCTAssertEqual(code.language, "swift")
    }

    // A container box must NOT start matching at its own nodeStart: the naive `pos >= textStart,
    // pos <= textStart + textLength` form would, because containers report a degenerate
    // `textStart == nodeStart, textLength == 0`, and that position must keep falling through.
    func test_blockQuoteContainer_stillDoesNotResolveAtItsNodeStart() {
        let canvas = makeCanvas([
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                .paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "hi")])),
            ])),
        ]))
        XCTAssertNil(canvas.activeStack(at: canvas.boxes[0].nodeStart))
    }

    // The caret is still "in a code block" for menu purposes while it sits in the language line.
    func test_isCodeBlock_isTrueInTheLanguageRegion() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: nil, runs: [TextRun(text: "x")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 1)
        XCTAssertTrue(canvas.currentState().isCodeBlock)
    }
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd submodules/TelegramUI/Components/RichTextEditor && \
  DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/CodeLanguageRegionTests
```

Expected: FAIL — `activeStack` returns non-nil in the language region, `insertCodeBlockNewline` corrupts the code text, and `isCodeBlock` is false.

- [ ] **Step 3: Change `activeStack`'s leaf branch**

In `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+Editing.swift`, replace the leaf-box branch inside `descend` (currently `if let first = b.leafRegions().first, pos >= first.globalStart, …`):

```swift
                // A leaf text box (paragraph/code/pullQuote/media-caption): match by its PRIMARY text
                // region — the one starting at `textStart` — NOT by `leafRegions().first`. A code box's
                // FIRST region is its LANGUAGE line, and resolving a language position here would hand
                // every caller a language-relative `local` to apply to the box's CODE layout. Selecting
                // by `textStart` makes a language position return nil instead, exactly as a quote-author
                // position already does (see the fallback's note below), which leaves every existing
                // `box is CodeBlockBox` branch inert in the language line by construction.
                //
                // NB the naive `pos >= b.textStart, pos <= b.textStart + b.textLength` is NOT equivalent:
                // container boxes (block quote / details / table) report a degenerate
                // `textStart == nodeStart, textLength == 0`, so that form would newly match them at
                // exactly `nodeStart` and return a container with `local == 0`, where today that position
                // correctly falls through to the fallback (which refuses containers).
                if let primary = b.leafRegions().first(where: { $0.globalStart == b.textStart }),
                   pos >= primary.globalStart, pos <= primary.globalStart + primary.length {
                    return (stack, b, pos - primary.globalStart, i)
                }
```

- [ ] **Step 4: Keep `isCodeBlock` true in the language line**

In `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+State.swift`, in `currentState()`, replace the `isCodeBlock:` argument:

```swift
            isCodeBlock: isCaretInCodeBlock(),
```

and add this helper to the same extension:

```swift
    /// True when the caret is anywhere in a code block — its code text OR its language line. The language
    /// line resolves to no `activeStack` (by design, see `activeStack`), so the box test alone would report
    /// false there and the format menu would stop showing the block as code mid-edit.
    private func isCaretInCodeBlock() -> Bool {
        if activeStack(at: head)?.box is CodeBlockBox { return true }
        if let (region, _) = leafRegion(containingGlobal: head), case .codeLanguage = region.ref { return true }
        return false
    }
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd submodules/TelegramUI/Components/RichTextEditor && \
  DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh
```

Expected: PASS, including the full suite — the `activeStack` change touches every editing path, so a green full run is the point of this task.

- [ ] **Step 6: Commit**

```bash
git add submodules/TelegramUI/Components/RichTextEditor/Sources submodules/TelegramUI/Components/RichTextEditor/Tests
git commit -m "richtext: resolve boxes by their primary text region in activeStack"
```

---

### Task 4: Typing into the language line

**Files:**
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+UITextInput.swift` (`typingAttributeDict`, `legacyInsertText`)
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+MarkedText.swift` (traits)
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView.swift` (trait reload on region crossing)
- Test: `Tests/RichTextEditorUIKitTests/CodeLanguageRegionTests.swift`

**Interfaces:**
- Consumes: the Task 3 guard (`activeStack` is nil in the language region), `CodeBlockBox.languageAttributes(mapper:)`.
- Produces: typing in the language region routes through `applyLeafReplaceOutcome(globalFrom:globalTo:text:)`; `DocumentCanvasView.caretIsInCodeLanguageRegion: Bool`.

- [ ] **Step 1: Write the failing test**

Append to `CodeLanguageRegionTests`:

```swift
    func test_typingIntoAnEmptyLanguageLine_landsInTheLanguageNotTheCode() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: nil, runs: [TextRun(text: "x")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 1)
        canvas.insertText("s")
        canvas.insertText("h")
        guard case let .code(code) = canvas.currentBlocks()[0] else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.language, "sh")
        XCTAssertEqual(code.text, "x")
    }

    // The first character typed into an EMPTY language line must inherit the language line's own
    // attributes (bold, body size), not the 17pt body default — otherwise the read-back writes a
    // differently-styled string back into the model.
    func test_firstCharacterInAnEmptyLanguageLine_usesLanguageAttributes() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: nil, runs: [TextRun(text: "x")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 1)
        canvas.insertText("s")
        let box = canvas.boxes[0] as! CodeBlockBox
        let typed = box.languageLayout.attributedString.attributes(at: 0, effectiveRange: nil)
        let expected = CodeBlockBox.languageAttributes(mapper: box.mapper)
        XCTAssertEqual(typed[.font] as? UIFont, expected[.font] as? UIFont)
    }

    // iOS would capitalize "swift" to "Swift" and autocorrect language names into English words.
    // A multi-line paste into the language line arrives flattened; interior newlines must not survive
    // into the model (`currentCode()` only trims the edges).
    func test_pastingMultipleLinesIntoTheLanguageKeepsItOneLine() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: nil, runs: [TextRun(text: "x")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 1)
        canvas.insertText("obj\nc")
        guard case let .code(code) = canvas.boxes[0].currentBlock() else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.language, "obj c")
        XCTAssertEqual(code.text, "x")
    }

    func test_languageRegionReportsNoAutocorrectTraits() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: nil, runs: [TextRun(text: "x")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 1)
        XCTAssertEqual(canvas.autocorrectionType, .no)
        XCTAssertEqual(canvas.autocapitalizationType, .none)
        XCTAssertEqual(canvas.spellCheckingType, .no)
        // …and the ordinary code text is unaffected.
        canvas.setCaret(global: canvas.boxes[0].textStart)
        XCTAssertEqual(canvas.autocorrectionType, .yes)
    }
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd submodules/TelegramUI/Components/RichTextEditor && \
  DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/CodeLanguageRegionTests
```

Expected: FAIL — the typed characters go nowhere (the insert falls through to `applyReplaceOutcome`, which returns `.unchanged` because `activeStack` is nil), and the traits are `.yes` / `.sentences`.

- [ ] **Step 3: Add the empty-region typing attributes**

In `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+UITextInput.swift`, in `typingAttributeDict(region:atLocal:)`, inside the `if storage.length == 0 {` block, directly after the existing `.code` branch:

```swift
            // An empty LANGUAGE line types the language attributes (bold, body size) — without this the
            // first character lands 17pt body-styled and read-back writes that string into the model.
            if case .codeLanguage = region.ref {
                return CodeBlockBox.languageAttributes(mapper: self.mapper)
            }
```

- [ ] **Step 4: Route the insert through the region-aware path**

In the same file, in `legacyInsertText(_:)`, directly after the existing quote-author branch (`if let (region, _) = leafRegion(containingGlobal: head), case .quoteAuthor = region.ref { … }`), add:

```swift
        // A collapsed caret in a code block's LANGUAGE line: like the quote author, it is a second leaf
        // region outside the box's primary `textStart`/`textLength` extent, so `activeStack` resolves nil
        // and `applyReplaceOutcome` would drop the keystroke. Route it through the region-aware path.
        // Newlines are stripped: a `.Pre` language is a single-line string, and a multi-line paste
        // (which reaches this path flattened — `insertingFragment` refuses a language locus, so the
        // clipboard falls back to plain text) would otherwise put interior "\n"s in the model, where
        // `currentCode()`'s edge-trim cannot reach them.
        if let (region, _) = leafRegion(containingGlobal: head), case .codeLanguage = region.ref {
            let flat = text.replacingOccurrences(of: "\n", with: " ")
            editing(coalescing: .typing) { applyLeafReplaceOutcome(globalFrom: selFrom, globalTo: selTo, text: flat) }
            return
        }
```

Place it **after** the `if text == "\n"` dispatch is entered only for non-newline text — i.e. keep it below the `\n` block, alongside the author branch, so Task 5's Return handling takes precedence.

- [ ] **Step 5: Make the traits region-aware**

In `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView.swift`, add to the main class extension (next to the other caret helpers):

```swift
    /// True when the caret sits in a code block's language line. Read by the text-input traits: a language
    /// name is not prose, so autocorrect / autocapitalization / spell check are all off there (iOS would
    /// otherwise turn "swift" into "Swift" on the first space).
    var caretIsInCodeLanguageRegion: Bool {
        if let (region, _) = leafRegion(containingGlobal: head), case .codeLanguage = region.ref { return true }
        return false
    }
```

In `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+MarkedText.swift`, replace the traits extension body:

```swift
    var autocorrectionType: UITextAutocorrectionType {
        get { caretIsInCodeLanguageRegion ? .no : .yes } set { }
    }
    var autocapitalizationType: UITextAutocapitalizationType {
        // `.sentences` is UIKit's default for an unimplemented trait, so this changes nothing outside the
        // language line.
        get { caretIsInCodeLanguageRegion ? .none : .sentences } set { }
    }
    var spellCheckingType: UITextSpellCheckingType {
        get { caretIsInCodeLanguageRegion ? .no : (isSpellCheckingEnabled ? .yes : .no) } set { }
    }
```

- [ ] **Step 6: Make the keyboard re-read the traits when the caret crosses the boundary**

UIKit caches `UITextInputTraits` — it re-reads them on `reloadInputViews()`, which the canvas already calls when `isSpellCheckingEnabled` changes ("let the keyboard re-read the trait"). In `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView.swift`, add a stored property beside the other caret state:

```swift
    /// Last known value of `caretIsInCodeLanguageRegion`, so a crossing can be detected and the keyboard
    /// told to re-read its traits. UIKit caches `UITextInputTraits`; without this the keyboard keeps
    /// autocapitalizing after the caret moves into the language line.
    private var lastCaretWasInCodeLanguageRegion = false
```

and call this from wherever the canvas already reacts to a selection change (the same place `onSelectionChange?()` is invoked — search for `onSelectionChange?()` and add the call directly after it):

```swift
        refreshCodeLanguageInputTraitsIfNeeded()
```

with:

```swift
    /// Reload the keyboard's cached traits when the caret enters or leaves a code block's language line.
    func refreshCodeLanguageInputTraitsIfNeeded() {
        let now = caretIsInCodeLanguageRegion
        guard now != lastCaretWasInCodeLanguageRegion else { return }
        lastCaretWasInCodeLanguageRegion = now
        reloadInputViews()
    }
```

- [ ] **Step 7: Run the tests to verify they pass**

```bash
cd submodules/TelegramUI/Components/RichTextEditor && \
  DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh
```

Expected: PASS (full suite).

- [ ] **Step 8: Commit**

```bash
git add submodules/TelegramUI/Components/RichTextEditor/Sources submodules/TelegramUI/Components/RichTextEditor/Tests
git commit -m "richtext: type into a code block's language line"
```

---

### Task 5: Return and Backspace at the language line's edges

**Files:**
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+UITextInput.swift` (`legacyInsertText`'s `\n` dispatch, `legacyDeleteBackward`)
- Test: `Tests/RichTextEditorUIKitTests/CodeLanguageRegionTests.swift`

**Interfaces:**
- Consumes: Tasks 3 and 4.
- Produces: no new API — behaviour only.

**Spec deviation to record:** the design lists a forward-delete rule. There is no forward-delete primitive in this editor (`DocumentCanvasView+Editing.swift:1764`: "No forward-delete primitive exists; UIKit never sends it to this canvas today"), so that row is vacuous and **no code is written for it**. Do not invent a path.

- [ ] **Step 1: Write the failing test**

Append to `CodeLanguageRegionTests`:

```swift
    // Return in the language line moves to the code text. A `.Pre` language has no second line, so it
    // must not insert a newline and must not split the block (this is where it diverges from the quote
    // author, which splits — the author is trailing, the language is leading).
    func test_returnInTheLanguageLineMovesToTheCodeStart() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 3)     // mid-"swift"
        canvas.insertText("\n")
        XCTAssertEqual(canvas.head, canvas.boxes[0].textStart)
        guard case let .code(code) = canvas.currentBlocks()[0] else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.language, "swift")
        XCTAssertEqual(code.text, "let x = 1")
        XCTAssertEqual(canvas.currentBlocks().count, 1)
    }

    // Backspace at the START of the language line steps OUT of the block. It must never merge the
    // language into the previous block and never delete a block that still has content.
    func test_backspaceAtLanguageStartStepsOutWithoutDeleting() {
        let canvas = makeCanvas([
            .paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "before")])),
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])),
        ])
        canvas.setCaret(global: canvas.boxes[1].nodeStart + 1)
        canvas.deleteBackward()
        XCTAssertEqual(canvas.currentBlocks().count, 2)
        guard case let .code(code) = canvas.currentBlocks()[1] else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.language, "swift")
        XCTAssertEqual(canvas.head, canvas.boxes[0].textStart + canvas.boxes[0].textLength)
    }

    // A wholly-empty code block (no language, no code) is still un-made by Backspace at its start —
    // today's empty-code rule, relocated to the block's new FIRST position.
    func test_backspaceAtLanguageStartOfAWhollyEmptyBlockUnmakesIt() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: nil, runs: [])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 1)
        canvas.deleteBackward()
        guard case .paragraph = canvas.currentBlocks()[0] else {
            return XCTFail("a wholly-empty code block should un-make to a body paragraph")
        }
    }

    // A code block that is the document's FIRST block has nowhere to step out to — a no-op, not a delete.
    func test_backspaceAtLanguageStartOfALeadingBlockIsANoOp() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "x")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 1)
        canvas.deleteBackward()
        guard case let .code(code) = canvas.currentBlocks()[0] else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.language, "swift")
        XCTAssertEqual(code.text, "x")
    }

    // Backspace with text before the caret deletes inside the language line, not in the code.
    func test_backspaceInsideTheLanguageDeletesThere() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].nodeStart + 1 + 5)   // end of "swift"
        canvas.deleteBackward()
        guard case let .code(code) = canvas.currentBlocks()[0] else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.language, "swif")
        XCTAssertEqual(code.text, "let x = 1")
    }
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd submodules/TelegramUI/Components/RichTextEditor && \
  DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/CodeLanguageRegionTests
```

Expected: FAIL on all five.

- [ ] **Step 3: Handle Return**

In `legacyInsertText(_:)`, inside the `if text == "\n" {` block, as the **first** branch (above the quote-author split branch):

```swift
            // Return in a code block's LANGUAGE line moves the caret to the start of the code text. It
            // inserts nothing and splits nothing: a `.Pre` language has no second line. (The quote author
            // splits instead, because it is a TRAILING region — the tail becomes a paragraph after the
            // quote. A leading region has no such tail.)
            if selFrom == selTo, let (region, _) = leafRegion(containingGlobal: head),
               case let .codeLanguage(id) = region.ref,
               let codeBox = boxes.compactMap({ $0 as? CodeBlockBox }).first(where: { $0.id == id }) {
                setCaret(global: codeBox.textStart)
                return
            }
```

- [ ] **Step 4: Handle Backspace**

In `legacyDeleteBackward()`, directly after the existing quote-author `local == 0` relocation branch, add:

```swift
        // Backspace with a collapsed caret at the START of a code block's LANGUAGE line. The language is
        // the block's FIRST position, so there is nothing inside the block to merge into:
        //   • a WHOLLY empty block (no language, no code) is un-made to a body paragraph — today's
        //     empty-code rule, relocated to the block's new first position;
        //   • otherwise the caret steps OUT to the previous block's end, deleting nothing. When the code
        //     block is the document's first block there is nowhere to step, so it is a no-op.
        // Never merges the language into the previous block; never deletes a block that has content.
        if selFrom == selTo, let (region, local) = leafRegion(containingGlobal: head),
           case let .codeLanguage(id) = region.ref, local == 0,
           let active = activeStackContainingCodeBox(id: id) {
            if region.length == 0, active.box.textLength == 0 {
                editing {
                    let body = BlockBox(paragraph: ParagraphBlock(id: active.box.id, style: .body, runs: []),
                                        mapper: mapper, width: effectiveWidth)
                    var newBoxes = active.stack.boxes
                    newBoxes.replaceSubrange(active.index...active.index, with: [body])
                    active.stack.boxes = newBoxes
                    recomputeSpans()
                    return .caret(at: body.textStart)
                }
                return
            }
            let prev = prevTextPosition(before: region.globalStart)
            if prev != head { setCaret(global: prev) }
            return
        }
        // Backspace INSIDE a code block's language line (text before the caret): delete that grapheme in
        // the language region. `activeStack` resolves nil there by design, so the generic paths below
        // would mis-route it. Mirrors the block-quote author/child branch.
        if selFrom == selTo, let (region, local) = leafRegion(containingGlobal: head),
           case .codeLanguage = region.ref, local > 0 {
            let n = graphemeClusterLengthBeforeCaret(global: head)
            editing(coalescing: .deleting) { applyLeafReplaceOutcome(globalFrom: head - n, globalTo: head, text: "") }
            return
        }
```

Add the lookup helper to `DocumentCanvasView+Editing.swift`, beside `activeStack(at:)`:

```swift
    /// The stack, box and index of the `CodeBlockBox` with `id`, searched recursively (a code block can sit
    /// inside a block quote, a detail block, or a table cell). Needed because a caret in a code block's
    /// LANGUAGE line resolves to no `activeStack` — by design — so a language-line branch cannot get at its
    /// own box the usual way.
    func activeStackContainingCodeBox(id: BlockID) -> (stack: BlockStack, box: CodeBlockBox, index: Int)? {
        func search(_ stack: BlockStack) -> (stack: BlockStack, box: CodeBlockBox, index: Int)? {
            for (i, b) in stack.boxes.enumerated() {
                if let c = b as? CodeBlockBox, c.id == id { return (stack, c, i) }
                if let bq = b as? BlockQuoteBox, let hit = search(bq.children) { return hit }
                if let d = b as? DetailsBox, let hit = search(d.children) { return hit }
                if let t = b as? TableBlockBox {
                    for cell in t.cells.flatMap({ $0 }) { if let hit = search(cell) { return hit } }
                }
            }
            return nil
        }
        return search(root)
    }
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd submodules/TelegramUI/Components/RichTextEditor && \
  DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh
```

Expected: PASS (full suite).

- [ ] **Step 6: Commit**

```bash
git add submodules/TelegramUI/Components/RichTextEditor/Sources submodules/TelegramUI/Components/RichTextEditor/Tests
git commit -m "richtext: Return and Backspace semantics for the code language line"
```

---

### Task 6: Lock character formatting out of the language line

**Files:**
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+CharacterFormat.swift`
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+Emoji.swift`
- Test: `Tests/RichTextEditorUIKitTests/CodeLanguageRegionTests.swift`

**Interfaces:**
- Consumes: Task 3.
- Produces: `DocumentCanvasView.selectionIsEntirelyInCodeLanguageRegion() -> Bool`.

A `.Pre` language is a plain string on the wire. Bold/italic/underline/strikethrough/spoiler/inline-code/link/emoji applied there would either be dropped on read-back (dirtying the model with an inert edit) or, worse, survive in the layout and change what `currentCode()` reads back.

- [ ] **Step 1: Write the failing test**

Append to `CodeLanguageRegionTests`:

```swift
    func test_characterFormatsAreInertInTheLanguageLine() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "x")])),
        ])
        let box = canvas.boxes[0] as! CodeBlockBox
        canvas.setSelectionForTesting(anchor: box.nodeStart + 1, head: box.nodeStart + 1 + 5)   // all of "swift"
        let before = box.languageLayout.attributedString
        canvas.toggleBold()
        canvas.toggleItalic()
        canvas.toggleUnderline()
        canvas.toggleStrikethrough()
        canvas.toggleSpoiler()
        canvas.toggleInlineCode()
        XCTAssertEqual(box.languageLayout.attributedString, before)
        guard case let .code(code) = canvas.currentBlocks()[0] else { return XCTFail("expected a code block") }
        XCTAssertEqual(code.language, "swift")
    }

    func test_emojiInsertionIsInertInTheLanguageLine() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "x")])),
        ])
        let box = canvas.boxes[0] as! CodeBlockBox
        canvas.setCaret(global: box.nodeStart + 1 + 5)
        canvas.insertEmoji(id: "1", altText: "🙂")
        XCTAssertEqual(box.currentCode().language, "swift")
    }
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd submodules/TelegramUI/Components/RichTextEditor && \
  DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/CodeLanguageRegionTests
```

Expected: FAIL — the toggles mutate the language layout.

- [ ] **Step 3: Add the predicate**

In `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+CharacterFormat.swift`, beside `selectionIsEntirelyInAuthorRegion()`:

```swift
    /// True when every character-format target lies in a `.codeLanguage` region. A code block's language is
    /// a PLAIN string on the wire (`.Pre` carries no nested entities), so every inline format there is
    /// either dropped on read-back — an inert edit that still dirties the model — or survives in the layout
    /// and corrupts what `currentCode()` reads back. Mirrors `selectionIsEntirelyInAuthorRegion`.
    func selectionIsEntirelyInCodeLanguageRegion() -> Bool {
        let targets = characterFormatTargets()
        guard !targets.isEmpty else {
            if let (region, _) = leafRegion(containingGlobal: head), case .codeLanguage = region.ref { return true }
            return false
        }
        let regions = allLeafRegions()
        return targets.allSatisfy { target in
            guard let region = regions.first(where: { $0.layout === target.layout }) else { return false }
            if case .codeLanguage = region.ref { return true }
            return false
        }
    }
```

- [ ] **Step 4: Gate every character-format entry point**

In the same file, add this as the first line of the body of each of `toggleBold()`, `toggleItalic()`, `toggleStrikethrough()`, `toggleUnderline()`, `toggleSpoiler()` and `toggleInlineCode()`:

```swift
        if selectionIsEntirelyInCodeLanguageRegion() { return }   // a language is a plain string on the wire
```

In `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+Emoji.swift`, add the same line as the first line of `insertEmoji(id:altText:)`.

Then check the link path: open `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+Links.swift`, find the function that applies a link to the selection, and add the same guard line as its first statement.

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd submodules/TelegramUI/Components/RichTextEditor && \
  DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh
```

Expected: PASS (full suite).

- [ ] **Step 6: Commit**

```bash
git add submodules/TelegramUI/Components/RichTextEditor/Sources submodules/TelegramUI/Components/RichTextEditor/Tests
git commit -m "richtext: lock inline formatting out of the code language line"
```

---

### Task 7: Pin the navigation, coverage and spell-check decisions with tests

**Files:**
- Test: `Tests/RichTextEditorUIKitTests/CodeLanguageRegionTests.swift`
- Possibly modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+ComposerSelection.swift:76-77`

**Interfaces:**
- Consumes: Tasks 2–6. Produces: nothing new.

Three spec decisions are expected to hold **without code changes**, because of how the surrounding code is written. This task proves each one, and only then changes anything. If a test passes on the first run, that is the deliverable — record it in the commit message.

- [ ] **Step 1: Write the characterization tests**

Append to `CodeLanguageRegionTests`:

```swift
    // Unlike an empty quote author (which `isEmptyAuthorRegion` makes arrow-unreachable), an EMPTY language
    // line stays navigable: it is always present and always visible, so skipping it would leave it
    // reachable only by tapping. Expected to pass unchanged — `isEmptyAuthorRegion` matches only
    // `.quoteAuthor`.
    func test_arrowKeysEnterAnEmptyLanguageLine() {
        let canvas = makeCanvas([
            .paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "a")])),
            .code(CodeBlock(id: BlockID("c"), language: nil, runs: [TextRun(text: "x")])),
        ])
        let codeBox = canvas.boxes[1]
        // Stepping right from the end of the paragraph lands in the (empty) language line, not the code.
        let next = canvas.nextTextPosition(after: canvas.boxes[0].textStart + canvas.boxes[0].textLength)
        XCTAssertEqual(next, codeBox.nodeStart + 1)
        XCTAssertLessThan(next, codeBox.textStart)
    }

    // Select-All then type must replace the WHOLE code block, language included — not leave an orphan
    // language line behind. The language is LEADING, and `coverableContentStart` is the box's `nodeStart`,
    // so the leading edge already covers it. Expected to pass unchanged.
    func test_selectAllReplacesTheWholeBlockIncludingItsLanguage() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])),
        ])
        canvas.setSelectionForTesting(anchor: 0, head: canvas.documentSize)
        canvas.insertText("z")
        XCTAssertEqual(canvas.currentBlocks().count, 1)
        guard case let .paragraph(p) = canvas.currentBlocks()[0] else {
            return XCTFail("select-all + type should leave one paragraph")
        }
        XCTAssertEqual(p.text, "z")
    }

    // Toggling Code OFF drops the language: it is block metadata with no paragraph to live on. The
    // existing `makeCodeBlock` toggle-off path rebuilds paragraphs from `currentCode().text` alone, so
    // this should pass unchanged — the test exists to keep it that way.
    func test_toggleCodeOffDropsTheLanguage() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "let x = 1")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].textStart)
        canvas.makeCodeBlock()
        for block in canvas.currentBlocks() {
            if case .code = block { return XCTFail("the code block should have become paragraphs") }
        }
    }

    // Toggling Code ON leaves the caret in the CODE text, not in the new (empty) language line — you
    // asked for a code block to type code in. `makeCodeBlock` parks the caret at
    // `codeBox.textStart + codeBox.textLength`, and `textStart` is the code region, so this holds.
    func test_toggleCodeOnLeavesTheCaretInTheCodeText() {
        let canvas = makeCanvas([
            .paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "let x = 1")])),
        ])
        canvas.setCaret(global: canvas.boxes[0].textStart)
        canvas.makeCodeBlock()
        let box = canvas.boxes[0]
        XCTAssertGreaterThanOrEqual(canvas.head, box.textStart)
        XCTAssertEqual(box.textRef, .code(box.id))
    }

    // A language name must not get spelling underlines — iOS would flag `kotlin` as a misspelling.
    // `spellCheckableRef` puts `.codeLanguage` in its nil arm, exactly where `.code` already sits.
    func test_languageRegionIsNotSpellChecked() {
        let canvas = makeCanvas([
            .code(CodeBlock(id: BlockID("c"), language: "kotln", runs: [TextRun(text: "x")])),
        ]))
        let regions = canvas.allLeafRegions().filter {
            if case .codeLanguage = $0.ref { return true }
            return false
        }
        XCTAssertEqual(regions.count, 1)
        XCTAssertNil(canvas.spellCheckableRef(regions[0].ref))
    }
```

`spellCheckableRef(_:)` gained its `.codeLanguage` case in Task 1 (its switch is exhaustive, so it had to). This test pins the *decision* — that the case belongs in the **nil** arm — so a later edit cannot quietly start spell-checking language names.

- [ ] **Step 2: Run them**

```bash
cd submodules/TelegramUI/Components/RichTextEditor && \
  DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh RichTextEditorUIKitTests/CodeLanguageRegionTests
```

Expected: PASS with no source changes. If any fails, fix the source to match the spec decision (the test is right, the behaviour is wrong) — do not relax the test.

- [ ] **Step 3: Audit the composer-selection site**

Open `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+ComposerSelection.swift:70-85`. It reads `box.leafRegions().first`, which for a code box is now the **language** region. Read the surrounding function and decide which region it means:

- If it maps a composer-visible plain-text selection, it must use the **code** region (`box.textStart`), because the language is off the flat plain-text axis.
- If it enumerates every editable region, it must iterate all of `leafRegions()`.

Change the line accordingly, add a comment naming which of the two it is, and add a test asserting the choice.

- [ ] **Step 4: Run the full suite**

```bash
cd submodules/TelegramUI/Components/RichTextEditor && \
  DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add submodules/TelegramUI/Components/RichTextEditor/Sources submodules/TelegramUI/Components/RichTextEditor/Tests
git commit -m "richtext: pin navigation/coverage/spell-check behaviour for the language line"
```

---

### Task 8: Host wiring and the localized placeholder

**Files:**
- Modify: `submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer/Sources/RichTextEditorChatInputNode.swift:174`
- Modify: `submodules/TelegramUI/Components/RichTextAttachmentScreen/Sources/RichTextAttachmentScreen.swift:1365`
- Modify: the app's English `.strings` file (find it with the command in Step 1)

**Interfaces:**
- Consumes: `RichTextEditorPlaceholders.codeLanguage` (Task 2).
- Produces: nothing further.

- [ ] **Step 1: Find where the sibling placeholder strings are defined**

```bash
grep -rn "RichText_PlaceholderCode" --include="*.strings" --include="*.swift" Telegram/ submodules/ | head
```

Note the file and the exact entry format used by `RichText_PlaceholderCode`.

- [ ] **Step 2: Add the new string**

Add an entry alongside `RichText_PlaceholderCode`, in the same file and format:

```
"RichText.PlaceholderCodeLanguage" = "Language";
```

(Match the punctuation convention you observed in Step 1 — this repo's `.strings` keys use dots and the generated Swift accessor uses underscores.)

- [ ] **Step 3: Pass it from both hosts**

In `RichTextEditorChatInputNode.swift:174`, add `codeLanguage: self.strings.RichText_PlaceholderCodeLanguage` to the `RichTextEditorPlaceholders(...)` call, directly after the `codeBlock:` argument.

In `RichTextAttachmentScreen.swift:1365`, add `codeLanguage: environment.strings.RichText_PlaceholderCodeLanguage` to the `RichTextEditorPlaceholders(...)` call, in the same position.

- [ ] **Step 4: Verify both call sites compile**

The hosts are Bazel-only targets; there is no isolated build for them, so this is verified by the full app build in Task 9. For now, confirm the argument label and the generated accessor name exist:

```bash
grep -rn "RichText_PlaceholderCodeLanguage" --include="*.swift" --include="*.strings" Telegram/ submodules/ | head
```

Expected: the `.strings` entry plus both call sites.

- [ ] **Step 5: Commit**

```bash
git add Telegram submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer/Sources/RichTextEditorChatInputNode.swift \
        submodules/TelegramUI/Components/RichTextAttachmentScreen/Sources/RichTextAttachmentScreen.swift
git commit -m "richtext: localize the code language placeholder in both editor hosts"
```

---

### Task 9: Full app build and final verification

**Files:** none expected; fixes only.

**Interfaces:** consumes everything.

`TextNodeRef` has no consumers outside this package, so its exhaustive switches were already handled in Task 1 and `swift test` covers them. What the app build adds is: the two host call sites from Task 8, the generated `PresentationStrings` accessor for the new string, and `-warnings-as-errors` (on for 658 of 665 submodule BUILD files) — which turns the unused-variable leftovers from Task 2's property removal, and any always-false `is` check, into build failures. `Block.code` broke the app build this way once before (see the RichTextEditor `CLAUDE.md`), so run it before claiming done.

- [ ] **Step 1: Run the full app build**

```bash
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion \
 --cacheDir ~/telegram-bazel-cache build \
 --configurationPath build-system/appstore-configuration.json \
 --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
 --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 --configuration=debug_sim_arm64 --continueOnError
```

Expected: `Build completed successfully`. `--continueOnError` is deliberate — a new enum case can break several switches at once, and one pass should surface all of them.

- [ ] **Step 2: Fix every reported break**

Expect two kinds: a wrong argument label or accessor name at a Task 8 call site, and `-warnings-as-errors` complaints about anything Task 2 orphaned. If a `switch must be exhaustive` on `TextNodeRef` appears anyway, add the case explicitly and decide its behaviour from the spec — never add a `default:` to silence it, because that exhaustiveness is what surfaced the site.

- [ ] **Step 3: Re-run the build until clean, then run both test suites**

```bash
cd submodules/TelegramUI/Components/RichTextEditor && swift test
cd submodules/TelegramUI/Components/RichTextEditor && \
  DEVICE=FA6F7462-AA97-42FE-9E57-8DA0593CE756 Scripts/iostest.sh
```

Expected: both PASS.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "richtext: fix exhaustive switches for TextNodeRef.codeLanguage"
```

- [ ] **Step 5: Hand off for runtime verification**

Do **not** install to the simulator. Report to the user: the branch is build-green with both suites passing, and the runtime check they need to do themselves is — open a chat composer with "Force Text Field v2" on (Debug Settings), create a code block, confirm the "Language" line is visible and empty, type a language, send, and confirm the sent bubble shows the language lowercased.

---

## Notes for the executor

- **Do not install to the simulator or drive the sim UI.** Build only, then stop; the user does visual verification.
- **Work in a git worktree** if the current workspace has uncommitted work: `git worktree add`, then `git submodule update --init --recursive` inside it (a fresh worktree starts with empty submodule dirs and the Bazel build fails with exit 37 otherwise).
- **`swift test` builds for macOS**, so any new file under `Tests/RichTextEditorUIKitTests/` must be wrapped in `#if canImport(UIKit)`.
- If a `Scripts/iostest.sh` run appears to hang with no output, it is the post-failure `simctl diagnose`; the script already passes `-collect-test-diagnostics never`, so a hang means an ambiguous `-destination` — pass the K3 UDID explicitly as shown.
