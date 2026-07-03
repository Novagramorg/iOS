# Pull Quote Block Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a text-only "pull quote" block to the RichTextEditor — a centered, fixed-italic framed block with a content-hugging tinted pill and corner quote-mark images — that round-trips fully as an InstantPage `.pullQuote` rich message.

**Architecture:** A first-class `Block.pullQuote(PullQuote)` entity modeled on the existing `Block.code`/`CodeBlockBox` (single block, multi-line via interior `"\n"`, text-only by construction). Rendering forces italic + center as a **render-only** style (`ParagraphStyleName.pullQuote`, mirroring the render-only `.caption`), so nothing pollutes the model. The wire round-trip is 1:1 (`Block.pullQuote` ↔ `ChatInputBlock.pullQuote` ↔ InstantPage `.pullQuote`), mirroring the existing `.code`/`.preformatted` path. The recipient V2 render is reskinned from top/bottom rules to a content-hugging pill + corner marks.

**Tech Stack:** Swift, UIKit, TextKit (via `BlockLayoutEngine`), SwiftPM (`RichTextEditorCore` UIKit-free + `RichTextEditorUIKit`), TelegramCore (`ChatInputContent`), InstantPageUI, Bazel app build.

**Spec:** `docs/superpowers/specs/2026-07-02-pull-quote-design.md` (read it first).

## Global Constraints

- **Render-only invariant:** forced italic + center alignment are applied at render time ONLY; they MUST NOT appear in read-back `PullQuote.runs` / `Document`. Every reverse-map path strips them.
- **Text-only:** a pull quote can only contain text with inline formatting. No image/table/list/nested block inside — enforced by it being a single `Block` entity.
- **1:1 wire mapping:** one `Block.pullQuote` ↔ one `ChatInputBlock.pullQuote` ↔ one InstantPage `.pullQuote(text: RichText, caption: .empty)`. No coalescing/splitting.
- **Mirror the code block:** `Block.code` / `CodeBlock` / `CodeBlockBox` / `ChatInputCode` and their `.preformatted` codec arms are the exact template. When a step says "mirror the `.code` arm at X", copy that arm's structure verbatim and substitute the pull-quote types.
- **`TelegramCore` never imports UIKit/Display.** The `ChatInputContent` + codec work (Phase D) stays UIKit-free.
- **No markdown serializer** in the editor (WYSIWYG). Interchange is RTF + the private fragment UTI.
- **iOS floor 13** for `RichTextEditorUIKit`; the new box/views are `@available(iOS 13.0, *)` like `CodeBlockBox`.
- **Reuse asset** `Images.xcassets/Chat/Message/ReplyQuoteIcon` (no new asset).
- **Commit** after each task's tests pass. Commit messages end with the `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` trailer (repo convention).

**Build/test commands:**
- Core (macOS, fast): from `submodules/TelegramUI/Components/RichTextEditor`: `swift test --filter <TestClass>`
- UIKit (simulator): `Scripts/iostest.sh <Class/test>` (needs a booted "iPhone 17 Pro"; override `DEVICE=`). Per memory, prefer `DEVICE="iPhone 17 Pro K3"`.
- TextFormat unit test: `source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache test --configurationPath build-system/appstore-configuration.json --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git --gitCodesigningType development --gitCodesigningUseCurrent --target //submodules/TextFormat:TextFormatTests`
- Full app build (final gate): the CLAUDE.md Bazel `build` invocation with `--configuration=debug_sim_arm64` (prefix `source ~/.zshrc 2>/dev/null;`).

---

## Phase A — Core model (`RichTextEditorCore`, `swift test`)

### Task 1: `PullQuote` struct + `Block.pullQuote` case

**Files:**
- Create: `submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorCore/Model/PullQuote.swift`
- Modify: `Sources/RichTextEditorCore/Model/Block.swift` (enum case, `id`, Codable `Kind`/init/encode)
- Test: `Tests/RichTextEditorCoreTests/PullQuoteTests.swift` (create)

**Interfaces:**
- Produces: `struct PullQuote: Codable, Equatable { var id: BlockID; var runs: [TextRun]; init(id:runs:); var text: String; var utf16Count: Int }`; `Block.pullQuote(PullQuote)`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import RichTextEditorCore

final class PullQuoteTests: XCTestCase {
    func test_block_pullQuote_codableRoundTrip() throws {
        let pq = PullQuote(id: BlockID(rawValue: "pq1"), runs: [TextRun(text: "line1\nline2")])
        let block = Block.pullQuote(pq)
        let data = try JSONEncoder().encode(block)
        let decoded = try JSONDecoder().decode(Block.self, from: data)
        XCTAssertEqual(decoded, block)
        XCTAssertEqual(decoded.id, pq.id)
    }

    func test_pullQuote_utf16Count() {
        let pq = PullQuote(id: BlockID(rawValue: "x"), runs: [TextRun(text: "ab"), TextRun(text: "c")])
        XCTAssertEqual(pq.utf16Count, 3)
        XCTAssertEqual(pq.text, "abc")
    }
}
```

*(Check the exact `BlockID` initializer in `Model/BlockID.swift` and `TextRun` initializer in `Model/TextRun.swift` and adjust the literals to match — e.g. `BlockID.generate()` if there is no raw init.)*

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PullQuoteTests`
Expected: FAIL — `PullQuote`/`Block.pullQuote` undefined (compile error).

- [ ] **Step 3: Create `PullQuote.swift`** (mirror `CodeBlock.swift`, drop `language`)

```swift
import Foundation

/// A pull quote: one text-only block holding multi-line rich text (interior "\n"s), rendered centered +
/// italic inside a content-hugging tinted pill with corner quote marks. Unlike a paragraph, its runs may
/// contain "\n" — the whole block is one editable unit. Unlike a code block, its runs keep full inline
/// formatting (bold/underline/link/color/emoji); the italic + center are render-only and never stored here.
public struct PullQuote: Codable, Equatable {
    public var id: BlockID
    public var runs: [TextRun]

    public init(id: BlockID, runs: [TextRun] = []) {
        self.id = id
        self.runs = runs
    }

    /// The plain text of the block (runs concatenated; may contain "\n").
    public var text: String { runs.map(\.text).joined() }

    /// Total UTF-16 length of the block's text.
    public var utf16Count: Int { runs.reduce(0) { $0 + $1.utf16Count } }
}
```

- [ ] **Step 4: Add the `Block` case** — in `Block.swift`, add to the enum, `id`, `Kind`, `init(from:)`, `encode(to:)`:

```swift
// enum Block
case pullQuote(PullQuote)
// id switch
case .pullQuote(let q): return q.id
// enum Kind
case paragraph, media, table, code, collapsedQuote, pullQuote
// init(from:)
case .pullQuote: self = .pullQuote(try c.decode(PullQuote.self, forKey: .value))
// encode(to:)
case .pullQuote(let q):
    try c.encode(Kind.pullQuote, forKey: .type)
    try c.encode(q, forKey: .value)
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter PullQuoteTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorCore/Model/PullQuote.swift \
        submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorCore/Model/Block.swift \
        submodules/TelegramUI/Components/RichTextEditor/Tests/RichTextEditorCoreTests/PullQuoteTests.swift
git commit -m "feat(richtext): add PullQuote core model + Block.pullQuote case"
```

---

### Task 2: `TextNodeRef.pullQuote` + `DocumentTree` node arm

**Files:**
- Modify: `Sources/RichTextEditorCore/Position/TextNodeRef.swift` (add case)
- Modify: `Sources/RichTextEditorCore/Position/DocumentTree.swift:9-41` (add `.pullQuote` arm)
- Test: `Tests/RichTextEditorCoreTests/PullQuoteTests.swift` (extend)

**Interfaces:**
- Consumes: `PullQuote`, `Block.pullQuote` (Task 1).
- Produces: `TextNodeRef.pullQuote(BlockID)`; `DocumentTree.node(for: .pullQuote)` → `.paragraph` DocNode with `.text(length:, ref: .pullQuote(id))`, `nodeSize == utf16Count + 2`.

