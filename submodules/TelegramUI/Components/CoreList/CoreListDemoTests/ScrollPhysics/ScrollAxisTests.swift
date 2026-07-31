import XCTest
import CoreGraphics
import Foundation
@testable import CoreListDemo

final class ScrollAxisTests: XCTestCase {
    private func makeAxis(offset: CGFloat = 0) -> ScrollAxis {
        ScrollAxis(offset: offset, min: 0, max: 1000, range: 400,
                   rate: 0.998, scale: 2, vScale: 1)
    }

    func testDragMapsOffsetToStartMinusTranslation() {
        var a = makeAxis()
        a.beginDrag()
        a.drag(translation: -100, recognizerVelocity: 0)   // offset = 0 − (−100) = 100
        XCTAssertEqual(a.offset, 100, accuracy: 1e-9)
    }

    func testDragPastTopRubberBands() {
        var a = makeAxis()
        a.beginDrag()
        a.drag(translation: 50, recognizerVelocity: 0)     // proposed = −50 → rubber-band
        XCTAssertEqual(a.offset, -25.7307, accuracy: 1e-3) // −400·(1−1/(1+0.55·50/400))
    }

    func testEndDragFiltersVelocityAndDeceleratesAboveThreshold() {
        var a = makeAxis()
        a.beginDrag()
        a.drag(translation: 0, recognizerVelocity: -1000)  // velocity = 1.0, prev = 0
        a.drag(translation: 0, recognizerVelocity: -2000)  // prev = 1.0, velocity = 2.0
        XCTAssertEqual(a.endDrag(), .decelerate)
        XCTAssertEqual(a.velocity, 1.25, accuracy: 1e-9)   // 0.75·prev(1.0) + 0.25·latest(2.0)
    }

    func testEndDragBelowThresholdStops() {
        var a = makeAxis()
        a.beginDrag()
        a.drag(translation: 0, recognizerVelocity: -100)   // velocity = 0.1, prev = 0
        XCTAssertEqual(a.endDrag(), .stop)                 // (0.75·0.1 + 0.25·0)² = 0.005625 < 0.0625
        XCTAssertEqual(a.velocity, 0, accuracy: 1e-9)
    }

    /// Releasing while overscrolled must spring back even with no flick velocity — otherwise a tap or
    /// tiny drag during a bounce ends as `.stop` and the content freezes off the edge.
    func testEndDragInOverscrollDeceleratesEvenBelowThreshold() {
        var a = ScrollAxis(offset: 1100, min: 0, max: 1000, range: 400,   // 100px past the bottom edge
                           rate: 0.998, scale: 2, vScale: 1)
        a.beginDrag()                                       // no drag → velocity 0 (below threshold)
        XCTAssertEqual(a.endDrag(), .decelerate)            // must bounce back, NOT .stop
        let before = a.offset
        _ = a.step(dtMs: 16.667)
        XCTAssertLessThan(a.offset, before)                 // springs toward the edge
        XCTAssertGreaterThan(a.offset, 1000)                // ...monotonically, not past it
    }

    func testStepReturnsPixelRoundedWrittenOffset() {
        var a = makeAxis()
        a.beginDrag()
        a.drag(translation: 0, recognizerVelocity: -2000)  // velocity = 2.0
        a.drag(translation: 0, recognizerVelocity: -2000)
        _ = a.endDrag()
        let (written, settled) = a.step(dtMs: 16.667)
        XCTAssertFalse(settled)
        XCTAssertGreaterThan(written, 0)                                       // moved forward
        // written lands on the 1/scale grid (scale 2 → multiples of 0.5)
        XCTAssertEqual(written.truncatingRemainder(dividingBy: 0.5), 0, accuracy: 1e-9)
        // ...while the internal offset keeps full precision (proves rounding actually occurred)
        XCTAssertNotEqual(written, a.offset)
    }

    func testTwoAxisPhysicsDragsBothIndependently() {
        var p = ScrollPhysics(
            x: ScrollAxis(offset: 0, min: 0, max: 500, range: 300, rate: 0.998, scale: 2, vScale: 1),
            y: ScrollAxis(offset: 0, min: 0, max: 1000, range: 400, rate: 0.998, scale: 2, vScale: 1))
        p.beginDrag()
        p.drag(translation: CGPoint(x: -30, y: -60), recognizerVelocity: .zero)
        XCTAssertEqual(p.x.offset, 30, accuracy: 1e-9)
        XCTAssertEqual(p.y.offset, 60, accuracy: 1e-9)
    }

    func testTwoAxisEndDragForwardsToBothAxes() {
        var p = ScrollPhysics(
            x: ScrollAxis(offset: 0, min: 0, max: 500, range: 300, rate: 0.998, scale: 2, vScale: 1),
            y: ScrollAxis(offset: 0, min: 0, max: 1000, range: 400, rate: 0.998, scale: 2, vScale: 1))
        p.beginDrag()
        // x slow (rv −50 → 0.05 pts/ms), y fast (rv −2000 → 2.0 pts/ms)
        p.drag(translation: .zero, recognizerVelocity: CGPoint(x: -50, y: -2000))
        let decision = p.endDrag()
        XCTAssertEqual(decision.x, .stop)        // (0.75·0.05)² = 0.0014 < 0.0625
        XCTAssertEqual(decision.y, .decelerate)  // (0.75·2.0)²  = 2.25  > 0.0625
    }
}
