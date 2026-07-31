import XCTest
@testable import CoreListDemo

final class MixedPassStressOracleTests: XCTestCase {
    func testOracleAcceptsOverlappingStructuralGeometryAndScrollPasses() {
        let initial = (0..<120).map {
            MixedPassItem(
                id: $0,
                height: MixedPassScenario.heights[$0 % MixedPassScenario.heights.count]
            )
        }
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 800),
            items: initial.map { $0 as CoreListItem },
            preloadMargin: 160,
            emitsCA: true
        )
        let oracle = MixedPassStressOracle()
        let before = oracle.capture(fixture: fixture)

        var changed = initial
        changed[0] = MixedPassItem(id: changed[0].id, height: 128)
        let inserted = (200..<205).map {
            MixedPassItem(id: $0, height: 60)
        }
        changed.insert(contentsOf: inserted, at: 5)
        let step = MixedPassStep(
            items: changed,
            size: CGSize(width: 430, height: 874),
            insets: UIEdgeInsets(top: 120, left: 40, bottom: 40, right: 50),
            scrollTo: .init(index: 40, pointOffset: 20),
            transition: .easeInOut(duration: 0.5),
            advanceAfter: 0.05,
            actions: [
                .resize(index: 0, id: 0, from: 44, to: 128),
                .insert(index: 5, ids: Array(200..<205)),
                .scroll(index: 40, pointOffset: 20),
            ]
        )

        fixture.listView.frame.size = step.size
        fixture.listView.applyChanges(
            items: step.items.map { $0 as CoreListItem },
            newSize: step.size,
            newInsets: step.insets,
            scrollTo: step.scrollTo,
            transition: step.transition
        )
        let after = oracle.capture(fixture: fixture)

        oracle.assertBoundary(
            before: before,
            after: after,
            step: step,
            context: "focused"
        )
        oracle.assertWindow(fixture: fixture, context: "focused")
        oracle.assertInstalledAnimations(fixture: fixture, context: "focused")

        _ = fixture.runUntilSettled(max: 2)
        oracle.assertSettled(fixture: fixture, context: "focused")
    }

    func testOracleDetectsMissingInstalledAnimation() {
        let track = ListAnimationTrack(
            generation: 7,
            from: 20,
            to: 0,
            startTime: 1,
            duration: 0.5,
            curve: .linear
        )

        XCTAssertThrowsError(
            try MixedPassStressOracle.validateTrack(
                expected: track,
                animation: nil,
                property: .positionY
            )
        )
    }

    func testSettlementCheckpointReapsTracksAlreadyPastTheirDeadline() {
        let initial = (0..<20).map {
            MixedPassItem(id: $0, height: 60)
        }
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 800),
            items: initial.map { $0 as CoreListItem },
            emitsCA: true
        )
        fixture.listView.applyChanges(
            items: Array(initial.dropFirst()).map { $0 as CoreListItem },
            transition: .easeInOut(duration: 0.1)
        )
        fixture.clock.advance(by: 0.2)

        XCTAssertFalse(fixture.hasActiveAnimations)
        XCTAssertFalse(fixture.ghostBlocks.isEmpty)

        MixedPassStressOracle().settle(fixture: fixture, max: 1)

        XCTAssertTrue(fixture.ghostBlocks.isEmpty)
        XCTAssertTrue(fixture.crossingCarryIdentities.isEmpty)
    }
}