- [ ] **Step 1: Write the failing test** (append to `PullQuoteTests`)

```swift
func test_documentTree_pullQuoteNodeSize() {
    let pq = PullQuote(id: BlockID(rawValue: "pq"), runs: [TextRun(text: "abcd")])  // 4 utf16
    let doc = Document(blocks: [.pullQuote(pq)])
    // content(4) + 2 wrapper tokens == 6, exactly like a paragraph / code block.
    XCTAssertEqual(DocumentTree.documentSize(doc), 6)
}
```

*(Adjust `Document(blocks:)` to the real initializer — check `Model/Document.swift`; it may be `Document(schemaVersion:blocks:)`.)*

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter PullQuoteTests/test_documentTree_pullQuoteNodeSize`
Expected: FAIL — non-exhaustive switch / missing ref case (compile error).

- [ ] **Step 3: Add `TextNodeRef.pullQuote`** in `TextNodeRef.swift` (mirror `.code`):

```swift
case pullQuote(BlockID)
```

Update any exhaustive `switch` over `TextNodeRef` (grep `case .code(` under `Sources/RichTextEditorCore` and `Sources/RichTextEditorUIKit`; add a parallel `.pullQuote` arm — for read-back the canvas will resolve it to a `PullQuoteBox`, added later).

- [ ] **Step 4: Add the `DocumentTree` arm** in `DocumentTree.swift` after the `.code` arm:

```swift
case .pullQuote(let pq):
    // Text-only entity; same node shape as a paragraph/code block (content + 2). The `.pullQuote`
    // ref lets the canvas identify it as a pull quote for read-back / box resolution.
    return .paragraph(id: pq.id,
                      children: [.text(length: pq.utf16Count, ref: .pullQuote(pq.id))])
```

- [ ] **Step 5: Run to verify pass**

Run: `swift test --filter PullQuoteTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(richtext): map Block.pullQuote through the position tree"
```

---

### Task 3: `DocumentFragment` arms (fragment IDs, inline-merge, plain text)

**Files:**
- Modify: `Sources/RichTextEditorCore/Model/DocumentFragment.swift` (`isInlineMergeable`, `regeneratingTopLevelIDs`, the `lastLen`/`blockPlainText` helpers — every place `.code` appears)
- Test: `Tests/RichTextEditorCoreTests/PullQuoteTests.swift` (extend)

**Interfaces:**
- Produces: `isInlineMergeable(.pullQuote) == false`; a `.pullQuote` fragment regenerates its `id`; `blockPlainText(.pullQuote)` returns its text.

- [ ] **Step 1: Write the failing test**

```swift
func test_fragment_pullQuoteNotInlineMergeable() {
    XCTAssertFalse(isInlineMergeable(.pullQuote(PullQuote(id: BlockID(rawValue: "p"), runs: []))))
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter PullQuoteTests/test_fragment_pullQuoteNotInlineMergeable`
Expected: FAIL.

- [ ] **Step 3: Add the arms.** In `DocumentFragment.swift`:
  - `isInlineMergeable` (around line 7): the function currently returns `false` for `.code`/`.collapsedQuote`/`.media`/`.table` — add `.pullQuote` to the `false` set (only `.paragraph` — and only body/heading — is mergeable). Concretely, ensure `.pullQuote` hits the `return false` path.
  - `regeneratingTopLevelIDs()` (around line 18-29): mirror the `.code` arm (line 24) — `case .pullQuote(var q): q.id = BlockID.generate(); return .pullQuote(q)` (match the exact mutation style used for `.code`).
  - `blockPlainText` (around line 126): add `case .pullQuote(let q): return q.text`.
  - The `lastLen` computation (around line 110): add `case .pullQuote(let q): lastLen = q.utf16Count` (mirror `.code`).

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter PullQuoteTests`
Expected: PASS. Also run the whole Core suite to catch exhaustive-switch breaks: `swift test` → PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(richtext): DocumentFragment handling for Block.pullQuote"
```

---

### Task 4: `ParagraphStyleName.pullQuote` render-only case (Core switches)

**Files:**
- Modify: `Sources/RichTextEditorCore/Model/Enums.swift:10-14` (add case)
- Modify: any exhaustive `switch ParagraphStyleName` in Core (grep `case .caption` under `Sources/RichTextEditorCore`)
- Test: `Tests/RichTextEditorCoreTests/PullQuoteTests.swift` (extend)

**Interfaces:**
- Produces: `ParagraphStyleName.pullQuote` (render-only; never persisted on a `ParagraphBlock`).

- [ ] **Step 1: Write the failing test**

```swift
func test_paragraphStyleName_hasPullQuote() {
    XCTAssertTrue(ParagraphStyleName.allCases.contains(.pullQuote))
    // String rawValue round-trips (Codable is rawValue-based).
    XCTAssertEqual(ParagraphStyleName(rawValue: "pullQuote"), .pullQuote)
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter PullQuoteTests/test_paragraphStyleName_hasPullQuote`
Expected: FAIL.

- [ ] **Step 3: Add the case** in `Enums.swift`:

```swift
case heading1, heading2, heading3, body, caption, quote, pullQuote
```

- [ ] **Step 4: Fix Core exhaustive switches.** `swift build` and add a `.pullQuote` arm wherever the compiler flags a non-exhaustive `switch ParagraphStyleName` in Core. Where `.caption` is grouped, group `.pullQuote` with it (both render-only). If none in Core (the UIKit StyleSheet is Task 5), the build is clean.

- [ ] **Step 5: Run to verify pass**

Run: `swift test --filter PullQuoteTests` → PASS. `swift test` (full Core) → PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(richtext): add render-only ParagraphStyleName.pullQuote"
```

---

## Phase B — Editor rendering (`RichTextEditorUIKit`, `Scripts/iostest.sh`)

### Task 5: StyleSheet `.pullQuote` render + ambient-italic strip

**Files:**
- Modify: `Sources/RichTextEditorUIKit/Mapping/StyleSheet.swift` (`baseSize`, `metrics`, `font`, `paragraphStyle`)
- Modify: `Sources/RichTextEditorUIKit/Mapping/AttributedStringMapper.swift:118` (`characterAttributes(from:style:)` — ambient-italic strip; and the per-style default color at line ~75/160 if divergent — use `primaryText` like body/quote)
- Test: `Tests/RichTextEditorUIKitTests/StyleSheetPullQuoteTests.swift` (create)

**Interfaces:**
- Produces: `StyleSheet.font(for: .pullQuote, attributes:)` returns an italic body font; `paragraphStyle(for: .pullQuote, …)` is centered; `mapper.runs(from:, style: .pullQuote)` yields runs with `italic == false` regardless of the laid-out font.

- [ ] **Step 1: Write the failing test**

```swift
#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

final class StyleSheetPullQuoteTests: XCTestCase {
    func test_pullQuote_forcesItalicAndCenter() {
        let ss = StyleSheet.default
        let font = ss.font(for: .pullQuote, attributes: CharacterAttributes())  // no italic set
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
        let ps = ss.paragraphStyle(for: .pullQuote, attributes: ParagraphAttributes(), baseWritingDirection: .natural)
        XCTAssertEqual(ps.alignment, .center)
    }

    func test_pullQuote_italicIsAmbient_notStoredOnReadback() {
        let mapper = AttributedStringMapper()
        // Build the rendered (italic) string for a plain run, then reverse-map it.
        let block = ParagraphBlock(id: BlockID(rawValue: "p"), style: .pullQuote, runs: [TextRun(text: "hi")])
        let attr = mapper.attributedString(for: block)
        let runs = mapper.runs(from: attr, style: .pullQuote)
        XCTAssertEqual(runs.map(\.text).joined(), "hi")
        XCTAssertFalse(runs.contains { $0.attributes.italic })   // forced italic never persists
    }
}
#endif
```

*(Adjust `StyleSheet.default`, `CharacterAttributes()`, `ParagraphAttributes()`, `TextRun.attributes.italic`, and the `paragraphStyle(for:attributes:baseWritingDirection:)` signature to the real ones — check `StyleSheet.swift:110` and `TextRun.swift`.)*

- [ ] **Step 2: Run to verify it fails**

Run: `Scripts/iostest.sh StyleSheetPullQuoteTests`
Expected: FAIL.

- [ ] **Step 3: Add StyleSheet arms.**
  - `baseSize` (line 73): `case .pullQuote: return bodyBaseSize` (body 17pt — a pull quote reads at body scale).
  - `metrics` (line 88): `case .pullQuote: return metrics(for: .quote)` (reuse quote spacing) — or inline the same `StyleMetrics`.
  - `font` (line 99): `case .pullQuote:` return the body font with the italic trait forced ON regardless of `attributes.italic`, composing `attributes.bold`. Follow the existing `.quote` font branch (upright) but add `.traitItalic`. Example shape:

    ```swift
    case .pullQuote:
        var traits: UIFontDescriptor.SymbolicTraits = [.traitItalic]
        if attributes.bold { traits.insert(.traitBold) }
        let base = UIFont.systemFont(ofSize: baseSize(.pullQuote))
        let desc = base.fontDescriptor.withSymbolicTraits(traits) ?? base.fontDescriptor
        return UIFont(descriptor: desc, size: baseSize(.pullQuote))
    ```
    (Match the module's existing font-construction helper used by the `.quote`/`.body` branch rather than hand-rolling if one exists.)
  - `paragraphStyle` (line 110): add `.pullQuote` → same as body but `ps.alignment = .center`, no quote leading indent (symmetric). Follow the `.caption`/`.body` branch.

- [ ] **Step 4: Add the ambient-italic strip.** In `AttributedStringMapper.characterAttributes(from:style:)` (line 118): when `style == .pullQuote`, force the resulting `CharacterAttributes.italic = false` (do not read italic from the font's symbolic traits) — mirroring the per-style default-color strip already there. This is what keeps the forced italic render-only.

- [ ] **Step 5: Run to verify pass**

Run: `Scripts/iostest.sh StyleSheetPullQuoteTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(richtext): render-only italic+center for .pullQuote style"
```

---

### Task 6: `PullQuoteBox` (CanvasBlock)

**Files:**
- Create: `Sources/RichTextEditorUIKit/Canvas/PullQuoteBox.swift`
- Test: `Tests/RichTextEditorUIKitTests/PullQuoteBoxTests.swift` (create)

**Interfaces:**
- Consumes: `PullQuote`, `AttributedStringMapper`, `.pullQuote` style (Tasks 1,5).
- Produces: `final class PullQuoteBox: CanvasBlock` with `init(pullQuote: PullQuote, mapper:, width:)`, `currentBlock() -> Block.pullQuote(...)` preserving rich runs, `textRef == .pullQuote(id)`, `nodeSize == utf16Count + 2`, and a `contentWidth` accessor (widest laid-out line) for the pill geometry (Task 8).

- [ ] **Step 1: Write the failing test**

```swift
#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

final class PullQuoteBoxTests: XCTestCase {
    func test_currentBlock_preservesRichRuns() {
        let mapper = AttributedStringMapper()
        var bold = CharacterAttributes(); bold.bold = true
        let pq = PullQuote(id: BlockID(rawValue: "pq"),
                           runs: [TextRun(text: "a", attributes: bold), TextRun(text: "b")])
        let box = PullQuoteBox(pullQuote: pq, mapper: mapper, width: 300)
        guard case .pullQuote(let out) = box.currentBlock() else { return XCTFail() }
        XCTAssertEqual(out.text, "ab")
        XCTAssertTrue(out.runs.first?.attributes.bold ?? false)   // bold preserved
        XCTAssertFalse(out.runs.contains { $0.attributes.italic }) // forced italic not stored
    }

    func test_nodeSize_isContentPlusTwo() {
        let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID(rawValue: "x"),
                               runs: [TextRun(text: "abcd")]), mapper: AttributedStringMapper(), width: 300)
        XCTAssertEqual(box.nodeSize, 6)
    }
}
#endif
```

*(Adjust `CharacterAttributes`/`TextRun(text:attributes:)` to the real initializers.)*

- [ ] **Step 2: Run to verify it fails**

Run: `Scripts/iostest.sh PullQuoteBoxTests`
Expected: FAIL — `PullQuoteBox` undefined.

- [ ] **Step 3: Create `PullQuoteBox.swift`** — copy `CodeBlockBox.swift` and apply these deltas:
  - Rename type `CodeBlockBox` → `PullQuoteBox`; init param `code: CodeBlock` → `pullQuote: PullQuote`; drop `language`.
  - **Build via the mapper** (NOT the plain monospace string): store `let mapper`; build the layout string as `mapper.attributedString(for: ParagraphBlock(id: pq.id, style: .pullQuote, runs: pq.runs))`. (This gives italic+center+formatting.) Remove `codeAttributes()`/`attributedString(for code:)`.
  - `currentBlock()` → `Block.pullQuote(PullQuote(id: id, runs: mapper.runs(from: layout.attributedString, style: .pullQuote)))` (rich reverse-map; NOT the plain-string path).
  - `textRef` → `.pullQuote(id)`; `leafRegions()` ref → `.pullQuote(id)`.
  - `emptyLineHeight` uses the `.pullQuote` body font (from `mapper.styleSheet.font(for: .pullQuote, attributes: CharacterAttributes())`), not monospace.
  - `draw(...)` draws only `layout.drawText` (the pill + marks are drawn by the decorations/underlay + corner-mark view, Tasks 8-9) — remove the language label.
  - Add `var contentWidth: CGFloat { /* widest laid-out line width */ }` — compute from the layout. If `BlockLayoutEngine` lacks a max-line-width accessor, add one (see Task 8 Step 3) and call it here; fall back to `layout.boundingWidth` if present.
  - Keep insets: reuse `mapper.styleSheet` quote insets is wrong for a symmetric pill — instead use the `PullQuoteStyle` padding once Task 10 lands; for now use a constant `8` horizontal / `8` vertical so this task compiles and lays out (Task 10 wires the knob).

- [ ] **Step 4: Run to verify pass**

Run: `Scripts/iostest.sh PullQuoteBoxTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(richtext): PullQuoteBox canvas block (rich runs, forced italic)"
```

---

### Task 7: Box-factory arm (`Block.pullQuote` → `PullQuoteBox`)

**Files:**
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView.swift:574` (the `setBlocks` box factory switch)
- Test: `Tests/RichTextEditorUIKitTests/PullQuoteBoxTests.swift` (extend)

**Interfaces:**
- Produces: setting a `Document` with a `.pullQuote` block yields a `PullQuoteBox` in `canvas.boxes`.

- [ ] **Step 1: Write the failing test**

```swift
func test_canvasBuildsPullQuoteBox() {
    let canvas = DocumentCanvasView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
    canvas.setBlocks([.pullQuote(PullQuote(id: BlockID(rawValue: "pq"), runs: [TextRun(text: "hi")]))], width: 320)
    XCTAssertTrue(canvas.boxes.contains { $0 is PullQuoteBox })
}
```

*(Match how other canvas-direct tests build a `DocumentCanvasView` — check `CanvasQuoteEditTests` for the standard setup, including any `simulateParentLayout()`.)*

- [ ] **Step 2: Run to verify it fails**

Run: `Scripts/iostest.sh PullQuoteBoxTests/test_canvasBuildsPullQuoteBox`
Expected: FAIL — factory returns nothing for `.pullQuote` (or non-exhaustive switch compile error).

- [ ] **Step 3: Add the factory arm** at `DocumentCanvasView.swift:574` (next to `.code`):

```swift
case .pullQuote(let pq): return PullQuoteBox(pullQuote: pq, mapper: mapper, width: width)
```

- [ ] **Step 4: Run to verify pass**

Run: `Scripts/iostest.sh PullQuoteBoxTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(richtext): build PullQuoteBox from Block.pullQuote"
```

---

### Task 8: Content-hugging pill decorations + barless underlay

**Files:**
- Modify: `Sources/RichTextEditorUIKit/Canvas/BlockquoteUnderlay.swift` (barless image; or a `PullQuoteUnderlay` sibling)
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+Decorations.swift` (add a `PullQuoteBox` case emitting a hugging pill rect)
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView.swift` (feed the pull-quote pill rects to the barless underlay in the visible-runs sync)
- Modify (maybe): `Sources/RichTextEditorUIKit/Layout/BlockLayoutEngine.swift` (+ `BlockLayout`/`BlockLayoutTK1`) — add `maxLineWidth(forWidth:)` if absent
- Test: `Tests/RichTextEditorUIKitTests/PullQuoteGeometryTests.swift` (create)

**Interfaces:**
- Consumes: `PullQuoteBox.contentWidth` (Task 6).
- Produces: `DocumentCanvasView.pullQuotePillRects() -> [CGRect]` (centered, hugging, per pull-quote box), consumed by the barless underlay.

- [ ] **Step 1: Write the failing test**

```swift
func test_pullQuotePill_isCenteredAndHugsContent() {
    let canvas = DocumentCanvasView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
    canvas.setBlocks([.pullQuote(PullQuote(id: BlockID(rawValue: "pq"), runs: [TextRun(text: "Hi")]))], width: 320)
    canvas.simulateParentLayout()   // if the harness needs it (see CanvasDecorationsTests)
    let pills = canvas.pullQuotePillRects()
    XCTAssertEqual(pills.count, 1)
    let pill = pills[0]
    XCTAssertLessThan(pill.width, 320)                                   // hugs, not full-width
    XCTAssertEqual(pill.midX, canvas.bounds.width / 2, accuracy: 1.0)    // centered
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `Scripts/iostest.sh PullQuoteGeometryTests`
Expected: FAIL — `pullQuotePillRects` undefined.

- [ ] **Step 3: Add a max-line-width accessor if needed.** Check `BlockLayoutEngine` for an existing used-width / line-rect API (grep `boundingWidth`, `usedRect`, `lineFragmentRects`, `selectionFillRects`). If none returns the widest line width, add:

```swift
func maxLineWidth() -> CGFloat   // widest line-fragment used width; 0 when empty
```

and implement in `BlockLayout` (TK2: enumerate `textLayoutManager.enumerateTextLayoutFragments`, take max `layoutFragmentFrame.width`) and `BlockLayoutTK1` (enumerate `layoutManager.enumerateLineFragments`, take max `usedRect.width`). Return the analytically-known width for the empty case (placeholder handled in Task 11).

- [ ] **Step 4: Emit the pill rect.** In `DocumentCanvasView+Decorations.swift`, add a `pullQuotePillRects()` helper:

```swift
/// One centered, content-hugging pill rect per PullQuoteBox (canvas coords). Width = the box's widest
/// laid-out line + symmetric horizontal padding, clamped to a minimum, centered in the content column.
func pullQuotePillRects() -> [CGRect] {
    boxes.compactMap { box in
        guard let pq = box as? PullQuoteBox else { return nil }
        let hPad = pullQuoteStyle.horizontalPadding   // Task 10 knob; use a constant until then
        let w = min(max(pq.contentWidth + hPad * 2, pullQuoteStyle.minWidth), box.frame.width)
        return CGRect(x: box.frame.midX - w / 2, y: box.frame.minY, width: w, height: box.frame.height)
    }
}
```

- [ ] **Step 5: Barless underlay.** In `BlockquoteUnderlay`, add a second cached image built with `bar = 0` (factor `fillImage()` to take a `bar:` param, cache both) and a `syncPullQuote(runFills:)` that uses the barless image; OR add a lightweight `PullQuoteUnderlay: UIView` reusing the same resizable-image trick with no bar. Wire it in `DocumentCanvasView` next to `blockquoteUnderlay.sync(...)`: `pullQuoteUnderlay.sync(runFills: visiblePullQuotePillRects(band:))` (mirror `visibleBlockquoteFills`).

- [ ] **Step 6: Run to verify pass**

Run: `Scripts/iostest.sh PullQuoteGeometryTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat(richtext): content-hugging pill background for pull quotes"
```

---

### Task 9: Corner-mark controls view

**Files:**
- Create: `Sources/RichTextEditorUIKit/Canvas/PullQuoteMarksView.swift` (modeled on `QuoteCollapseControlsView.swift`)
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView.swift` (host + sync the marks view; feed the pill rects)
- Modify: `Sources/RichTextEditorUIKit/RichTextEditorView.swift` (host hook to supply the `ReplyQuoteIcon` image, `#if !SWIFT_PACKAGE` via `AppBundle`; `#if SWIFT_PACKAGE` a bundled/`nil` fallback — mirror the spoiler-texture split)
- Test: `Tests/RichTextEditorUIKitTests/PullQuoteGeometryTests.swift` (extend)

**Interfaces:**
- Consumes: `pullQuotePillRects()` (Task 8).
- Produces: `DocumentCanvasView.pullQuoteMarkRects() -> [(open: CGRect, close: CGRect)]` (top-left / bottom-right per pill), and a pooled `PullQuoteMarksView` that positions two tinted `UIImageView`s per visible pill (the closing one rotated `.pi`).

- [ ] **Step 1: Write the failing test**

```swift
func test_pullQuoteMarks_topLeftAndBottomRight() {
    let canvas = DocumentCanvasView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
    canvas.setBlocks([.pullQuote(PullQuote(id: BlockID(rawValue: "pq"), runs: [TextRun(text: "Hi")]))], width: 320)
    canvas.simulateParentLayout()
    let marks = canvas.pullQuoteMarkRects()
    XCTAssertEqual(marks.count, 1)
    let pill = canvas.pullQuotePillRects()[0]
    XCTAssertEqual(marks[0].open.minX, pill.minX + canvas.pullQuoteStyle.markInset, accuracy: 1.0)   // top-left
    XCTAssertEqual(marks[0].close.maxX, pill.maxX - canvas.pullQuoteStyle.markInset, accuracy: 1.0)   // bottom-right
    XCTAssertGreaterThan(marks[0].close.minY, marks[0].open.minY)   // close is lower than open
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `Scripts/iostest.sh PullQuoteGeometryTests/test_pullQuoteMarks_topLeftAndBottomRight`
Expected: FAIL.

- [ ] **Step 3: Add `pullQuoteMarkRects()`** in `DocumentCanvasView+Decorations.swift`:

```swift
func pullQuoteMarkRects() -> [(open: CGRect, close: CGRect)] {
    let s = pullQuoteStyle.markSize, inset = pullQuoteStyle.markInset
    return pullQuotePillRects().map { pill in
        (open: CGRect(x: pill.minX + inset, y: pill.minY + inset, width: s, height: s),
         close: CGRect(x: pill.maxX - inset - s, y: pill.maxY - inset - s, width: s, height: s))
    }
}
```

- [ ] **Step 4: Create `PullQuoteMarksView.swift`** — copy `QuoteCollapseControlsView.swift`'s pooled-view structure; instead of buttons, host two `UIImageView`s per run: `open.image = markImage`, `close.image = markImage; close.transform = CGAffineTransform(rotationAngle: .pi)`, both `tintColor = accent`, `image` in `.alwaysTemplate` mode. `sync(marks: [(open, close)], accent:)` reconciles the pool and hides extras (mirror `BlockquoteUnderlay.sync`).

- [ ] **Step 5: Host + supply the image.** In `DocumentCanvasView`, add `let pullQuoteMarksView = PullQuoteMarksView()` added above the block views (like `quoteCollapseControls`), synced in the same place as the underlay: `pullQuoteMarksView.sync(marks: pullQuoteMarkRects(), accent: mapper.theme.accent)`. Supply `markImage` via a façade hook on `RichTextEditorView` (`configurePullQuoteMarkImage` or reuse the theme/icon plumbing), resolving `ReplyQuoteIcon` — `#if !SWIFT_PACKAGE` `UIImage(bundleImageName: "Chat/Message/ReplyQuoteIcon")` (add `//submodules/AppBundle` to deps if not already present); `#if SWIFT_PACKAGE` a `nil`/bundled fallback (mirror the `SpoilerDustView` split documented in the editor CLAUDE.md).

- [ ] **Step 6: Run to verify pass**

Run: `Scripts/iostest.sh PullQuoteGeometryTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat(richtext): corner quote-mark ornaments for pull quotes"
```

---

### Task 10: `PullQuoteStyle` per-host geometry knob

**Files:**
- Create: `Sources/RichTextEditorUIKit/PullQuoteStyle.swift` (mirror `QuoteStyle.swift`)
- Modify: `Sources/RichTextEditorUIKit/RichTextEditorView.swift` (`pullQuoteStyle` property → `canvas.applyPullQuoteStyle`)
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView.swift` (store `pullQuoteStyle`, `applyPullQuoteStyle` rebuild+reload)
- Test: `Tests/RichTextEditorUIKitTests/PullQuoteGeometryTests.swift` (extend)

**Interfaces:**
- Produces: `struct PullQuoteStyle { var horizontalPadding; var verticalPadding; var cornerRadius; var fillAlpha; var markSize; var markInset; var minWidth; static let `default` }`; `DocumentCanvasView.pullQuoteStyle`.

- [ ] **Step 1: Write the failing test**

```swift
func test_pullQuoteStyle_minWidthApplied() {
    let canvas = DocumentCanvasView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
    var style = PullQuoteStyle.default; style.minWidth = 200
    canvas.applyPullQuoteStyle(style)
    canvas.setBlocks([.pullQuote(PullQuote(id: BlockID(rawValue: "pq"), runs: [TextRun(text: "x")]))], width: 320)
    canvas.simulateParentLayout()
    XCTAssertGreaterThanOrEqual(canvas.pullQuotePillRects()[0].width, 200)
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `Scripts/iostest.sh PullQuoteGeometryTests/test_pullQuoteStyle_minWidthApplied`
Expected: FAIL.

- [ ] **Step 3: Create `PullQuoteStyle.swift`** (mirror `QuoteStyle.swift` fields + `default`), retrofit the constants used in Tasks 6/8/9 to read `pullQuoteStyle`.

- [ ] **Step 4: Wire `applyPullQuoteStyle`** on `DocumentCanvasView` (store + `reload()` like `applyQuoteStyle`) and the `RichTextEditorView.pullQuoteStyle` façade property (mirror the `quoteStyle` property at `RichTextEditorView.swift:34`).

- [ ] **Step 5: Run to verify pass**

Run: `Scripts/iostest.sh PullQuoteGeometryTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(richtext): PullQuoteStyle per-host geometry knob"
```

---

### Task 11: Placeholder text + empty-state pill

**Files:**
- Modify: `Sources/RichTextEditorUIKit/Canvas/PullQuoteBox.swift` (`placeholderText` / `placeholderDraw`, empty `contentWidth` = placeholder width)
- Modify: `Sources/RichTextEditorUIKit/RichTextEditorView.swift` + `RichTextEditorView+ComposerHost.swift` (add `pullQuote` to `RichTextEditorPlaceholders`, default "Type a quote here")
- Test: `Tests/RichTextEditorUIKitTests/PullQuoteBoxTests.swift` (extend)

**Interfaces:**
- Produces: an empty `PullQuoteBox` reports a placeholder draw + a `contentWidth` sized to the placeholder (so the pill hugs it).

- [ ] **Step 1: Write the failing test**

```swift
func test_emptyPullQuote_showsPlaceholderAndHugsIt() {
    let mapper = AttributedStringMapper()
    let box = PullQuoteBox(pullQuote: PullQuote(id: BlockID(rawValue: "pq"), runs: []), mapper: mapper, width: 320)
    box.placeholder = "Type a quote here"
    XCTAssertNotNil(box.placeholderDraw())
    XCTAssertGreaterThan(box.contentWidth, 0)   // hugs the placeholder, not zero
}
```

*(Match how `BlockBox.placeholderDraw()` is shaped and how the placeholder string is injected — via `stampListMarkers` in production; the box may take the string via a settable property.)*

- [ ] **Step 2: Run to verify it fails**

Run: `Scripts/iostest.sh PullQuoteBoxTests/test_emptyPullQuote_showsPlaceholderAndHugsIt`
Expected: FAIL.

- [ ] **Step 3: Implement placeholder** on `PullQuoteBox` (mirror `BlockBox.placeholderText`/`placeholderDraw`, centered/italic/`mapper.theme.placeholder`); when `layout.length == 0`, `contentWidth` returns the measured placeholder-string width (so the empty pill hugs it, clamped by `minWidth` in Task 8). Add a `pullQuote` field to `RichTextEditorPlaceholders` (default "Type a quote here") and stamp it onto the box wherever list/paragraph placeholders are stamped.

- [ ] **Step 4: Run to verify pass**

Run: `Scripts/iostest.sh PullQuoteBoxTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(richtext): pull-quote placeholder + empty-state pill"
```

---

## Phase C — Editing (`RichTextEditorUIKit`)

### Task 12: `makePullQuote()` creation toggle

**Files:**
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+ParagraphFormat.swift` (add `makePullQuote()`, mirror `makeCodeBlock()`)
- Modify: `Sources/RichTextEditorUIKit/RichTextEditorView.swift` (façade `makePullQuote()`)
- Test: `Tests/RichTextEditorUIKitTests/CanvasPullQuoteEditTests.swift` (create)

**Interfaces:**
- Produces: `DocumentCanvasView.makePullQuote()` toggles the touched top-level paragraphs into one `Block.pullQuote` (text joined by `"\n"`) and toggles a pull quote back into body paragraphs split on `"\n"`; `RichTextEditorView.makePullQuote()`.

- [ ] **Step 1: Write the failing test**

```swift
func test_makePullQuote_togglesParagraphsIntoOneBlock() {
    let canvas = DocumentCanvasView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
    canvas.setBlocks([.paragraph(ParagraphBlock(id: BlockID(rawValue: "a"), style: .body, runs: [TextRun(text: "one")])),
                      .paragraph(ParagraphBlock(id: BlockID(rawValue: "b"), style: .body, runs: [TextRun(text: "two")]))],
                     width: 320)
    canvas.selectAll(nil)          // or set a selection spanning both paragraphs (match the module's selection helper)
    canvas.makePullQuote()
    let blocks = canvas.currentDocument().blocks   // match the real read-back accessor
    XCTAssertEqual(blocks.count, 1)
    guard case .pullQuote(let pq) = blocks[0] else { return XCTFail() }
    XCTAssertEqual(pq.text, "one\ntwo")
    // Toggle back:
    canvas.selectAll(nil)
    canvas.makePullQuote()
    XCTAssertTrue(canvas.currentDocument().blocks.allSatisfy { if case .paragraph = $0 { return true } else { return false } })
}
```

*(Copy the exact selection + read-back helpers from `CanvasCodeBlockTests` / the code-block `makeCodeBlock` test — same shape.)*

- [ ] **Step 2: Run to verify it fails**

Run: `Scripts/iostest.sh CanvasPullQuoteEditTests`
Expected: FAIL.

- [ ] **Step 3: Implement `makePullQuote()`** in `+ParagraphFormat.swift` by copying `makeCodeBlock()` and substituting: build a `PullQuote(id:, runs:)` from the joined runs (preserve inline formatting — unlike code, do NOT flatten to plain text; concatenate the paragraphs' runs with a `TextRun(text: "\n")` between paragraphs), and the reverse toggle splits `pq.runs` on `"\n"` into `.body` paragraphs (preserving runs). Refuse a selection spanning a non-text block (same guard as code). Wrap in `editing { }` for one undo step. Add the façade forwarder in `RichTextEditorView.swift`.

- [ ] **Step 4: Run to verify pass**

Run: `Scripts/iostest.sh CanvasPullQuoteEditTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(richtext): makePullQuote creation toggle"
```

---

### Task 13: Enter inserts an interior newline

**Files:**
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+Editing.swift` (add `insertPullQuoteNewline`, mirror `insertCodeBlockNewline`)
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+UITextInput.swift` (Enter dispatch — route a caret inside a `PullQuoteBox` to `insertPullQuoteNewline`)
- Test: `Tests/RichTextEditorUIKitTests/CanvasPullQuoteEditTests.swift` (extend)

**Interfaces:**
- Produces: pressing Enter with the caret inside a pull quote inserts `"\n"` (replacing any selection), keeping one block.

- [ ] **Step 1: Write the failing test** — place the caret inside a pull quote, invoke the Enter path (call the same method the Return key command calls, e.g. `canvas.insertParagraphBreak()` / the key-command handler), assert the block is still a single `.pullQuote` whose text now contains `"\n"`. (Copy the code-block Enter test structure.)

- [ ] **Step 2: Run to verify it fails.** `Scripts/iostest.sh CanvasPullQuoteEditTests/<enterTest>` → FAIL.

- [ ] **Step 3: Implement.** Copy `insertCodeBlockNewline` → `insertPullQuoteNewline`; in the Enter dispatch (where `codeBlockDoubleReturnExit` / `insertCodeBlockNewline` are dispatched on a `CodeBlockBox` caret), add the `PullQuoteBox` branch that first checks the exit condition (Task 14) then falls back to `insertPullQuoteNewline`.

- [ ] **Step 4: Run to verify pass.** → PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(richtext): Enter inserts interior newline in a pull quote"
```

---

### Task 14: Double-return exit + empty-Backspace un-make

**Files:**
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+Editing.swift` (`pullQuoteDoubleReturnExitIndex` + `exitPullQuoteToBodyParagraph`/`Before` + `unmakeEmptyPullQuote`, mirror the code-block functions)
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+UITextInput.swift` (Enter + Backspace dispatch)
- Test: `Tests/RichTextEditorUIKitTests/CanvasPullQuoteEditTests.swift` (extend)

**Interfaces:**
- Produces: exit semantics identical to the code block (trailing empty line → body after; first empty line / two-newlines-at-start → body before; wholly-empty block → un-make to body; middle empty line → newline). Empty-pull-quote Backspace un-makes to a body paragraph.

- [ ] **Step 1: Write the failing tests** — one per case (trailing, first, wholly-empty, middle, empty-backspace). Copy `DoubleReturnExitTests` / the code-block exit tests and swap the block type. E.g.:

```swift
func test_doubleReturn_trailingEmptyLine_exitsAfter() {
    // pull quote "hi\n" with caret on the trailing empty line → Enter exits to a body paragraph AFTER.
    // (assemble via makePullQuote + insertPullQuoteNewline, then invoke the Enter path)
    ...
    let blocks = canvas.currentDocument().blocks
    XCTAssertEqual(blocks.count, 2)
    if case .pullQuote(let pq) = blocks[0] { XCTAssertEqual(pq.text, "hi") } else { XCTFail() }
    if case .paragraph(let p) = blocks[1] { XCTAssertEqual(p.style, .body) } else { XCTFail() }
}
```

- [ ] **Step 2: Run to verify they fail.** → FAIL.

- [ ] **Step 3: Implement** by copying `codeBlockDoubleReturnExit` / `exitCodeBlockToBodyParagraph(Before)` / `uncodeEmptyCodeBlock` → the `pullQuote`* equivalents; hook them into the Enter dispatch (Task 13) and the empty-block Backspace branch (where `uncodeEmptyCodeBlock` fires in `deleteBackward`).

- [ ] **Step 4: Run to verify pass.** → PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(richtext): pull-quote double-return exit + empty-backspace un-make"
```

---

### Task 15: Framed-atom integration (tap-below, cross-block delete, backspace-after)

**Files:**
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+Editing.swift` (`isNonParagraphAtom`, `coverableContentEnd`, `applyReplace` cross-block truncate/drop — add `PullQuoteBox` where `CodeBlockBox` appears)
- Modify: `Sources/RichTextEditorUIKit/Canvas/DocumentCanvasView+Interaction.swift` (tap-below trailing pull quote → append body paragraph)
- Modify: `Sources/RichTextEditorUIKit/Canvas/BlockStack.swift` (`isFramedAtom` / `facingInset` — a pull quote is its own framed atom for inter-block spacing)
- Test: `Tests/RichTextEditorUIKitTests/CanvasPullQuoteEditTests.swift` (extend)

**Interfaces:**
- Produces: `PullQuoteBox` is treated like `CodeBlockBox` in every framed-atom code path (spacing, cross-block delete, backspace-after-atom, tap-below).

- [ ] **Step 1: Write the failing test** — e.g. backspace at the start of a body paragraph after a pull quote deletes the empty paragraph (not the block); and a tap below a trailing pull quote appends a body paragraph. Copy the equivalent code-block tests.

- [ ] **Step 2: Run to verify it fails.** → FAIL.

- [ ] **Step 3: Implement.** Grep `CodeBlockBox` across `Sources/RichTextEditorUIKit/Canvas/*.swift`; at each framed-atom decision site (`isNonParagraphAtom`, `coverableContentEnd`, `isFramedAtom`, `facingInset`, the `applyReplace` endpoint truncate/drop, the tap-below affordance, backspace-after-atom), add `PullQuoteBox` alongside `CodeBlockBox` (same handling). A pull quote's `coverableContentEnd` is `textStart + textLength` (it has a text leaf, like code — not the audio-atom `nodeStart + 1`).

- [ ] **Step 4: Run to verify pass.** → PASS. Then run the full UIKit suite to catch regressions: `Scripts/iostest.sh` (no filter) → PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(richtext): pull quote as a framed atom (delete/spacing/tap-below)"
```

---

## Phase D — ChatInputContent round-trip (`TelegramCore`, TextFormat tests)

### Task 16: `ChatInputPullQuote` + `ChatInputBlock.pullQuote`

**Files:**
- Modify: `submodules/TelegramCore/Sources/ChatInputContent/ChatInputContentModel.swift` (struct, block case, CodingKeys, `isEntityExpressible`, flat-axis)
- Test: `submodules/TextFormat/Tests/ChatInputContentModelTests.swift` (extend; match the real test file name)

**Interfaces:**
- Produces: `struct ChatInputPullQuote: Equatable, Codable { var runs: [ChatInputRun] }`; `ChatInputBlock.pullQuote(ChatInputPullQuote)`; `isEntityExpressible == false`; flat-axis participation = full text length.

- [ ] **Step 1: Write the failing test**

```swift
func test_pullQuote_isNotEntityExpressible() {
    let content = ChatInputContent(blocks: [.pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "hi")]))])
    XCTAssertFalse(content.isEntityExpressible())
    XCTAssertFalse(content.isEntityExpressible(options: EntityExpressibleOptions()))  // unconditional
}

func test_pullQuote_codableRoundTrip() throws {
    let block = ChatInputBlock.pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "a\nb")]))
    let data = try JSONEncoder().encode(block)
    XCTAssertEqual(try JSONDecoder().decode(ChatInputBlock.self, from: data), block)
}
```

*(Match the real `ChatInputContent`/`ChatInputRun`/`EntityExpressibleOptions` initializers.)*

- [ ] **Step 2: Run to verify it fails**

Run the TextFormat target (see Global Constraints). Expected: FAIL / compile error.

- [ ] **Step 3: Implement** in `ChatInputContentModel.swift`:
  - `struct ChatInputPullQuote` mirroring `ChatInputCode` (line 389) minus `language`.
  - `case pullQuote(ChatInputPullQuote)` in `ChatInputBlock` (line 244) + the two `CodingKeys` enums (lines 256, 264) + the decode/encode arms (mirror `.code`).
  - `isEntityExpressible(options:)` (lines 214-240): add `case .pullQuote: return false` (unconditional — no `quotesRequireRichContent` gating).
  - Flat-axis (`blockIsFlatParticipating`/`blockFlatLength`, lines 735-757): `.pullQuote` participates like `.code` (counts its full text length).

- [ ] **Step 4: Run to verify pass.** TextFormat target → PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(core): ChatInputBlock.pullQuote (rich-only, non-entity-expressible)"
```

