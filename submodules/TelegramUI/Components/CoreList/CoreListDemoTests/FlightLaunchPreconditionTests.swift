import XCTest
import UIKit
@testable import CoreListDemo

/// `KeyframeFlight` asserts it is built from a core in `.decelerating` state, and
/// `PhysicsScrollEngine.launchFlight` is the only production site that builds one. Between
/// `endDrag` returning `.decelerate` and that construction sits `applyDecelerationHandOff` — a REAL
/// integration frame, so it can also END the deceleration it was handed. Two releases decelerate
/// with no motion left to spend, and both settle inside that one step:
///
/// - the low-pass cancels. The decelerate/stop threshold reads the RAW latest sample and the
///   0.75/0.25 blend runs AFTER it, so a finger that reverses just before lifting releases above the
///   threshold at a blended velocity of ~0 — below the integrator's own `velocityFloor`;
/// - a release while overscrolled by less than `Deceleration.settleTolerance`, which springs back
///   inside the tolerance in one frame.
///
/// Both reached `KeyframeFlight(core:)` with the core already back at `.idle`.
final class FlightLaunchPreconditionTests: XCTestCase {

    private func makeKeyframeEngine() -> PhysicsScrollEngine {
        let engine = PhysicsScrollEngine()
        engine.contentHost.bounds.size = CGSize(width: 390, height: 844)
        engine.decelerationMode = .keyframe
        engine.setEdges(min: nil, max: nil)
        return engine
    }

    private func pan(_ engine: PhysicsScrollEngine, _ state: UIGestureRecognizer.State,
                     translation: CGFloat, velocity: CGFloat) {
        engine.applyPanUpdate(state: state,
                              translation: CGPoint(x: 0, y: translation),
                              velocity: CGPoint(x: 0, y: velocity),
                              forced: false,
                              isIndirect: false)
    }

    // MARK: - The two releases that decelerate with nothing left to spend

    func test_aReleaseWhoseLowPassCancelsSettlesInsteadOfLaunchingAFlight() {
        let engine = makeKeyframeEngine()
        var published: [ScrollFlight?] = []
        engine.onFlightChanged = { published.append($0) }

        // The finger reverses on its last sample: latest = 0.3 pts/ms clears the 0.25 threshold, and
        // 0.75·(−0.1) + 0.25·(0.3) == 0 is what the release actually carries.
        pan(engine, .began, translation: 5, velocity: 100)
        pan(engine, .changed, translation: -10, velocity: -300)
        let atRelease = engine.offset
        pan(engine, .ended, translation: -10, velocity: -300)

        XCTAssertFalse(engine.isDecelerating, "no motion left — the release settles where it lifted")
        XCTAssertNil(published.compactMap { $0 }.first, "a settled release publishes no flight")
        XCTAssertEqual(engine.offset, atRelease, accuracy: 0.5, "and does not jump")
        engine.tearDown()
    }

    func test_aReleaseOverscrolledInsideTheSettleToleranceSettlesInsteadOfLaunchingAFlight() {
        let engine = makeKeyframeEngine()
        engine.setEdges(min: 0, max: 1000)
        engine.setOffset(10)                         // 10pt short of the top edge
        var published: [ScrollFlight?] = []
        engine.onFlightChanged = { published.append($0) }

        // Drag to the edge and pause before lifting — the everyday way to reach an edge. 10.5pt of
        // finger travel from 10pt out lands 0.5pt past it, which the rubber band compresses to
        // ~0.27pt, and the pause releases below the decelerate threshold. That is `.stop`, but an
        // overscrolled release springs back regardless, so `endDrag` still reports deceleration —
        // for a bounce one hand-off frame brings inside `Deceleration.settleTolerance`.
        pan(engine, .began, translation: 10.5, velocity: 0)
        pan(engine, .ended, translation: 10.5, velocity: 0)

        XCTAssertFalse(engine.isDecelerating, "the spring-back finished inside the hand-off frame")
        XCTAssertNil(published.compactMap { $0 }.first, "a settled release publishes no flight")
        engine.tearDown()
    }

    // MARK: - Non-vacuity

    func test_aRealFlickStillLaunchesAFlight() {
        let engine = makeKeyframeEngine()
        var published: [ScrollFlight?] = []
        engine.onFlightChanged = { published.append($0) }

        pan(engine, .began, translation: -20, velocity: -3000)
        pan(engine, .changed, translation: -60, velocity: -3000)
        pan(engine, .ended, translation: -60, velocity: -3000)

        XCTAssertTrue(engine.isDecelerating)
        XCTAssertNotNil(published.compactMap { $0 }.first, "a real release still flies")
        engine.tearDown()
    }

