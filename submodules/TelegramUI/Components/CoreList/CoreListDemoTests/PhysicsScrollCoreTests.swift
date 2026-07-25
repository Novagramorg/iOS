import XCTest
import UIKit
@testable import CoreListDemo

final class PhysicsScrollCoreTests: XCTestCase {

    private func makeCore(viewport: CGSize = CGSize(width: 390, height: 800)) -> (PhysicsScrollCore, UIView) {
        let host = UIView(frame: CGRect(origin: .zero, size: viewport))
        let core = PhysicsScrollCore(contentHost: host)
        return (core, host)
    }

    func test_setOffset_writesHostBounds_doesNotFireOnScroll() {
        let (core, host) = makeCore()
        var fired: [CGFloat] = []
        core.onScroll = { fired.append($0) }
        core.setOffset(120)
        XCTAssertEqual(host.bounds.origin.y, 120, accuracy: 0.001)
        XCTAssertEqual(core.offset, 120, accuracy: 0.001)
        XCTAssertTrue(fired.isEmpty, "programmatic setOffset must not fire onScroll")
    }

    func test_applyShift_addsToOffset_doesNotFireOnScroll() {
        let (core, host) = makeCore()
        core.setOffset(100)
        var fired: [CGFloat] = []
        core.onScroll = { fired.append($0) }
        core.applyShift(30)
        XCTAssertEqual(host.bounds.origin.y, 130, accuracy: 0.001)
        XCTAssertTrue(fired.isEmpty, "programmatic applyShift must not fire onScroll")
    }

    func test_drag_firesOnScroll_andMovesOffset() {
        let (core, _) = makeCore()
        var fired: [CGFloat] = []
        core.onScroll = { fired.append($0) }
        core.beginDrag()
        core.drag(translation: -100, velocity: -800)   // finger up → offset increases
        XCTAssertGreaterThan(core.offset, 0, "dragging up increases the offset")
        XCTAssertFalse(fired.isEmpty, "drag fires onScroll")
        XCTAssertEqual(fired.last!, core.offset, accuracy: 0.001)
    }

    func test_openEdges_freeFlick_decelerates_andSettles() {
        let (core, _) = makeCore()
        core.setEdges(min: nil, max: nil)               // neither edge loaded → free travel both ways
        core.beginDrag()
        core.drag(translation: 0, velocity: -3000)
        core.drag(translation: 0, velocity: -3000)
        XCTAssertTrue(core.endDrag(), "a flick decelerates")
        XCTAssertTrue(core.isDecelerating)

        var settled = false
        for _ in 0..<600 where !settled { settled = core.step(dtMs: 1000.0 / 60) }
        XCTAssertTrue(settled, "free flick settles when velocity dies")
        XCTAssertGreaterThan(core.offset, 100, "it coasted forward a meaningful distance")
        XCTAssertFalse(core.isDecelerating)
    }

    func test_cancelDeceleration_stopsDecel_withoutMovingOffset() {
        let (core, _) = makeCore()
        core.setEdges(min: nil, max: nil)
        core.beginDrag()
        core.drag(translation: 0, velocity: -3000)
        core.drag(translation: 0, velocity: -3000)
        XCTAssertTrue(core.endDrag())
        _ = core.step(dtMs: 1000.0 / 60)
        XCTAssertTrue(core.isDecelerating)

        let offsetBefore = core.offset
        core.cancelDeceleration()
        XCTAssertFalse(core.isDecelerating, "deceleration cancelled")
        XCTAssertEqual(core.offset, offsetBefore, accuracy: 0.001, "content held where it caught")
    }

    func test_containerOrigin_parksAtNaturalBaseZero() {
        let (core, _) = makeCore()
        let h: CGFloat = 1000
        XCTAssertEqual(core.containerOrigin(windowHeight: h, topLoaded: true, bottomLoaded: false), 0, accuracy: 0.001)
        XCTAssertEqual(core.containerOrigin(windowHeight: h, topLoaded: true, bottomLoaded: true), 0, accuracy: 0.001)
        XCTAssertEqual(core.containerOrigin(windowHeight: h, topLoaded: false, bottomLoaded: true), -h, accuracy: 0.001)
        XCTAssertEqual(core.containerOrigin(windowHeight: h, topLoaded: false, bottomLoaded: false), -h / 2, accuracy: 0.001)
    }

    func test_bakeTrajectory_fromFlick_settles() {
        let (core, _) = makeCore()
        core.setEdges(min: nil, max: nil)              // free travel both ways
        core.beginDrag()
        core.drag(translation: 0, velocity: -3000)
        core.drag(translation: 0, velocity: -3000)
        XCTAssertTrue(core.endDrag())
        let traj = core.bakeTrajectory()
        XCTAssertGreaterThan(traj.duration, 0)
        XCTAssertGreaterThan(traj.finalOffset, 100, "coasted forward")
    }

