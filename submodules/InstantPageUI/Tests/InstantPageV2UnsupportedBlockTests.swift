import XCTest
import UIKit
import TelegramCore
import UnsupportedContentPill
@testable import InstantPageUI

private let testStrings = UnsupportedContentPillStrings(
    title: "Unsupported message",
    text: "Please update Telegram to view this message.",
    action: "Update"
)

private let testColors = UnsupportedContentPillColors(
    fill: UIColor(white: 0.0, alpha: 0.1),
    primaryText: .white,
    isDark: true
)

/// A real pill item (so its height is the component's real height), moved to `y`.
private func makeUnsupportedItem(y: CGFloat, isTopLevel: Bool = true) -> InstantPageV2LaidOutItem {
    let items = layoutUnsupportedBlock(boundingWidth: 320.0, horizontalInset: 17.0, strings: testStrings, colors: testColors, isTopLevel: isTopLevel)
    guard case var .unsupportedContent(item) = items[0] else {
        preconditionFailure("layoutUnsupportedBlock did not produce an .unsupportedContent item")
    }
    item.frame.origin.y = y
    return .unsupportedContent(item)
}

private func makeLayout(_ items: [InstantPageV2LaidOutItem]) -> InstantPageV2Layout {
    return InstantPageV2Layout(contentSize: CGSize(width: 320.0, height: 500.0), items: items, detailsIndices: [])
}

/// Mirrors the padding local to `unsupportedContentTearZones`. Duplicated rather than shared because
/// the value is private to that function; if it changes there, these tests fail loudly and this
/// line is the fix.
private let expectedTearPadding: CGFloat = 6.0

final class InstantPageV2UnsupportedBlockTests: XCTestCase {
    /// A page from a newer server can contain a whole run of blocks this build cannot decode. One
    /// "update your app" card is the message; five stacked copies is noise. The helper reports
    /// which indices to SKIP rather than returning a filtered array — filtering would renumber the
    /// blocks that `pathPrefix + [i]` turns into structural paths.
    func testAdjacentUnsupportedBlocksCollapseToOne() {
        let blocks: [InstantPageBlock] = [.paragraph(.plain("a")), .unsupported, .unsupported, .unsupported, .paragraph(.plain("b"))]

        XCTAssertEqual(redundantUnsupportedBlockIndices(blocks), Set([2, 3]))
    }

    /// Separated runs are separate cards: the pill marks a position in the document, so two holes
    /// in different places must stay two.
    func testSeparatedRunsAreKept() {
        let blocks: [InstantPageBlock] = [.unsupported, .paragraph(.plain("a")), .unsupported, .unsupported]

        XCTAssertEqual(redundantUnsupportedBlockIndices(blocks), Set([3]))
    }

    /// Sequences with nothing to collapse report nothing (the helper runs on every nested sequence
    /// — details bodies, table cells — so it must be a no-op in the common case).
    func testSequencesWithoutRunsReportNothing() {
        XCTAssertTrue(redundantUnsupportedBlockIndices([]).isEmpty)
        XCTAssertTrue(redundantUnsupportedBlockIndices([.unsupported]).isEmpty)

        let mixed: [InstantPageBlock] = [.paragraph(.plain("a")), .divider, .unsupported, .paragraph(.plain("b"))]
        XCTAssertTrue(redundantUnsupportedBlockIndices(mixed).isEmpty)
    }

    /// The pill is a rounded card, so it is laid out inside the page's horizontal insets like a
    /// paragraph — not flush to the page edge like a document row — and it stretches to fill them.
    func testPillIsLaidOutInsideThePageInsets() {
        let items = layoutUnsupportedBlock(boundingWidth: 320.0, horizontalInset: 17.0, strings: testStrings, colors: testColors, isTopLevel: true)

        XCTAssertEqual(items.count, 1)
        guard case let .unsupportedContent(item) = items[0] else {
            return XCTFail("expected an .unsupportedContent item, got \(items[0])")
        }
        XCTAssertEqual(item.frame.minX, 17.0)
        XCTAssertEqual(item.frame.width, 320.0 - 17.0 * 2.0)
        XCTAssertEqual(item.frame.minY, 0.0)
    }

