import XCTest
import UIKit
@testable import CoreListDemo

/// A full-replace carousel — the shape a chat produces when it jumps from far in the past to a
/// different region of history — must stay one rigid travel between two strips: the outgoing ghost
/// strip and the incoming live strip are adjacent for the whole pass and never overlap.
///
/// The regression these lock down only appeared when the destination window reached a COLLECTION
/// EDGE. A full replace leaves `initialGhostWitness` no surviving predecessor, so it falls through to
/// `newItems[0]` (or `newItems.last`), which becomes a resolvable boundary witness exactly when that
/// row is loaded — giving the departed strip a second vertical owner that walks it onto the incoming
/// one while the shared viewport track carries both. A jump to a mid-collection target leaves both
/// edge rows unloaded, so the witness stays `.unresolved` and the travel is rigid; that is why the
/// existing carousel suites never saw it. `ProgrammaticScrollAnimationTests` asserts strip adjacency
/// but keeps the same collection (old rows become viewport carries, not ghost blocks), and
/// `CarouselFadeSuppressionTests` does full replaces but only asserts opacity, always at index 50.
final class FullReplaceCarouselStripSeparationTests: XCTestCase {
    private final class Item: CoreListItem {
        let id: Int

        var identity: AnyHashable { id }

        init(id: Int) { self.id = id }

        func view() -> UIView & CoreListItemView { FixedHeightItemView(height: 50) }

        func isEqual(to other: CoreListItem) -> Bool { (other as? Item)?.id == id }
    }

    private func makeFixture() -> VirtualListFixture {
        VirtualListFixture(viewport: CGSize(width: 390, height: 300),
                           items: (0..<200).map { Item(id: $0) },
                           preloadMargin: 100)
    }

    /// Settle far away from either collection edge, then replace the whole collection under an
    /// explicit `scrollTo` — the two loaded windows share no identity, which is what makes the pass
    /// a carousel.
    private func fullReplaceCarousel(_ fixture: VirtualListFixture,
                                     to targetIndex: Int,
                                     direction: CoreListScrollTarget.Direction,
                                     duration: TimeInterval) {
        fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                      transition: .easeInOut(duration: 0))
        let replacement: [CoreListItem] = (1000..<1200).map { Item(id: $0) }
        fixture.listView.applyChanges(
            items: replacement,
            scrollTo: .init(index: targetIndex, direction: direction, resolve: { _, _ in 0 }),
            transition: .easeInOut(duration: duration)
        )
    }

    private func liveStrip(_ fixture: VirtualListFixture) -> ClosedRange<CGFloat>? {
        let frames = fixture.activeWindow.items.compactMap {
            fixture.screenFrame(forIndex: $0.index)
        }
        guard let minY = frames.map(\.minY).min(),
              let maxY = frames.map(\.maxY).max() else { return nil }
        return minY...maxY
    }

    private func ghostStrip(_ fixture: VirtualListFixture) -> ClosedRange<CGFloat>? {
        let frames = fixture.ghostMemberViews.compactMap { view -> CGRect? in
            guard let y = fixture.driver.exitScreenY(view: view) else { return nil }
            return CGRect(x: 0, y: y, width: view.bounds.width, height: view.bounds.height)
        }
        guard let minY = frames.map(\.minY).min(),
              let maxY = frames.map(\.maxY).max() else { return nil }
        return minY...maxY
    }

    /// Samples the two strips across the travel and fails on any overlap. Stops once the ghosts are
    /// torn down at the deadline — there is nothing left to intersect after that.
    private func assertStripsStayDisjoint(_ fixture: VirtualListFixture,
                                          duration: TimeInterval,
                                          file: StaticString = #filePath,
                                          line: UInt = #line) throws {
        let step = duration / 8
        var sampled = 0
        for _ in 0..<8 {
            guard let ghost = ghostStrip(fixture) else { break }
            let live = try XCTUnwrap(liveStrip(fixture), file: file, line: line)
            let overlap = min(live.upperBound, ghost.upperBound)
                - max(live.lowerBound, ghost.lowerBound)
            XCTAssertLessThanOrEqual(
                overlap, 1e-6,
                "outgoing ghost strip \(ghost) overlaps incoming live strip \(live)",
                file: file, line: line
            )
            sampled += 1
            fixture.tick(dt: step)
        }
        XCTAssertGreaterThan(sampled, 1, "the travel was never observed with ghosts on screen",
                             file: file, line: line)
    }

    /// A chat's "jump to now": the destination window starts at collection index 0, so the witness
    /// `initialGhostWitness` proposes is loaded and used to resolve.
    func testBackwardCarouselToTheFirstIndexKeepsStripsDisjoint() throws {
        let fixture = makeFixture()
        fullReplaceCarousel(fixture, to: 0, direction: .backward, duration: 2)
        try assertStripsStayDisjoint(fixture, duration: 2)
    }

    /// The mirror: a jump to the far end of the collection loads the last row, which
    /// `initialGhostWitness` proposes through its `ordinal == newItems.count` branch.
    func testForwardCarouselToTheLastIndexKeepsStripsDisjoint() throws {
        let fixture = makeFixture()
        fullReplaceCarousel(fixture, to: 199, direction: .forward, duration: 2)
        try assertStripsStayDisjoint(fixture, duration: 2)
    }

    /// The case that always worked, kept as the control: neither collection edge is loaded.
    func testCarouselToAMidCollectionTargetKeepsStripsDisjoint() throws {
        let fixture = makeFixture()
        fullReplaceCarousel(fixture, to: 100, direction: .backward, duration: 2)
        try assertStripsStayDisjoint(fixture, duration: 2)
    }

    /// The mechanism itself, so a regression names its own cause rather than reporting geometry.
    /// The viewport track is the carousel's sole vertical owner; a ghost block must not hold one.
    func testCarouselGhostBlocksTakeNoWitnessAndNoPositionTrack() throws {
        for target in [0, 100, 199] {
            let fixture = makeFixture()
            fullReplaceCarousel(fixture, to: target,
                                direction: target == 199 ? .forward : .backward,
                                duration: 2)

            XCTAssertFalse(fixture.ghostBlocks.isEmpty, "target \(target)")
            for block in fixture.ghostBlocks {
                XCTAssertEqual(block.witness, .unresolved, "target \(target)")
                XCTAssertNil(fixture.ghostBlockTrack(block.id), "target \(target)")
            }
            XCTAssertNotNil(fixture.viewportTrack, "target \(target)")
        }
    }
}
