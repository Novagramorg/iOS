import XCTest
@testable import TONWalletKit

/// Verifies the durable event queue.
///
/// Durability is the point: a dApp request arrives over the bridge and may sit unanswered
/// while the user is elsewhere or the app is killed. Losing one means the dApp waits forever
/// for a reply that never comes, so these tests lean hard on restart and crash behaviour.
final class EventStoreTests: XCTestCase {
    /// A controllable clock, so timeout behaviour is tested without sleeping.
    final class TestClock: @unchecked Sendable {
        private let lock = NSLock()
        private var millis: Int64 = 1_700_000_000_000

        var now: Int64 {
            lock.lock(); defer { lock.unlock() }
            return millis
        }

        func advance(seconds: TimeInterval) {
            lock.lock(); millis += Int64(seconds * 1000); lock.unlock()
        }

        var reader: @Sendable () -> Int64 {
            { [self] in self.now }
        }
    }

    private func makeStore(
        storage: any WalletKitStorage = InMemoryStorage(),
        config: DurableEventsConfig = .default,
        clock: TestClock = TestClock()
    ) -> (EventStore, TestClock, any WalletKitStorage) {
        (EventStore(storage: storage, config: config, now: clock.reader), clock, storage)
    }

    private func payload(_ text: String = "request") -> Data {
        Data(text.utf8)
    }

    // MARK: - Storing

    func testStoreAndRetrieve() async throws {
        let (store, _, _) = makeStore()
        let stored = try await store.store(
            id: "e1",
            sessionID: "s1",
            eventType: .sendTransaction,
            payload: payload()
        )

        XCTAssertEqual(stored.id, "e1")
        XCTAssertEqual(stored.status, .new)
        XCTAssertEqual(stored.sizeBytes, payload().count)
        XCTAssertEqual(stored.retryCount, 0)

        let fetched = await store.event(id: "e1")
        XCTAssertEqual(fetched, stored)
    }

    /// A bridge message can arrive twice — a reconnect without a resume point replays it.
    /// Re-storing the same id must not reset the event or cause a second delivery.
    func testStoringIsIdempotent() async throws {
        let (store, _, _) = makeStore()
        _ = try await store.store(id: "e1", sessionID: "s1", eventType: .connect, payload: payload())
        _ = await store.claim(id: "e1", walletID: "w1")

        // The duplicate must not knock it back to `new`.
        let second = try await store.store(
            id: "e1",
            sessionID: "s1",
            eventType: .connect,
            payload: payload()
        )
        XCTAssertEqual(second.status, .processing, "a duplicate must not reset the status")
        let actual1 = await store.count()
        XCTAssertEqual(actual1, 1)
    }

    /// A bridge peer must not be able to fill storage.
    func testOversizedEventIsRejected() async throws {
        let (store, _, _) = makeStore(config: DurableEventsConfig(maxEventBytes: 1024))
        let big = Data(repeating: 0x41, count: 2048)

        do {
            _ = try await store.store(id: "big", sessionID: nil, eventType: .connect, payload: big)
            XCTFail("expected the oversized event to be rejected")
        } catch let error as EventStore.EventStoreError {
            guard case .eventTooLarge(let bytes, let limit) = error else {
                return XCTFail("expected eventTooLarge, got \(error)")
            }
            XCTAssertEqual(bytes, 2048)
            XCTAssertEqual(limit, 1024)
        }
        let actual2 = await store.count()
        XCTAssertEqual(actual2, 0, "a rejected event must not be stored")
    }

    func testEventAtExactlyTheSizeLimitIsAccepted() async throws {
        let (store, _, _) = makeStore(config: DurableEventsConfig(maxEventBytes: 1024))
        let exact = Data(repeating: 0x41, count: 1024)
        do {
            _ = try await store.store(id: "e", sessionID: nil, eventType: .connect, payload: exact)
        } catch {
            XCTFail("an event at exactly the limit must be accepted, got \(error)")
        }
    }

    // MARK: - Querying

    /// Oldest first: a user given two requests should see them in the order the dApp sent
    /// them.
    func testPendingEventsAreOldestFirst() async throws {
        let (store, clock, _) = makeStore()
        for id in ["e1", "e2", "e3"] {
            _ = try await store.store(
                id: id,
                sessionID: "s1",
                eventType: .sendTransaction,
                payload: payload(id)
            )
            clock.advance(seconds: 1)
        }

        let pending = await store.pendingEvents(sessionIDs: ["s1"], types: [.sendTransaction])
        XCTAssertEqual(pending.map(\.id), ["e1", "e2", "e3"])
    }

