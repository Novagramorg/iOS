import Testing
import Foundation
import Combine
@testable import TONWalletKit

@Suite("TONStreamingPublisher Tests")
struct TONStreamingPublisherTests {

    @Test("delivers values from watch callback")
    func deliversValues() {
        var emit: ((Int) -> Void)?

        let publisher = TONStreamingPublisher<Int> { handler in
            emit = handler
            return { }
        }

        var received = [Int]()
        let cancellable = publisher.sink(
            receiveCompletion: { _ in },
            receiveValue: { received.append($0) }
        )

        emit?(1)
        emit?(2)
        emit?(3)

        #expect(received == [1, 2, 3])
        cancellable.cancel()
    }

    @Test("sends failure completion when watch throws")
    func watchThrowsSendsFailure() {
        struct WatchError: Error {}

        let publisher = TONStreamingPublisher<Int> { _ in
            throw WatchError()
        }

        var completionError: (any Error)?
        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    completionError = error
                }
            },
            receiveValue: { _ in }
        )

        #expect(completionError is WatchError)
        cancellable.cancel()
    }

    @Test("cancel calls unwatch")
    func cancelCallsUnwatch() {
        var unwatchCalled = false

        let publisher = TONStreamingPublisher<Int> { _ in
            return { unwatchCalled = true }
        }

        let cancellable = publisher.sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        )

        cancellable.cancel()

        #expect(unwatchCalled)
    }

    @Test("no values delivered after cancel")
    func noValuesAfterCancel() {
        var emit: ((Int) -> Void)?

        let publisher = TONStreamingPublisher<Int> { handler in
            emit = handler
            return { }
        }

        var received = [Int]()
        let cancellable = publisher.sink(
            receiveCompletion: { _ in },
            receiveValue: { received.append($0) }
        )

        emit?(1)
        cancellable.cancel()
        emit?(2)

        #expect(received == [1])
    }

    @Test("watch is called only once on multiple demands")
    func watchCalledOnce() {
        var watchCallCount = 0

        let publisher = TONStreamingPublisher<Int> { _ in
            watchCallCount += 1
            return { }
        }

        var subscription: Subscription?
        let subscriber = AnySubscriber<Int, any Error>(
            receiveSubscription: { sub in
                subscription = sub
                sub.request(.max(1))
                sub.request(.max(1))
                sub.request(.unlimited)
            },
            receiveValue: { _ in .none },
            receiveCompletion: { _ in }
        )

        publisher.receive(subscriber: subscriber)

        #expect(watchCallCount == 1)
        subscription?.cancel()
    }

    @Test("works with different output types")
    func worksWithStringOutput() {
        var emit: ((String) -> Void)?

        let publisher = TONStreamingPublisher<String> { handler in
            emit = handler
            return { }
        }

        var received: String?
        let cancellable = publisher.sink(
            receiveCompletion: { _ in },
            receiveValue: { received = $0 }
        )

        emit?("hello")

        #expect(received == "hello")
        cancellable.cancel()
    }

    @Test("delivers value first then fails on re-subscribe")
    func valueFirstThenError() {
        struct WatchError: Error {}
        var callCount = 0

        let publisher = TONStreamingPublisher<Int> { handler in
            callCount += 1
            if callCount > 1 {
                throw WatchError()
            }
            handler(42)
            return { }
        }

        var received = [Int]()
        let first = publisher.sink(
            receiveCompletion: { _ in },
            receiveValue: { received.append($0) }
        )
        first.cancel()

        #expect(received == [42])

        var completionError: (any Error)?
        let second = publisher.sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    completionError = error
                }
            },
            receiveValue: { received.append($0) }
        )

        #expect(received == [42])
        #expect(completionError is WatchError)
        second.cancel()
    }
}
