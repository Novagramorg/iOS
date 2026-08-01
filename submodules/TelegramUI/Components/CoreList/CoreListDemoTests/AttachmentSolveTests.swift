import XCTest
@testable import CoreListDemo

final class AttachmentSolveTests: XCTestCase {
    /// Frame-space band [100, 200] for a 30pt attachment; screen anchor 0 (a zero top inset);
    /// contentBase 0, so frame space and screen space differ only by the offset.
    private func map(edge: CoreListAttachmentEdge,
                     isFloating: Bool = true,
                     bandTop: CGFloat = 100,
                     bandBottom: CGFloat = 200,
                     height: CGFloat = 30,
                     anchor: CGFloat = 0,
                     contentBase: CGFloat = 0) -> AttachmentOffsetMap {
        AttachmentOffsetMap(bandTop: bandTop,
                            bandBottom: bandBottom,
                            height: height,
                            anchor: anchor,
                            contentBase: contentBase,
                            edge: edge,
                            isFloating: isFloating)
    }

    func testNonFloatingTopSitsAtBandTopRegardlessOfOffset() {
        let m = map(edge: .top, isFloating: false)
        XCTAssertEqual(m.y(atOffset: 0), 100, accuracy: 1e-9)
        XCTAssertEqual(m.y(atOffset: 500), 100, accuracy: 1e-9)
    }

    func testNonFloatingBottomSitsAtBandBottomMinusHeight() {
        let m = map(edge: .bottom, isFloating: false)
        XCTAssertEqual(m.y(atOffset: 0), 170, accuracy: 1e-9)
        XCTAssertEqual(m.y(atOffset: 500), 170, accuracy: 1e-9)
    }

    func testFloatingTopRidesContentThenParksThenIsPushedOut() {
        let m = map(edge: .top)
        // Run far below the anchor: attachment sits at the band top and rides content.
        XCTAssertEqual(m.y(atOffset: 50), 100, accuracy: 1e-9)
        // Anchor inside the band: parked, so frame-space y tracks the offset.
        XCTAssertEqual(m.y(atOffset: 130), 130, accuracy: 1e-9)
        // Anchor past hi: pushed out, pinned at hi.
        XCTAssertEqual(m.y(atOffset: 250), 170, accuracy: 1e-9)
    }

    func testFloatingBottomIsPushedOutAtBandTop() {
        // For .bottom the anchor is displayBottom - h; model that with anchor = 500.
        let m = map(edge: .bottom, anchor: 500)
        // Large offset drags the band up past the anchor: pinned at hi.
        XCTAssertEqual(m.y(atOffset: 400), 170, accuracy: 1e-9)
        // Anchor inside the band: parked.
        XCTAssertEqual(m.y(atOffset: -350), 150, accuracy: 1e-9)
        // Band entirely above the anchor: pinned at lo.
        XCTAssertEqual(m.y(atOffset: -450), 100, accuracy: 1e-9)
    }

    func testBreakpointsAreWhereTheAnchorCrossesTheBandLimits() {
        let m = map(edge: .top)
        // anchorFrame(offset) = anchor + offset - contentBase = offset.
        XCTAssertEqual(m.lowBreakpoint!, 100, accuracy: 1e-9)
        XCTAssertEqual(m.highBreakpoint!, 170, accuracy: 1e-9)
        // Evaluating exactly at a breakpoint agrees with both neighbouring segments.
        XCTAssertEqual(m.y(atOffset: m.lowBreakpoint!), 100, accuracy: 1e-9)
        XCTAssertEqual(m.y(atOffset: m.highBreakpoint!), 170, accuracy: 1e-9)
    }

    func testNonFloatingMapHasNoBreakpoints() {
        let m = map(edge: .top, isFloating: false)
        XCTAssertNil(m.lowBreakpoint)
        XCTAssertNil(m.highBreakpoint)
    }

    /// THE degenerate case. A band shorter than the attachment inverts the clamp, and the two edges
    /// resolve it differently: the FAR edge wins in both. This is the asymmetry that makes `.bottom`
    /// not a naive mirror of `.top` — see ListView.swift:4019 vs :4032.
    func testDegenerateShortRunResolvesToTheFarEdge() {
        // Band [100, 120] for a 30pt attachment: hi = 90 < lo = 100.
        let top = map(edge: .top, bandBottom: 120)
        let bottom = map(edge: .bottom, bandBottom: 120, anchor: 500)
        for offset in stride(from: CGFloat(-400), through: 400, by: 50) {
            XCTAssertEqual(top.y(atOffset: offset), 90, accuracy: 1e-9,
                           "top must resolve to hi at offset \(offset)")
            XCTAssertEqual(bottom.y(atOffset: offset), 100, accuracy: 1e-9,
                           "bottom must resolve to lo at offset \(offset)")
        }
    }
}