    func testPendingEventsFilterBySessionAndType() async throws {
        let (store, _, _) = makeStore()
        _ = try await store.store(id: "a", sessionID: "s1", eventType: .sendTransaction, payload: payload())
        _ = try await store.store(id: "b", sessionID: "s2", eventType: .sendTransaction, payload: payload())
        _ = try await store.store(id: "c", sessionID: "s1", eventType: .signData, payload: payload())

        let forS1 = await store.pendingEvents(sessionIDs: ["s1"], types: [.sendTransaction])
        XCTAssertEqual(forS1.map(\.id), ["a"], "must filter on both session and type")

        let bothTypes = await store.pendingEvents(
            sessionIDs: ["s1"],
            types: [.sendTransaction, .signData]
        )
        XCTAssertEqual(Set(bothTypes.map(\.id)), ["a", "c"])
    }

    /// A connect request arrives before any session exists, so it has no session id.
    func testSessionlessEventsQuerySeparately() async throws {
        let (store, _, _) = makeStore()
        _ = try await store.store(id: "connect", sessionID: nil, eventType: .connect, payload: payload())
        _ = try await store.store(id: "tx", sessionID: "s1", eventType: .sendTransaction, payload: payload())

        let sessionless = await store.pendingEventsWithoutSession(types: [.connect])
        XCTAssertEqual(sessionless.map(\.id), ["connect"])

        // And a session query must not pick it up.
        let withSession = await store.pendingEvents(sessionIDs: ["s1"], types: [.connect])
        XCTAssertTrue(withSession.isEmpty)
    }

    func testClaimedEventsAreNotPending() async throws {
        let (store, _, _) = makeStore()
        _ = try await store.store(id: "e1", sessionID: "s1", eventType: .connect, payload: payload())
        _ = await store.claim(id: "e1", walletID: "w1")

        let pending = await store.pendingEvents(sessionIDs: ["s1"], types: [.connect])
        XCTAssertTrue(pending.isEmpty, "a claimed event must not be handed out again")
    }

    // MARK: - Claiming

    func testClaimTransitionsToProcessing() async throws {
        let (store, _, _) = makeStore()
        _ = try await store.store(id: "e1", sessionID: "s1", eventType: .connect, payload: payload())

        let maybeClaimed = await store.claim(id: "e1", walletID: "w1")
        let claimed = try XCTUnwrap(maybeClaimed)
        XCTAssertEqual(claimed.status, .processing)
        XCTAssertEqual(claimed.lockedBy, "w1")
        XCTAssertNotNil(claimed.processingStartedAt)
    }

    /// Two wallets polling the same queue is normal; exactly one must win.
    func testOnlyOneClaimSucceeds() async throws {
        let (store, _, _) = makeStore()
        _ = try await store.store(id: "e1", sessionID: "s1", eventType: .connect, payload: payload())

        let first = await store.claim(id: "e1", walletID: "w1")
        let second = await store.claim(id: "e1", walletID: "w2")

        XCTAssertNotNil(first)
        XCTAssertNil(second, "losing the race must return nil, not throw")
        let actual3 = await store.event(id: "e1")?.lockedBy
        XCTAssertEqual(actual3, "w1")
    }

    /// Concurrent claims from many tasks must still yield exactly one winner. Actor
    /// isolation is what makes this hold without a hand-rolled lock table.
    func testConcurrentClaimsYieldExactlyOneWinner() async throws {
        let (store, _, _) = makeStore()
        _ = try await store.store(id: "e1", sessionID: "s1", eventType: .connect, payload: payload())

        let winners = await withTaskGroup(of: Bool.self) { group in
            for i in 0..<50 {
                group.addTask { await store.claim(id: "e1", walletID: "w\(i)") != nil }
            }
            var count = 0
            for await won in group where won { count += 1 }
            return count
        }
        XCTAssertEqual(winners, 1, "exactly one of 50 concurrent claims must succeed")
    }

    func testClaimingAnUnknownEventReturnsNil() async {
        let (store, _, _) = makeStore()
        let claimed = await store.claim(id: "nope", walletID: "w1")
        XCTAssertNil(claimed)
    }

    // MARK: - Release and retry