    // MARK: - Why: the hand-off is an integration frame, and it can settle what it is handed

    func test_theHandOffCanEndTheDecelerationItWasHanded_lowPassCancels() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let core = PhysicsScrollCore(contentHost: host)
        core.setEdges(min: nil, max: nil)
        core.beginDrag()
        core.drag(translation: 5, velocity: 100)
        core.drag(translation: -10, velocity: -300)

        XCTAssertTrue(core.endDrag(recognizerVelocity: -300, at: 0), "raw 0.3 pts/ms clears the threshold")
        XCTAssertTrue(core.isDecelerating, "…so the release installs a deceleration")
        XCTAssertEqual(core.decelerationVelocity, 0, accuracy: 1e-9, "carrying the cancelled blend")

        core.applyDecelerationHandOff(frameMs: 1000.0 / 120.0 * 0.5)
        XCTAssertFalse(core.isDecelerating, "one integration frame settles it — the flight's precondition is gone")
    }

    func test_theHandOffCanEndTheDecelerationItWasHanded_aBounceAlreadyInsideTheTolerance() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let core = PhysicsScrollCore(contentHost: host)
        core.setEdges(min: 0, max: 1000)
        core.setOffset(10)
        core.beginDrag()
        core.drag(translation: 10.5, velocity: 0)          // 0.5pt past the edge, banded to ~0.27pt
        XCTAssertTrue(core.isOverscrolled)

        XCTAssertTrue(core.endDrag(recognizerVelocity: 0, at: 0), "an overscrolled release springs back")
        XCTAssertTrue(core.isDecelerating)

        core.applyDecelerationHandOff(frameMs: 1000.0 / 120.0 * 0.5)
        XCTAssertFalse(core.isDecelerating, "the spring landed inside the tolerance in that one frame")
    }

    func test_aBounceRestsPastTheEdgeAtDevicePixelScale_soTheNextTouchReleasesOverscrolled() {
        // Why the overscrolled case is the everyday one and not a corner. The spring's rest is
        // pixel-ROUNDED, and on a 3× device that grid has no vertex at the edge from the outside: every
        // bounce, at every release speed, comes to rest at exactly −1/3 pt. So after ANY bounce the
        // content sits overscrolled inside `settleTolerance`, and the next touch — a tap, a slow drag,
        // any release under the decelerate threshold — springs back from there with nothing to play.
        // (At the tests' default scale 1 it rounds to −0.0 instead, which is why a suite that never
        // sets a device scale cannot see this at all.)
        for v in [800.0, 1500.0, 3000.0, 5000.0] as [CGFloat] {
            let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            let core = PhysicsScrollCore(contentHost: host)
            core.updateScale(3)
            core.setEdges(min: 0, max: 1000)
            core.setOffset(300)
            core.beginDrag()
            core.drag(translation: 100, velocity: v)           // finger down ⇒ content toward the min edge
            core.drag(translation: 200, velocity: v)
            XCTAssertTrue(core.endDrag(recognizerVelocity: v, at: 0))

            XCTAssertEqual(core.bakeTrajectory().finalOffset, -1.0 / 3.0, accuracy: 1e-6,
                           "v=\(v): the bounce rests one device pixel outside the edge")
        }
    }

    func test_aBareTouchOnContentRestingPastTheEdgeSettlesInsideTheHandOff() {
        // The widest form of the same trigger: nothing about the gesture is unusual, the overscroll is
        // already there from the previous bounce. `PhysicsScrollEngine.handleTouchUp` routes a bare tap
        // here, and `endDrag`'s `.stop` branch reaches it for any sub-threshold release.
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let core = PhysicsScrollCore(contentHost: host)
        core.updateScale(3)
        core.setEdges(min: 0, max: 1000)
        core.setOffset(-1.0 / 3.0)                             // where the bounce above left it

        XCTAssertTrue(core.resumeBounceIfOverscrolled(), "still overscrolled ⇒ spring back")
        XCTAssertTrue(core.isDecelerating)

        core.applyDecelerationHandOff(frameMs: 1000.0 / 120.0 * 0.5)
        XCTAssertFalse(core.isDecelerating, "one third of a point springs home in that one frame")
    }
}
