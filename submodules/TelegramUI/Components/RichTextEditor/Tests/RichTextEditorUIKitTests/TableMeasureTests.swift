#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 16.0, *)
final class TableMeasureTests: XCTestCase {
    private let mapper = AttributedStringMapper()

    private func makeTable(width: CGFloat) -> TableBlockBox {
        func cell(_ id: String, _ text: String) -> Cell {
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: text)]))])
        }
        let t = TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [
                Row(id: BlockID("r0"), isHeader: true, cells: [cell("a", "Alpha header that is quite long and wraps"), cell("b", "Beta")]),
                Row(id: BlockID("r1"), cells: [cell("c", "Gamma"), cell("d", "Delta value here")]),
            ])
        let box = TableBlockBox(table: t, mapper: mapper, width: width)
        box.setWidth(width)   // explicit: populate columnWidths up front so the tests don't depend on init internals
        return box
    }

    // The OLD height path called box.setWidth(cellContentWidth(c)) on every cell as a side effect.
    // To expose it: lay cells out at one width, then change the table's layoutWidth (so the column
    // widths differ) WITHOUT recomputing the cells, then read height. The old code re-flowed the
    // cells to the new column width; the refactored height must leave them untouched (recompute() is
    // the sole cell-layout site).
    func test_height_doesNotMutateCellWidths() {
        let box = makeTable(width: 320)
        box.recompute()                       // cells laid out at 320-derived column widths
        box.setWidth(700)                     // columns now 700-derived; cells deliberately NOT recomputed
        let cellLayout = box.cells[0][0].boxes[0].textLayout
        let before = cellLayout.containerWidth
        _ = box.height
        XCTAssertEqual(cellLayout.containerWidth, before, accuracy: 0.001,
                       "reading height must not resize cell text layouts")
    }

    // height (refactored) equals the stateless measure at the live width.
    func test_height_equalsMeasuredAtLiveWidth() {
        let box = makeTable(width: 320)
        XCTAssertEqual(box.height, box.measuredHeight(forWidth: 320), accuracy: 0.1)
    }
}
#endif