    func testReleaseWithoutErrorReturnsToNew() async throws {
        let (store, _, _) = makeStore()
        _ = try await store.store(id: "e1", sessionID: "s1", eventType: .connect, payload: payload())
        _ = await store.claim(id: "e1", walletID: "w1")

        let released = try await store.release(id: "e1")
        XCTAssertEqual(released.status, .new)
        XCTAssertNil(released.lockedBy)
        XCTAssertEqual(released.retryCount, 0, "a clean release is not a retry")
    }

    func testReleaseWithErrorIncrementsRetryCount() async throws {
        let (store, _, _) = makeStore()
        _ = try await store.store(id: "e1", sessionID: "s1", eventType: .connect, payload: payload())
        _ = await store.claim(id: "e1", walletID: "w1")

        let released = try await store.release(id: "e1", error: "network down")
        XCTAssertEqual(released.status, .new, "a retryable failure goes back to the queue")
        XCTAssertEqual(released.retryCount, 1)
        XCTAssertEqual(released.lastError, "network down")
    }

    /// An event that always fails must stop being retried, or it occupies the queue forever.
    func testRetriesAreBounded() async throws {
        let (store, _, _) = makeStore(config: DurableEventsConfig(maxRetries: 3))
        _ = try await store.store(id: "e1", sessionID: "s1", eventType: .connect, payload: payload())

        for attempt in 1...3 {
            _ = await store.claim(id: "e1", walletID: "w1")
            let released = try await store.release(id: "e1", error: "always fails")
            if attempt < 3 {
                XCTAssertEqual(released.status, .new, "retry \(attempt) should requeue")
            } else {
                XCTAssertEqual(released.status, .errored, "the final failure must give up")
            }
        }

        let pending = await store.pendingEvents(sessionIDs: ["s1"], types: [.connect])
        XCTAssertTrue(pending.isEmpty, "an errored event must not be handed out again")
    }

    func testCompleteMarksTerminal() async throws {
        let (store, _, _) = makeStore()
        _ = try await store.store(id: "e1", sessionID: "s1", eventType: .connect, payload: payload())
        _ = await store.claim(id: "e1", walletID: "w1")

        let completed = try await store.complete(id: "e1")
        XCTAssertEqual(completed.status, .completed)
        XCTAssertNotNil(completed.completedAt)
        XCTAssertNil(completed.lockedBy)
    }

    func testCompareAndSetRejectsAStaleExpectation() async throws {
        let (store, _, _) = makeStore()
        _ = try await store.store(id: "e1", sessionID: "s1", eventType: .connect, payload: payload())
        _ = await store.claim(id: "e1", walletID: "w1")

        // The event is `processing`, so a caller expecting `new` must be refused.
        do {
            _ = try await store.updateStatus(id: "e1", to: .completed, expecting: .new)
            XCTFail("expected a status mismatch")
        } catch let error as EventStore.EventStoreError {
            guard case .statusMismatch = error else {
                return XCTFail("expected statusMismatch, got \(error)")
            }
        }
    }

    // MARK: - Stale recovery

    /// The case this exists for: the app is killed while a confirmation sheet is up. Without
    /// recovery the request stays `processing` forever and the dApp waits indefinitely.
    func testStaleClaimsAreReclaimed() async throws {
        let (store, clock, _) = makeStore(config: DurableEventsConfig(processingTimeout: 60))
        _ = try await store.store(id: "e1", sessionID: "s1", eventType: .connect, payload: payload())
        _ = await store.claim(id: "e1", walletID: "w1")

        // Not yet stale.
        clock.advance(seconds: 30)
        let actual5 = await store.recoverStaleEvents()
        XCTAssertEqual(actual5, 0)
        let actual6 = await store.event(id: "e1")?.status
        XCTAssertEqual(actual6, .processing)

        // Past the timeout.
        clock.advance(seconds: 31)
        let actual7 = await store.recoverStaleEvents()
        XCTAssertEqual(actual7, 1)

        let maybeRecovered = await store.event(id: "e1")
        let recovered = try XCTUnwrap(maybeRecovered)
        XCTAssertEqual(recovered.status, .new, "a reclaimed event must be handed out again")
        XCTAssertNil(recovered.lockedBy)
        XCTAssertEqual(recovered.retryCount, 1)
    }