---

### Task 17: `ChatInputContent` ↔ InstantPage `.pullQuote`

**Files:**
- Modify: `submodules/TelegramCore/Sources/ChatInputContent/ChatInputContentInstantPage.swift` (forward ~line 76, reverse ~line 215)
- Test: `submodules/TextFormat/Tests/ChatInputContentInstantPageTests.swift` (extend)

**Interfaces:**
- Produces: `.pullQuote(pq)` → `InstantPageBlock.pullQuote(text: richText(from: pq.runs), caption: .empty)`; reverse `.pullQuote(rt, _)` → `.pullQuote(ChatInputPullQuote(runs: chatInputRuns(fromRichText: rt)))`.

- [ ] **Step 1: Write the failing test**

```swift
func test_pullQuote_instantPageRoundTrip_preservesFormatting() {
    var bold = ...; // a bold ChatInputRun (match the run-attribute API)
    let content = ChatInputContent(blocks: [.pullQuote(ChatInputPullQuote(runs: [bold, ChatInputRun(text: "\nplain")]))])
    let page = instantPage(from: content)
    // exactly one .pullQuote block, flat text "…\nplain"
    guard case .pullQuote(let text, let caption)? = page.blocks.first else { return XCTFail() }
    XCTAssertEqual(text.plainText, boldText + "\nplain")
    // reverse
    let back = chatInputContent(from: page)   // match the real reverse entry point
    XCTAssertEqual(back, content)
}
```

