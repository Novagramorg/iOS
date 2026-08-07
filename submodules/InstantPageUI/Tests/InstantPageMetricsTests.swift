import XCTest
import UIKit
import Display
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
        let scale = InstantPageMetrics.quoteScale
        let m = InstantPageMetrics(scale: scale)

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