    /// Recovery must not resurrect an event forever.
    func testRecoveryRespectsTheRetryLimit()
        async throws
    {
        let (store, clock, _) = makeStore(
            config: DurableEventsConfig(processingTimeout: 1, maxRetries: 2)
        )
        _ = try await store.store(id: "e1", sessionID: "s1", eventType: .connect, payload: payload())

        for _ in 0..<2 {
            _ = await store.claim(id: "e1", walletID: "w1")
            clock.advance(seconds: 2)
            _ = await store.recoverStaleEvents()
        }
        let actual8 = await store.event(id: "e1")?.status
        XCTAssertEqual(actual8, .errored)
    }

    func testRecoveryLeavesFreshAndFinishedEventsAlone() async throws {
        let (store, clock, _) = makeStore(config: DurableEventsConfig(processingTimeout: 1))
        _ = try await store.store(id: "new", sessionID: "s1", eventType: .connect, payload: payload())
        _ = try await store.store(id: "done", sessionID: "s1", eventType: .connect, payload: payload())
        _ = await store.claim(id: "done", walletID: "w1")
        _ = try await store.complete(id: "done")

        clock.advance(seconds: 10)
        let actual9 = await store.recoverStaleEvents()
        XCTAssertEqual(actual9, 0)
        let actual10 = await store.event(id: "new")?.status
        XCTAssertEqual(actual10, .new)
        let actual11 = await store.event(id: "done")?.status
        XCTAssertEqual(actual11, .completed)
    }

    // MARK: - Cleanup

    /// An unanswered request must never be dropped on age — the user may still act on it.
    func testCleanupKeepsUnansweredRequestsForever() async throws {
        let (store, clock, _) = makeStore(config: DurableEventsConfig(retention: 60))
        _ = try await store.store(id: "pending", sessionID: "s1", eventType: .connect, payload: payload())
        _ = try await store.store(id: "claimed", sessionID: "s1", eventType: .connect, payload: payload())
        _ = await store.claim(id: "claimed", walletID: "w1")

        clock.advance(seconds: 10_000)
        let actual12 = await store.cleanupOldEvents()
        XCTAssertEqual(actual12, 0, "only terminal events may be dropped")
        let actual13 = await store.count()
        XCTAssertEqual(actual13, 2)
    }

    func testCleanupDropsOldTerminalEvents() async throws {
        let (store, clock, _) = makeStore(config: DurableEventsConfig(retention: 60))
        _ = try await store.store(id: "done", sessionID: "s1", eventType: .connect, payload: payload())
        _ = await store.claim(id: "done", walletID: "w1")
        _ = try await store.complete(id: "done")

        clock.advance(seconds: 30)
        let actual14 = await store.cleanupOldEvents()
        XCTAssertEqual(actual14, 0, "still inside the retention window")

        clock.advance(seconds: 31)
        let actual15 = await store.cleanupOldEvents()
        XCTAssertEqual(actual15, 1)
        let actual16 = await store.event(id: "done")
        XCTAssertNil(actual16)
    }

    // MARK: - Durability

    /// The core promise: a restart must not lose events.
    func testEventsSurviveARestart() async throws {
        let storage = InMemoryStorage()
        let clock = TestClock()

        do {
            let store = EventStore(storage: storage, now: clock.reader)
            _ = try await store.store(id: "e1", sessionID: "s1", eventType: .connect, payload: payload("first"))
            _ = try await store.store(id: "e2", sessionID: "s1", eventType: .signData, payload: payload("second"))
            _ = await store.claim(id: "e2", walletID: "w1")
        }

        // A fresh store over the same storage stands in for a relaunch.
        let reopened = EventStore(storage: storage, now: clock.reader)
        let actual17 = await reopened.count()
        XCTAssertEqual(actual17, 2, "both events must survive")

        let maybeE1 = await reopened.event(id: "e1")
        let e1 = try XCTUnwrap(maybeE1)
        XCTAssertEqual(e1.status, .new)
        XCTAssertEqual(e1.payload, payload("first"))

        let maybeE2 = await reopened.event(id: "e2")
        let e2 = try XCTUnwrap(maybeE2)
        XCTAssertEqual(e2.status, .processing, "a claim must survive too")
        XCTAssertEqual(e2.lockedBy, "w1")
    }