- [ ] **Step 2: Run to verify it fails.** → FAIL.

- [ ] **Step 3: Implement** — add the forward arm next to `.code` (line 76):

```swift
case let .pullQuote(pq):
    result.append(.pullQuote(text: richText(from: pq.runs), caption: .empty))
```

and the reverse next to `.preformatted` (line 215):

```swift
case let .pullQuote(rt, _):
    result.append(.pullQuote(ChatInputPullQuote(runs: chatInputRuns(fromRichText: rt))))
```

- [ ] **Step 4: Run to verify pass.** → PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(core): ChatInputContent <-> InstantPage .pullQuote codec"
```

---

## Phase E — App-side bridges, send builder, host UI

### Task 18: `DocumentChatInputContentBridge` — `Block.pullQuote` ↔ `ChatInputBlock.pullQuote`

**Files:**
- Modify: `submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer/Sources/DocumentChatInputContentBridge.swift` (both directions — mirror the `.code` arms)
- Modify (if code touches it): `.../ChatRichTextEditorComposer/Sources/ComposerDocumentBridge.swift` (flat-axis participation)
- Test: extend a composer/TextFormat test if one exists for the bridge; otherwise assert via the full-build round-trip.

**Interfaces:**
- Produces: `Block.pullQuote(PullQuote) ↔ ChatInputBlock.pullQuote(ChatInputPullQuote)` (runs mapped via the existing run converters).

- [ ] **Step 1: Implement** the two arms next to the `.code`↔`.code` arms in `DocumentChatInputContentBridge.swift` (forward `chatInputContent(from:)` and reverse `document(from:)` / `chatInputBlock` builders). Map `PullQuote.runs ↔ ChatInputPullQuote.runs` with the existing `chatInputRuns(...)` / `runs(...)` converters used by `.code`. If `ComposerDocumentBridge` special-cases `.code` for the flat axis, add the same `.pullQuote` handling.

- [ ] **Step 2: Verify** with the module build (`swift`/Bazel compile of the composer target) — no unit test harness here; correctness is covered end-to-end by Task 17 (codec) + the full build (Task 24) + the device check. Grep to confirm no remaining non-exhaustive `switch Block` / `switch ChatInputBlock` in the file.

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat(composer): bridge Block.pullQuote <-> ChatInputBlock.pullQuote"
```

