import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// A whole `Postbox` over an in-memory value box, for tests that need the transaction
/// API and the view tracker rather than a single table.
final class PostboxFixture {
    let queue: Queue
    let basePath: String
    private(set) var postbox: Postbox!
    static let messageNamespace: MessageId.Namespace = MessageHistoryTableFixture.messageNamespace

    /// Holds the value box so it can be released on its queue (`SqliteValueBox.deinit`
    /// preconditions that); the Postbox implementation drops its own reference there too.
    private final class Storage {
        let valueBox: SqliteValueBox
        init(valueBox: SqliteValueBox) {
            self.valueBox = valueBox
        }
    }
    private var storage: Storage?
    private var disposables: [Disposable] = []

    init(name: String) {
        let _ = FixtureMedia.register
        self.queue = Queue(name: name)
        self.basePath = NSTemporaryDirectory() + name + "-" + UUID().uuidString
        let queue = self.queue
        let basePath = self.basePath
        var valueBox: SqliteValueBox?
        queue.sync {
            valueBox = SqliteValueBox(basePath: basePath + "/db", queue: queue, isTemporary: true, isReadOnly: false, useCaches: true, removeDatabaseOnError: true, encryptionParameters: nil, upgradeProgress: { _ in }, inMemory: true)
        }
        self.storage = Storage(valueBox: valueBox!)
        self.postbox = Postbox(
            queue: queue,
            basePath: basePath,
            seedConfiguration: MessageHistoryTableFixture.makeSeedConfiguration(),
            valueBox: valueBox!,
            timestampForAbsoluteTimeBasedOperations: Int32(Date().timeIntervalSince1970),
            isMainProcess: true,
            isTemporary: true,
            tempDir: nil,
            useCaches: true
        )
    }

    func close() {
        for disposable in self.disposables {
            disposable.dispose()
        }
        self.disposables = []
        // The media box opens its storage database on its own queue, lazily; deleting
        // the directory while that open is in flight trips an assertion inside SQLite
        // setup. A round trip through that queue makes sure the open has finished.
        let storageReady = DispatchSemaphore(value: 0)
        let disposable = self.postbox.mediaBox.storageBox.totalSize().start(next: { _ in
            storageReady.signal()
        })
        let _ = storageReady.wait(timeout: .now() + 10.0)
        disposable.dispose()
        // Release the Postbox first: its implementation is dropped on the queue, ahead of
        // the block below, so the value box outlives everything that uses it.
        self.postbox = nil
        self.queue.sync {
            self.storage = nil
        }
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
    }

    // MARK: - Transactions

    /// Runs `f` as a Postbox transaction and waits for it to finish. Nil, with the test
    /// failed, if it did not finish in time (a hung queue must not take the process down).
    @discardableResult
    func transaction<T>(_ f: @escaping (Transaction) -> T, file: StaticString = #file, line: UInt = #line) -> T? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: T?
        let disposable = self.postbox.transaction(f).start(next: { value in
            result = value
            semaphore.signal()
        })
        if semaphore.wait(timeout: .now() + 10.0) == .timedOut {
            XCTFail("transaction did not complete", file: file, line: line)
        }
        disposable.dispose()
        return result
    }

    // MARK: - Views

    /// Every value a combined view has produced so far, oldest first.
    final class ViewRecorder<View: PostboxView> {
        private let lock = NSLock()
        private var recorded: [View] = []
        private let semaphore = DispatchSemaphore(value: 0)

        fileprivate func record(_ view: View) {
            self.lock.lock()
            self.recorded.append(view)
            self.lock.unlock()
            self.semaphore.signal()
        }

        var values: [View] {
            self.lock.lock()
            defer { self.lock.unlock() }
            return self.recorded
        }

        /// Blocks until at least `count` values have arrived (or fails the test).
        @discardableResult
        func waitForValues(count: Int, file: StaticString = #file, line: UInt = #line) -> [View] {
            let deadline = DispatchTime.now() + 10.0
            while self.values.count < count {
                if self.semaphore.wait(timeout: deadline) == .timedOut {
                    XCTFail("expected \(count) view values, got \(self.values.count)", file: file, line: line)
                    break
                }
            }
            return self.values
        }
    }

    func observe<View: PostboxView>(_ key: PostboxViewKey, as type: View.Type) -> ViewRecorder<View> {
        let recorder = ViewRecorder<View>()
        let disposable = self.postbox.combinedView(keys: [key]).start(next: { combined in
            if let view = combined.views[key] as? View {
                recorder.record(view)
            } else {
                XCTFail("combined view has no \(View.self) for \(key)")
            }
        })
        self.disposables.append(disposable)
        return recorder
    }
}