    /// After a restart, a claim left dangling by the kill must be reclaimable — otherwise
    /// the request is stuck forever.
    func testDanglingClaimIsRecoverableAfterRestart() async throws {
        let storage = InMemoryStorage()
        let clock = TestClock()
        let config = DurableEventsConfig(processingTimeout: 60)

        do {
            let store = EventStore(storage: storage, config: config, now: clock.reader)
            _ = try await store.store(id: "e1", sessionID: "s1", eventType: .connect, payload: payload())
            _ = await store.claim(id: "e1", walletID: "w1")
            // Killed here, mid-processing.
        }

        clock.advance(seconds: 120)
        let reopened = EventStore(storage: storage, config: config, now: clock.reader)
        let actual18 = await reopened.recoverStaleEvents()
        XCTAssertEqual(actual18, 1)
        let actual19 = await reopened.event(id: "e1")?.status
        XCTAssertEqual(actual19, .new)
    }

    /// Randomized interruption: perform a random sequence of operations, reopening the store
    /// at arbitrary points, and require the invariants to hold every time.
    ///
    /// The plan calls for crash testing here specifically because the reference's
    /// hand-rolled lock table is the kind of thing that loses or duplicates events under
    /// interleaving.
    func testRandomizedInterruptionPreservesInvariants() async throws {
        for seed in 0..<40 {
            let storage = InMemoryStorage()
            let clock = TestClock()
            var generator = SeededGenerator(seed: UInt64(seed))
            var expectedIDs = Set<String>()

            for step in 0..<25 {
                // Reopening stands in for a kill and relaunch at an arbitrary point.
                let store = EventStore(storage: storage, now: clock.reader)

                switch Int.random(in: 0..<4, using: &generator) {
                case 0:
                    let id = "e\(step)"
                    _ = try await store.store(
                        id: id,
                        sessionID: "s1",
                        eventType: .sendTransaction,
                        payload: payload(id)
                    )
                    expectedIDs.insert(id)
                case 1:
                    if let target = expectedIDs.randomElement(using: &generator) {
                        _ = await store.claim(id: target, walletID: "w1")
                    }
                case 2:
                    if let target = expectedIDs.randomElement(using: &generator) {
                        _ = try? await store.release(id: target, error: "interrupted")
                    }
                default:
                    if let target = expectedIDs.randomElement(using: &generator) {
                        _ = try? await store.complete(id: target)
                    }
                }
                clock.advance(seconds: 1)
            }

            // No event may be lost, and none may be duplicated.
            let final = EventStore(storage: storage, now: clock.reader)
            let all = await final.allEvents()
            XCTAssertEqual(
                Set(all.map(\.id)),
                expectedIDs,
                "seed \(seed): stored ids must match exactly — nothing lost, nothing invented"
            )
            XCTAssertEqual(
                all.count,
                Set(all.map(\.id)).count,
                "seed \(seed): duplicate ids in the queue"
            )
            // A claim must always name its holder, and a released event must not.
            for event in all {
                switch event.status {
                case .processing:
                    XCTAssertNotNil(event.lockedBy, "seed \(seed): a claim with no holder")
                    XCTAssertNotNil(event.processingStartedAt)
                case .new, .errored:
                    XCTAssertNil(event.lockedBy, "seed \(seed): a queued event still held")
                case .completed:
                    XCTAssertNotNil(event.completedAt)
                    XCTAssertNil(event.lockedBy)
                }
            }
        }
    }

    func testClearRemovesEverything() async throws {
        let (store, _, _) = makeStore()
        _ = try await store.store(id: "e1", sessionID: "s1", eventType: .connect, payload: payload())
        _ = try await store.store(id: "e2", sessionID: "s1", eventType: .connect, payload: payload())
        await store.clear()
        let actual20 = await store.count()
        XCTAssertEqual(actual20, 0)
    }

    func testCountByStatus() async throws {
        let (store, _, _) = makeStore()
        for id in ["a", "b", "c"] {
            _ = try await store.store(id: id, sessionID: "s1", eventType: .connect, payload: payload())
        }
        _ = await store.claim(id: "a", walletID: "w1")
        _ = try await store.complete(id: "a")

        let actual21 = await store.count(status: .new)
        XCTAssertEqual(actual21, 2)
        let actual22 = await store.count(status: .completed)
        XCTAssertEqual(actual22, 1)
        let actual23 = await store.count()
        XCTAssertEqual(actual23, 3)
    }
}

/// Deterministic RNG, so a failing randomized case can be reproduced from its seed.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid the zero state, which would make the generator degenerate.
        self.state = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        if state == 0 { state = 0x9E3779B97F4A7C15 }
    }

    mutating func next() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2_685_821_657_736_338_717
    }
}
