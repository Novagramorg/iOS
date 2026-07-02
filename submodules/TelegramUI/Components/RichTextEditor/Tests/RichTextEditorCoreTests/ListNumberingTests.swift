import XCTest
@testable import RichTextEditorCore

final class ListNumberingTests: XCTestCase {
    private func item(_ id: String, _ marker: ListMarker, _ level: Int,
                      style: ParagraphStyleName = .body) -> ParagraphBlock {
        ParagraphBlock(id: BlockID(id), style: style, list: ListMembership(marker: marker, level: level))
    }

    func test_orderedTopLevel_incrementsDecimal() {
        let labels = ListNumbering.labels(for: [
            item("a", .ordered, 0), item("b", .ordered, 0), item("c", .ordered, 0),
        ])
        XCTAssertEqual(labels[BlockID("a")], "1.")
        XCTAssertEqual(labels[BlockID("b")], "2.")
        XCTAssertEqual(labels[BlockID("c")], "3.")
    }

    func test_nestedOrdered_usesAlphaAndRestarts() {
        let labels = ListNumbering.labels(for: [
            item("a", .ordered, 0),   // 1.
            item("b", .ordered, 1),   // a.
            item("c", .ordered, 1),   // b.
            item("d", .ordered, 0),   // 2.
            item("e", .ordered, 1),   // a.  (restarted)
        ])
        XCTAssertEqual(labels[BlockID("a")], "1.")
        XCTAssertEqual(labels[BlockID("b")], "a.")
        XCTAssertEqual(labels[BlockID("c")], "b.")
        XCTAssertEqual(labels[BlockID("d")], "2.")
        XCTAssertEqual(labels[BlockID("e")], "a.")
    }

    func test_bulletsUsePerLevelGlyph_andNonListResets() {
        let labels = ListNumbering.labels(for: [
            item("a", .ordered, 0),                                  // 1.
            ParagraphBlock(id: BlockID("gap")),                      // non-list → resets
            item("b", .ordered, 0),                                  // 1. again
            item("c", .bullet, 0),                                   // •
            item("d", .bullet, 1),                                   // ◦
        ])
        XCTAssertEqual(labels[BlockID("a")], "1.")
        XCTAssertNil(labels[BlockID("gap")])
        XCTAssertEqual(labels[BlockID("b")], "1.")
        XCTAssertEqual(labels[BlockID("c")], "•")
        XCTAssertEqual(labels[BlockID("d")], "◦")
    }

    func test_quoteInterruptsOrderedList_ownScope_andOuterRestarts() {
        // A quote is a distinct block container: quoted list items form their own numbering scope, and
        // the surrounding (non-quote) list restarts after the quote — a quote boundary breaks the run
        // the same way an intervening non-list paragraph does.
        let labels = ListNumbering.labels(for: [
            item("a", .ordered, 0),                  // 1.  outer list
            item("b", .ordered, 0, style: .quote),   // 1.  quote is its own scope
            item("c", .ordered, 0, style: .quote),   // 2.  contiguous quote continues within the quote
            item("d", .ordered, 0),                  // 1.  outer restarts after the quote
        ])
        XCTAssertEqual(labels[BlockID("a")], "1.")
        XCTAssertEqual(labels[BlockID("b")], "1.")
        XCTAssertEqual(labels[BlockID("c")], "2.")
        XCTAssertEqual(labels[BlockID("d")], "1.")
    }

    func test_sameLevelBulletRestartsOrderedRun() {
        let labels = ListNumbering.labels(for: [
            item("x", .ordered, 0),   // 1.
            item("y", .bullet, 0),    // •
            item("z", .ordered, 0),   // 1.  (the intervening same-level bullet restarts the run)
        ])
        XCTAssertEqual(labels[BlockID("x")], "1.")
        XCTAssertEqual(labels[BlockID("y")], "•")
        XCTAssertEqual(labels[BlockID("z")], "1.")
    }
}
