import XCTest
import UIKit
@testable import CoreListDemo

final class KeyframeFlightTests: XCTestCase {

    private func makeCoreFlung(viewport: CGSize = CGSize(width: 390, height: 800), startTime: TimeInterval = 0)
        -> (PhysicsScrollCore, KeyframeFlight) {
        let host = UIView(frame: CGRect(origin: .zero, size: viewport))
        let core = PhysicsScrollCore(contentHost: host)
        core.setEdges(min: nil, max: nil)
        core.beginDrag()
        core.drag(translation: 0, velocity: -3000)
        core.drag(translation: 0, velocity: -3000)
        _ = core.endDrag()
        let flight = KeyframeFlight(core: core, startTime: startTime)
        return (core, flight)
    }

    func test_liveOffset_advancesAlongTrajectory() {
        let (_, flight) = makeCoreFlung()
        let o0 = flight.liveOffset(now: 0)
        let o1 = flight.liveOffset(now: 0.1)
        XCTAssertGreaterThan(o1, o0, "coasts forward")
        XCTAssertLessThanOrEqual(flight.liveOffset(now: flight.duration + 1), flight.trajectory.finalOffset + 0.5)
    }

    func test_isComplete_atDuration() {
        let (_, flight) = makeCoreFlung()
        XCTAssertFalse(flight.isComplete(now: 0))
        XCTAssertTrue(flight.isComplete(now: flight.duration + 0.001))
    }

    func test_noRebakeWhenNoCoordinateChange() {
        let (_, flight) = makeCoreFlung()
        let before = flight.generation
        flight.beginTick(now: 0.1)
        // no noteShift / noteEdgesChanged this tick
        let did = flight.rebakeIfNeeded(now: 0.1)
        XCTAssertFalse(did)
        XCTAssertEqual(flight.generation, before, "no rebake → generation unchanged")
    }

    func test_shift_showsInLiveOffsetImmediately() {
        let (core, flight) = makeCoreFlung()
        flight.beginTick(now: 0.1)
        let preShift = flight.liveOffset(now: 0.1)
        core.applyShiftPhysicsOnly(120)   // the engine routes applyShift → core + flight.noteShift
        flight.noteShift(120)
        XCTAssertEqual(flight.liveOffset(now: 0.1), preShift + 120, accuracy: 0.5,
                       "the re-base shows up in the live offset immediately (and persists)")
    }

    func test_shift_doesNotRebake_butIsCarriedContinuously() {
        // A pure coordinate shift is a rigid translation — the engine slides the layer model so the
        // in-flight animation rides along, so the flight must NOT rebake (no re-emit). Re-emitting on
        // every shift — which happens every frame at scroll speed — was the residual jank.
        let (core, flight) = makeCoreFlung()
        let gen0 = flight.generation
        flight.beginTick(now: 0.2)
        let liveBefore = flight.liveOffset(now: 0.2)
        core.applyShiftPhysicsOnly(200); flight.noteShift(200)   // re-base +200
        XCTAssertFalse(flight.rebakeIfNeeded(now: 0.2), "a pure shift does not rebake")
        XCTAssertEqual(flight.generation, gen0, "no rebake → generation unchanged")
        // The shift shows up in the live offset immediately...
        XCTAssertEqual(flight.liveOffset(now: 0.2), liveBefore + 200, accuracy: 0.6)
        // ...and PERSISTS across the tick boundary, with the trajectory still coasting forward (a small
        // decel delta, not a shift-sized jump).
        let next = flight.liveOffset(now: 0.2 + 1.0/60)
        XCTAssertLessThan(abs(next - flight.liveOffset(now: 0.2)), 60)
        XCTAssertGreaterThan(next, liveBefore + 200 - 1, "the +200 re-base persists across ticks")
    }

    func test_shift_isVelocityInvariant() {
        let (core, flight) = makeCoreFlung()
        flight.beginTick(now: 0.2)
        let velBefore = flight.liveVelocity(now: 0.2)
        core.applyShiftPhysicsOnly(200); flight.noteShift(200)
        XCTAssertFalse(flight.rebakeIfNeeded(now: 0.2))   // pure shift → no rebake
        // Velocity is shift-invariant — a rigid re-base moves position only.
        XCTAssertEqual(flight.liveVelocity(now: 0.2), velBefore, accuracy: 0.05)
    }

    func test_rebakeOnEdgeChange_springsBackToNewBottomEdge() {
        // Flick down with a far-away bottom, then mid-flight load a real bottom edge → rebake must
        // bake a spring-back to that edge.
        let host = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 390, height: 800)))
        let core = PhysicsScrollCore(contentHost: host)
        core.setEdges(min: nil, max: nil)
        core.beginDrag(); core.drag(translation: 0, velocity: -6000); core.drag(translation: 0, velocity: -6000)
        _ = core.endDrag()
        let flight = KeyframeFlight(core: core, startTime: 0)
        flight.beginTick(now: 0.05)
        let live = flight.liveOffset(now: 0.05)
        core.setEdges(min: nil, max: live + 10)   // a bottom edge just ahead
        flight.noteEdgesChanged()
        XCTAssertTrue(flight.rebakeIfNeeded(now: 0.05))
        // The rebaked path settles at/near the new bottom edge, not far past it.
        XCTAssertLessThanOrEqual(flight.trajectory.finalOffset, live + 11)
    }

    func testEdgeChangeBeforeNextBeginTickRemainsPendingUntilRebake() {
        let (core, flight) = makeCoreFlung()
        flight.beginTick(now: 0.05)
        XCTAssertFalse(flight.rebakeIfNeeded(now: 0.05))

        let nextNow: TimeInterval = 0.1
        let newMax = flight.liveOffset(now: nextNow) + 10
        XCTAssertTrue(core.setEdges(min: nil, max: newMax))
        flight.noteEdgesChanged()

        flight.beginTick(now: nextNow)

        XCTAssertTrue(flight.rebakeIfNeeded(now: nextNow))
        XCTAssertEqual(flight.generation, 1)
        XCTAssertLessThanOrEqual(flight.trajectory.finalOffset, newMax + 1)
    }

    func testMultipleEdgeChangesBeforeTickCoalesceAgainstLatestBounds() {
        let (core, flight) = makeCoreFlung()
        let nextNow: TimeInterval = 0.1
        let live = flight.liveOffset(now: nextNow)

        XCTAssertTrue(core.setEdges(min: nil, max: live + 200))
        flight.noteEdgesChanged()
        XCTAssertTrue(core.setEdges(min: nil, max: live + 10))
        flight.noteEdgesChanged()

        flight.beginTick(now: nextNow)

        XCTAssertTrue(flight.rebakeIfNeeded(now: nextNow))
        XCTAssertEqual(flight.generation, 1)
        XCTAssertLessThanOrEqual(flight.trajectory.finalOffset, live + 11)
    }
}
