import XCTest
import UIKit
@testable import CoreListDemo

final class TestScrollEngineTests: XCTestCase {

    private func makeEngine(viewport: CGSize = CGSize(width: 390, height: 800))
        -> (TestScrollEngine, SyntheticClock) {
        let clock = SyntheticClock()
        let engine = TestScrollEngine(clock: clock, viewport: viewport)
        return (engine, clock)
    }

    func test_offset_andHost_wired() {
        let (engine, _) = makeEngine()
        XCTAssertEqual(engine.offset, 0, accuracy: 0.001)
        XCTAssertFalse(engine.contentHost is UIScrollView)
    }

    func test_simulateFlick_decelerates_throughTicks_andSettles() {
        let (engine, clock) = makeEngine()
        engine.setEdges(min: nil, max: nil)            // free travel both ways
        var lastReported: CGFloat = 0
        engine.onScroll = { lastReported = $0 }

        engine.simulateFlick(offsetVelocity: 3000)     // +down
        XCTAssertTrue(engine.isDecelerating)

        var ticks = 0
        while engine.isDecelerating && ticks < 600 {
            clock.advance(by: 1.0 / 60)
            engine.tick(dt: 1.0 / 60)
            ticks += 1
        }
        XCTAssertFalse(engine.isDecelerating, "settled within the budget")
        XCTAssertGreaterThan(engine.offset, 100, "coasted forward")
        XCTAssertEqual(lastReported, engine.offset, accuracy: 0.001, "onScroll reported the live offset")
    }

    func test_programmaticSetOffset_doesNotFireOnScroll() {
        let (engine, _) = makeEngine()
        var fired = 0
        engine.onScroll = { _ in fired += 1 }
        engine.setOffset(200)
        XCTAssertEqual(engine.offset, 200, accuracy: 0.001)
        XCTAssertEqual(fired, 0)
    }

    func test_containerOrigin_delegatesToNaturalBase() {
        let (engine, _) = makeEngine()
        let h: CGFloat = 600
        XCTAssertEqual(engine.containerOrigin(windowHeight: h, topLoaded: true, bottomLoaded: false), 0, accuracy: 0.001)
        XCTAssertEqual(engine.containerOrigin(windowHeight: h, topLoaded: true, bottomLoaded: true), 0, accuracy: 0.001)
        XCTAssertEqual(engine.containerOrigin(windowHeight: h, topLoaded: false, bottomLoaded: true), -h, accuracy: 0.001)
        XCTAssertEqual(engine.containerOrigin(windowHeight: h, topLoaded: false, bottomLoaded: false), -h / 2, accuracy: 0.001)
    }

    func test_keyframeMode_flickDecelerates_viaTrajectorySampling_andSettles() {
        let (engine, clock) = makeEngine()
        engine.decelerationMode = .keyframe
        engine.setEdges(min: nil, max: nil)
        var lastReported: CGFloat = 0
        engine.onScroll = { lastReported = $0 }

        engine.simulateFlick(offsetVelocity: 3000)
        XCTAssertTrue(engine.isDecelerating)

        var ticks = 0
        while engine.isDecelerating && ticks < 600 {
            clock.advance(by: 1.0 / 60)
            engine.tick(dt: 1.0 / 60)
            ticks += 1
        }
        XCTAssertFalse(engine.isDecelerating, "settled within budget")
        XCTAssertGreaterThan(engine.offset, 100, "coasted forward")
        XCTAssertEqual(lastReported, engine.offset, accuracy: 0.001, "onScroll reported the final settled offset")
    }

    func test_keyframeEdgeRemovedBetweenTicksRebakesBeforeOldBounce() {
        let (engine, clock) = makeEngine()
        engine.decelerationMode = .keyframe
        engine.setEdges(min: nil, max: 300)
        engine.setOffset(250)
        engine.simulateFlick(offsetVelocity: 1_500)

        engine.setEdges(min: nil, max: nil)

        var ticks = 0
        while engine.isDecelerating && ticks < 600 {
            clock.advance(by: 1.0 / 60)
            engine.tick(dt: 1.0 / 60)
            ticks += 1
        }

        XCTAssertFalse(engine.isDecelerating)
        XCTAssertGreaterThan(engine.offset, 400, "must coast past the removed 300pt bounce edge")
    }

    func test_keyframeShiftWithFiniteEdgeRebakesAgainstFixedEdge() {
        let (engine, clock) = makeEngine()
        engine.decelerationMode = .keyframe
        engine.setEdges(min: 0, max: nil)
        engine.setOffset(50)
        engine.simulateFlick(offsetVelocity: -1_500)

        engine.applyShift(250)
        clock.advance(by: 1.0 / 60)
        engine.tick(dt: 1.0 / 60)

        XCTAssertEqual(engine.keyframeRebakeCount, 1)

        var ticks = 0
        while engine.isDecelerating && ticks < 600 {
            clock.advance(by: 1.0 / 60)
            engine.tick(dt: 1.0 / 60)
            ticks += 1
        }

        XCTAssertFalse(engine.isDecelerating)
        XCTAssertEqual(
            engine.offset,
            0,
            accuracy: 1,
            "must use the fixed finite edge, not the translated old bounce endpoint at 250"
        )
    }

    func test_keyframeShiftWithOpenEdgesRemainsTranslationOnly() {
        let (engine, clock) = makeEngine()
        engine.decelerationMode = .keyframe
        engine.setEdges(min: nil, max: nil)
        engine.setOffset(50)
        engine.simulateFlick(offsetVelocity: 1_500)

        engine.applyShift(250)
        clock.advance(by: 1.0 / 60)
        engine.tick(dt: 1.0 / 60)

        XCTAssertEqual(engine.keyframeRebakeCount, 0)
    }

    func test_keyframePendingFiniteShiftRebakesAcrossOldDeadline() throws {
        let (engine, clock) = makeEngine()
        engine.decelerationMode = .keyframe
        engine.setEdges(min: 0, max: nil)
        engine.setOffset(50)
        engine.simulateFlick(offsetVelocity: -1_500)
        let oldDuration = try XCTUnwrap(engine.keyframeFlightDuration)

        clock.advance(by: oldDuration + 0.001)
        engine.applyShift(250)
        engine.tick(dt: 1.0 / 60)

        XCTAssertEqual(
            engine.keyframeRebakeCount,
            1,
            "pending finite-edge invalidation must outrank the old trajectory deadline"
        )
    }
}