    /// The block layout and the component must agree on height, or the page reserves the wrong
    /// amount of space and the pill is clipped or floats.
    func testPillHeightMatchesTheComponent() {
        let contentWidth = 320.0 - 17.0 * 2.0
        let expected = UnsupportedContentPill.layout(strings: testStrings, colors: testColors, constrainedWidth: contentWidth)
        let items = layoutUnsupportedBlock(boundingWidth: 320.0, horizontalInset: 17.0, strings: testStrings, colors: testColors, isTopLevel: true)

        guard case let .unsupportedContent(item) = items[0] else {
            return XCTFail("expected an .unsupportedContent item, got \(items[0])")
        }
        XCTAssertEqual(item.frame.height, expected.size.height)
        XCTAssertEqual(item.layout, expected)
    }

    /// The host tears a band out of its background across each pill. The band is the pill's own
    /// box plus breathing room, or the bubble's cut edges would touch the pill.
    func testTearZoneIsThePillPlusPadding() {
        let item = makeUnsupportedItem(y: 40.0)
        guard case let .unsupportedContent(pill) = item else {
            return XCTFail("expected an .unsupportedContent item")
        }

        let zones = unsupportedContentTearZones(in: makeLayout([item]))

        XCTAssertEqual(zones.count, 1)
        XCTAssertEqual(zones[0].minY, 40.0 - expectedTearPadding)
        XCTAssertEqual(zones[0].maxY, 40.0 + pill.frame.height + expectedTearPadding)
        // Horizontal extent is left alone: the host is what decides how wide a tear is, because
        // only the host knows how wide its background is.
        XCTAssertEqual(zones[0].minX, pill.frame.minX)
        XCTAssertEqual(zones[0].width, pill.frame.width)
    }

    /// Two runs separated by supported content are two pills, so two separate zones, in order.
    func testEachTopLevelPillProducesItsOwnZone() {
        let zones = unsupportedContentTearZones(in: makeLayout([
            makeUnsupportedItem(y: 40.0),
            makeUnsupportedItem(y: 300.0)
        ]))

        XCTAssertEqual(zones.count, 2)
        XCTAssertLessThan(zones[0].minY, zones[1].minY)
    }

    /// Top level only. A pill nested inside a table (or a <details> body, or a blockquote) is not
    /// full-width relative to the host's background, so a band across it would cut a stripe through
    /// unrelated content.
    func testNestedPillsProduceNoZone() {
        let inner = InstantPageV2Layout(
            contentSize: CGSize(width: 200.0, height: 100.0),
            items: [makeUnsupportedItem(y: 0.0)],
            detailsIndices: []
        )
        let table = InstantPageV2TableItem(
            frame: CGRect(x: 0.0, y: 0.0, width: 320.0, height: 120.0),
            titleSubLayout: inner,
            titleFrame: CGRect(x: 0.0, y: 0.0, width: 320.0, height: 100.0),
            contentSize: CGSize(width: 320.0, height: 20.0),
            contentInset: 17.0,
            cells: [],
            horizontalLines: [],
            verticalLines: [],
            bordered: false,
            striped: false,
            borderColor: .clear
        )

        XCTAssertTrue(unsupportedContentTearZones(in: makeLayout([.table(table)])).isEmpty)
    }

    /// The case not recursing does NOT catch, and the reason `isTopLevel` is carried on the item at
    /// all: a blockquote lays its children out with `layoutBlock` and appends the results straight
    /// into its parent's item array, offset. So a quoted pill sits in `layout.items` looking exactly
    /// like a top-level one, and only the flag tells them apart.
    func testASplicedNestedPillProducesNoZone() {
        let zones = unsupportedContentTearZones(in: makeLayout([
            makeUnsupportedItem(y: 40.0, isTopLevel: false)
        ]))

        XCTAssertTrue(zones.isEmpty)
    }

    /// And a page holding both still tears across the top-level one.
    func testASplicedNestedPillDoesNotSuppressATopLevelOne() {
        let zones = unsupportedContentTearZones(in: makeLayout([
            makeUnsupportedItem(y: 40.0, isTopLevel: false),
            makeUnsupportedItem(y: 300.0, isTopLevel: true)
        ]))

        XCTAssertEqual(zones.count, 1)
        XCTAssertEqual(zones[0].minY, 300.0 - expectedTearPadding)
    }

    /// The overwhelmingly common case: an ordinary page tears nothing.
    func testPagesWithoutUnsupportedBlocksProduceNoZones() {
        XCTAssertTrue(unsupportedContentTearZones(in: makeLayout([])).isEmpty)
    }
}