---

### Task 19: Attachment-screen InstantPage builder arm

**Files:**
- Modify: the `RichTextEditorMessageConversion` InstantPage builder (find via `grep -rln "InstantPageBlock" submodules/TelegramUI/Components/*/RichTextEditorMessageConversion* submodules/TelegramUI/**/RichTextEditorMessageConversion*` — the file that builds `InstantPage` from an editor `Document` for the attachment-screen send)
- Test: none in-module; covered by full build + device check.

**Interfaces:**
- Produces: `Block.pullQuote` → `InstantPageBlock.pullQuote(text:, caption: .empty)` in the direct Document→InstantPage builder.

- [ ] **Step 1: Implement** the `.pullQuote` arm next to the builder's `.code`→`.preformatted` arm: `case .pullQuote(let pq): blocks.append(.pullQuote(text: richText(from: pq.runs), caption: .empty))` (use the builder's local run→RichText helper).

- [ ] **Step 2: Verify** the module compiles; grep for any other non-exhaustive `switch Block` in the conversion module and add the arm.

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat(richtext): attachment-screen InstantPage builder emits .pullQuote"
```

---

### Task 20: "Pull Quote" creation entries (Format menu + action bar)

**Files:**
- Modify: `submodules/TelegramUI/Sources/ChatTextInputPanelNode.swift` (add "Pull Quote" to the rich Format submenu → `setParagraphStyle`-style call, here `richTextInputNode.makePullQuote()`)
- Modify: `submodules/TelegramUI/Components/RichTextAttachmentScreen/Sources/RichTextActionBarComponent.swift` (+ `RichTextAttachmentScreen.swift`) (action-bar entry → `editor.makePullQuote()`)
- Test: none (UI wiring); verified by the device check.

**Interfaces:**
- Consumes: `RichTextEditorView.makePullQuote()` (Task 12).

- [ ] **Step 1: Add the composer Format entry.** In the rich Format submenu construction (where "Quote"/"Code" route to the editor — grep `makeCodeBlock` / `performFormatAction` / the 10-item submenu), add a "Pull Quote" item that calls the editor's `makePullQuote()` through the existing `ChatRichTextInputNode` seam (mirror how "Code" is wired).

- [ ] **Step 2: Add the attachment action-bar entry** mirroring the existing paragraph-style/code buttons in `RichTextActionBarComponent`, routing to `editor.makePullQuote()`.

- [ ] **Step 3: Verify** the app compiles (`swift`/Bazel). Commit:

```bash
git add -A && git commit -m "feat(richtext): Pull Quote creation entries in composer + attachment editor"
```

---

## Phase F — Recipient V2 render (`InstantPageUI`)

### Task 21: Image-ornament laid-out item + view

**Files:**
- Modify: `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift` (new `InstantPageV2ImageOrnamentItem` struct + a `.imageOrnament` case in `InstantPageV2LaidOutItem`; `frame`/`offsetBy` arms ~lines 106-107,132-133)
- Modify: `submodules/InstantPageUI/Sources/InstantPageRenderer.swift` (`InstantPageV2ItemKind` line 39; `reuse` 642-649; `stableId` 713-714; `makeItemView` 771-773; new `InstantPageV2ImageOrnamentView: InstantPageItemView` mirroring `InstantPageV2ShapeView` 1642-1671)
- Modify: `submodules/InstantPageUI/Sources/InstantPageV2RevealCost.swift:338` (add the ornament to the zero-cost non-text list)
- Test: none in-module (InstantPageUI has no unit suite here); covered by the full build + device check.

**Interfaces:**
- Produces: an image-backed laid-out item (a `UIImageView` rendering `ReplyQuoteIcon` tinted + optionally rotated) usable by the pull-quote layout (Task 22).

- [ ] **Step 1: Add the item struct** in `InstantPageV2Layout.swift` (next to `InstantPageV2ShapeItem` ~199-214):

```swift
struct InstantPageV2ImageOrnamentItem {
    let frame: CGRect
    let imageName: String     // "Chat/Message/ReplyQuoteIcon"
    let color: UIColor
    let rotated: Bool         // true → 180° (closing mark)
}
```

Add `.imageOrnament(InstantPageV2ImageOrnamentItem)` to `InstantPageV2LaidOutItem` and its `frame` / `offsetBy` arms.

- [ ] **Step 2: Add the view + switch arms** in `InstantPageRenderer.swift`: an `InstantPageV2ImageOrnamentView` (a `UIImageView` host; `image = UIImage(bundleImageName: item.imageName)?.withRenderingMode(.alwaysTemplate)`, `tintColor = item.color`, `transform = item.rotated ? CGAffineTransform(rotationAngle: .pi) : .identity`), plus the `InstantPageV2ItemKind` case, `reuse`, `stableId` (`.positional`), and `makeItemView` arms — mirror the `.shape` arms exactly.

- [ ] **Step 3: Add to reveal cost** at `InstantPageV2RevealCost.swift:338` (list the ornament among the zero-cost non-text items, next to `.blockQuoteBar`/`.shape`).

- [ ] **Step 4: Verify** InstantPageUI compiles. Commit:

```bash
git add -A && git commit -m "feat(instantpage): V2 image-ornament item for pull-quote corner marks"
```

---

### Task 22: Reskin `layoutQuoteText(isPull: true)` → pill + corner marks

**Files:**
- Modify: `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift:2395-2503` (`layoutQuoteText`, the `isPull` branch)
- Test: none in-module; device check is the gate.

**Interfaces:**
- Consumes: the image-ornament item (Task 21), the existing `InstantPageV2ShapeKind.roundedRect` fill item.
- Produces: a pull-quote layout with a content-hugging rounded pill behind centered italic text + two corner marks; NO top/bottom rules.

- [ ] **Step 1: Remove the rules.** In the `isPull` branch, delete the top (2416-2429) and bottom (2472-2481) `.shape` `.line` items.

- [ ] **Step 2: Add the pill.** Compute the laid-out text width (the max line width of the centered text item) + horizontal padding, centered in the content column; append an `InstantPageV2ShapeItem(frame: pill, kind: .roundedRect(cornerRadius:), color: accent.withAlphaComponent(fillAlpha))` BEHIND the text (insert before the text item so it renders under it). Keep the existing centered + italic text (2412-2414, 2434) unchanged.

- [ ] **Step 3: Add the marks.** Append two `.imageOrnament` items: open at the pill's top-left (`imageName: "Chat/Message/ReplyQuoteIcon"`, `rotated: false`), close at bottom-right (`rotated: true`), both `color: accent`, sized to match the composer's `markSize`.

- [ ] **Step 4: Verify** the message bubble render (via the full build + device check). Commit:

```bash
git add -A && git commit -m "feat(instantpage): render pull quote with pill + corner marks (V2)"
```

---

## Phase G — RTF, build gate, verification

### Task 23: RTF export arm

**Files:**
- Modify: `submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextEditorUIKit/Canvas/RTFConversion.swift` (add `.pullQuote` to the block export walk + size map — wherever `.code` is handled)
- Test: `Tests/RichTextEditorUIKitTests/RTFConversionTests.swift` (extend — export a pull quote, assert its text survives)

**Interfaces:**
- Produces: a `Block.pullQuote` exports as an italic quote-like paragraph (best-effort); text is never lost.

- [ ] **Step 1: Write the failing test** — build a `Document` with a `.pullQuote`, run `rtfData(from:)`, assert the RTF contains the pull-quote text. (Copy the code-block RTF export test.)

- [ ] **Step 2: Run to verify it fails.** → FAIL.

- [ ] **Step 3: Implement** the `.pullQuote` arm in the export walk (mirror the `.code`/`.quote` arm; emit the runs as an italic paragraph). Add `.pullQuote` to the paragraph-style size map (`case .body, .quote, .pullQuote: return 17`).

- [ ] **Step 4: Run to verify pass.** → PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(richtext): RTF export for pull quotes"
```