    func test_reseedDeceleration_reAnchors_andBakesFromThere() {
        let (core, _) = makeCore()
        core.setEdges(min: nil, max: nil)
        core.reseedDeceleration(offset: 500, velocity: 2.0)   // 2.0 pts/ms
        let traj = core.bakeTrajectory()
        XCTAssertEqual(traj.samples.first!.offset, 500, accuracy: 0.5, "bakes from the reseeded offset")
        XCTAssertGreaterThan(traj.finalOffset, 500, "continues forward from the reseeded state")
    }

    func test_loadedTopEdge_overscrollDrag_rubberBands_andSpringsBack() {
        let (core, _) = makeCore()
        core.setEdges(min: 0, max: nil)                 // top loaded at offset 0, bottom open
        core.beginDrag()
        core.drag(translation: 200, velocity: 400)      // finger down past the top → offset < 0, resisted
        XCTAssertLessThan(core.offset, 0, "overscrolled past the top")
        XCTAssertGreaterThan(core.offset, -200, "rubber-band resisted (less than the raw 200)")
        XCTAssertTrue(core.endDrag(), "released while overscrolled → spring back")

        var settled = false
        for _ in 0..<600 where !settled { settled = core.step(dtMs: 1000.0 / 60) }
        XCTAssertTrue(settled)
        XCTAssertEqual(core.offset, 0, accuracy: 0.5, "sprang back to the top edge")
    }

    func test_resumeBounceIfOverscrolled_fromOverscrolledIdle_springsBackToEdge() {
        // Simulate the engine's trackpad-finger-rest catch: physics is .idle (cancelDeceleration was
        // called) but the offset is left overscrolled. resumeBounceIfOverscrolled is the engine's lift
        // handler — it must put the core into .decelerating and spring back to the edge.
        let (core, _) = makeCore()
        core.setEdges(min: 0, max: nil)              // top loaded at offset 0, bottom open
        core.setOffset(-40)                          // overscrolled 40pt past the top, .idle
        XCTAssertFalse(core.isDecelerating, "precondition: idle")
        XCTAssertTrue(core.isOverscrolled, "precondition: overscrolled")

        XCTAssertTrue(core.resumeBounceIfOverscrolled(), "overscrolled idle → decelerating (spring back)")
        XCTAssertTrue(core.isDecelerating)

        var settled = false
        for _ in 0..<600 where !settled { settled = core.step(dtMs: 1000.0 / 60) }
        XCTAssertTrue(settled)
        XCTAssertEqual(core.offset, 0, accuracy: 0.5, "sprang back to the top edge")
    }

    func test_resumeBounceIfOverscrolled_withinEdges_isNoOp() {
        // A trackpad lift on non-overscrolled content must NOT spuriously start a deceleration.
        let (core, _) = makeCore()
        core.setEdges(min: 0, max: 1000)
        core.setOffset(200)                          // well within edges
        XCTAssertFalse(core.isOverscrolled, "precondition: within edges")

        XCTAssertFalse(core.resumeBounceIfOverscrolled(), "within edges: nothing to resume")
        XCTAssertFalse(core.isDecelerating)
        XCTAssertEqual(core.offset, 200, accuracy: 0.001, "offset is unchanged")
    }

    func test_trackpadCoefficient_loosensOverscrollRubberBand_andSpringsBack() {
        // Touch core: default coefficient (0.55).
        let (touch, _) = makeCore()
        touch.setEdges(min: 0, max: nil)                 // top loaded at offset 0, bottom open
        touch.beginDrag()
        touch.drag(translation: 200, velocity: 400)      // finger down past the top → offset < 0, resisted

        // Trackpad core: same geometry/drag, but the looser indirect coefficient (0.715).
        let (trackpad, _) = makeCore()
        trackpad.updateRubberBandCoefficient(RubberBand.trackpadCoefficient)   // BEFORE beginDrag → makePhysics uses it
        trackpad.setEdges(min: 0, max: nil)
        trackpad.beginDrag()
        trackpad.drag(translation: 200, velocity: 400)

        XCTAssertLessThan(touch.offset, 0, "touch overscrolled past the top")
        XCTAssertLessThan(trackpad.offset, 0, "trackpad overscrolled past the top")
        XCTAssertLessThan(trackpad.offset, touch.offset,
                          "trackpad's looser rubber-band (0.715 > 0.55) resists less → further overscroll")

        // The looser drag still springs back to the edge (spring-back is c-independent).
        XCTAssertTrue(trackpad.endDrag(), "released while overscrolled → spring back")
        var settled = false
        for _ in 0..<600 where !settled { settled = trackpad.step(dtMs: 1000.0 / 60) }
        XCTAssertTrue(settled)
        XCTAssertEqual(trackpad.offset, 0, accuracy: 0.5, "sprang back to the top edge")
    }
}