---

### Task 24: Full-suite + full app build gate

**Files:** none (verification only).

- [ ] **Step 1: Full SwiftPM suite** from the package dir: `swift test` (Core) → PASS; `Scripts/iostest.sh` (UIKit, no filter) → PASS.

- [ ] **Step 2: TextFormat unit test** (see Global Constraints command) → PASS.

- [ ] **Step 3: Full app build** — the CLAUDE.md Bazel `build` with `--configuration=debug_sim_arm64` (prefix `source ~/.zshrc 2>/dev/null;`), adding `--continueOnError` on the first pass to collect all errors. Fix any exhaustive-switch / signature breaks across TelegramCore, InstantPageUI, TelegramUI, the composer, and the attachment screen. Re-build clean.

- [ ] **Step 4: Commit** any build fixes:

```bash
git add -A && git commit -m "fix(richtext): resolve full-build switch/signature gaps for pull quote"
```

---

### Task 25: Runtime verification (logged-in, two devices)

**Files:** none (manual/device verification; not gating for merge but the intended acceptance).

- [ ] **Step 1** Install per the sim-install note (memory: `cp` the rebuilt `Frameworks/TelegramUIFramework` over the installed bundle if `simctl install` no-ops at the same buildNumber).
- [ ] **Step 2** In the composer: create a pull quote (Format ▸ Pull Quote), type multi-line text with bold + a link + a custom emoji, confirm centered italic + content-hugging pill + corner marks + placeholder on empty.
- [ ] **Step 3** Send; confirm the recipient bubble renders centered italic + pill + corner marks (V2), formatting intact.
- [ ] **Step 4** Edit your own sent message; confirm it re-opens as a pull quote with runs intact (italic still render-only — not doubled).
- [ ] **Step 5** Background/reopen with a pull-quote draft; confirm it persists.
- [ ] **Step 6** Record the outcome in the editor CLAUDE.md (a short dated note, mirroring the checklist/collapsed-quote/code-block entries) + update the `MEMORY.md` index if warranted.

---

## Self-review notes (author)

- **Spec coverage:** model (T1-4), rendering incl. pill+marks+placeholder (T5-11), editing (T12-15), ChatInputContent + codec (T16-17), bridges/builder/host UI (T18-20), V2 recipient render (T21-22), RTF (T23), build+device (T24-25). Markdown reverse is intentionally left lossy (spec §5) — no task, by design.
- **Render-only invariant** is tested explicitly (T5 read-back `italic == false`, T6 `currentBlock` rich runs sans italic).
- **Type consistency:** `PullQuote{id,runs}`, `ChatInputPullQuote{runs}`, `TextNodeRef.pullQuote`, `ParagraphStyleName.pullQuote`, `PullQuoteBox`, `PullQuoteStyle`, `pullQuotePillRects()`, `pullQuoteMarkRects()`, `makePullQuote()`, `insertPullQuoteNewline` — used consistently across tasks.
- **Verify-first placeholders:** the plan flags where exact initializers/method names must be confirmed against the real files (BlockID/TextRun/CharacterAttributes/Document initializers; the mapper `paragraphStyle` signature; the composer submenu seam). These are noted at the point of use, not left as silent TODOs.
