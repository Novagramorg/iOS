import XCTest
import SwiftSignalKit
import MtProtoKit
import EncryptionProvider
import MTProtoEngineFFI
@testable import TelegramCore
@testable import MTProtoRustEngine

private let callConstructor: UInt32 = 0x7e57_0001
private let callResultConstructor: UInt32 = 0x7e57_0002
private let tagFloodOnce: UInt32 = 1001
private let tagDropConnectionOnce: UInt32 = 1002
private let tagNever: UInt32 = 1004
private let tagBadSaltOnce: UInt32 = 1007

private final class TestServerProcess {
    let address: String
    let port: Int32
    let key: Data
    let salt: Int64

    private let process: Process
    private let input: Pipe
    private let output: Pipe
    private var buffer = Data()

    static func binaryPath() -> String? {
        let engineDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../../../third-party/mtproto-engine/target")
            .standardizedFileURL
        for configuration in ["release", "debug"] {
            let path = engineDirectory.appendingPathComponent("\(configuration)/mtproto-testserver").path
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    init(binary: String) throws {
        self.process = Process()
        self.input = Pipe()
        self.output = Pipe()
        self.process.executableURL = URL(fileURLWithPath: binary)
        self.process.standardInput = self.input
        self.process.standardOutput = self.output
        self.process.standardError = FileHandle.nullDevice
        try self.process.run()

        var line: String?
        let handle = self.output.fileHandleForReading
        while line == nil {
            let chunk = handle.availableData
            if chunk.isEmpty {
                break
            }
            self.buffer.append(chunk)
            line = TestServerProcess.takeLine(&self.buffer)
        }
        guard let ready = line, let object = try JSONSerialization.jsonObject(with: Data(ready.utf8)) as? [String: Any], let address = object["address"] as? String, let keyHex = object["key_hex"] as? String, let salt = object["salt"] as? NSNumber, let separator = address.lastIndex(of: ":"), let port = Int32(address[address.index(after: separator)...]) else {
            throw NSError(domain: "TestServerProcess", code: 1)
        }
        self.address = String(address[..<separator])
        self.port = port
        self.key = TestServerProcess.data(hex: keyHex)
        self.salt = salt.int64Value
    }

    deinit {
        self.input.fileHandleForWriting.write(Data("quit\n".utf8))
        self.process.waitUntilExit()
    }

    func stats() -> [String: Any] {
        self.input.fileHandleForWriting.write(Data("stats\n".utf8))
        let handle = self.output.fileHandleForReading
        while true {
            if let line = TestServerProcess.takeLine(&self.buffer) {
                return ((try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any]) ?? [:]
            }
            let chunk = handle.availableData
            if chunk.isEmpty {
                return [:]
            }
            self.buffer.append(chunk)
        }
    }

    func executions(tag: UInt32) -> Int {
        return ((self.stats()["tags"] as? [String: Any])?["\(tag)"] as? NSNumber)?.intValue ?? 0
    }

    func obfuscationDatacenterIds() -> [Int] {
        return ((self.stats()["obfuscation_dc_ids"] as? [NSNumber]) ?? []).map { $0.intValue }
    }

    private static func takeLine(_ buffer: inout Data) -> String? {
        guard let index = buffer.firstIndex(of: 0x0a) else {
            return nil
        }
        let line = String(decoding: buffer[buffer.startIndex ..< index], as: UTF8.self)
        buffer.removeSubrange(buffer.startIndex ... index)
        return line
    }

    private static func data(hex: String) -> Data {
        var result = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            result.append(UInt8(hex[index ..< next], radix: 16) ?? 0)
            index = next
        }
        return result
    }
}

private final class InMemoryKeychain: NSObject, MTKeychain {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    func setObject(_ object: Any!, forKey aKey: String!, group: String!) {
        guard let object = object, let data = try? NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: false) else {
            return
        }
        self.lock.lock()
        self.storage[group + ":" + aKey] = data
        self.lock.unlock()
    }

    private func value(_ aKey: String, _ group: String) -> Any? {
        self.lock.lock()
        let data = self.storage[group + ":" + aKey]
        self.lock.unlock()
        return data.flatMap { MTDeprecated.unarchiveDeprecated(with: $0) }
    }

    func dictionary(forKey aKey: String!, group: String!) -> [AnyHashable: Any]? {
        return (self.value(aKey, group) as? NSDictionary) as? [AnyHashable: Any]
    }

    func number(forKey aKey: String!, group: String!) -> NSNumber? {
        return self.value(aKey, group) as? NSNumber
    }

    func removeObject(forKey aKey: String!, group: String!) {
        self.lock.lock()
        self.storage.removeValue(forKey: group + ":" + aKey)
        self.lock.unlock()
    }
}

private final class UnusedEncryptionProvider: NSObject, EncryptionProvider {
    func createBignumContext() -> MTBignumContext {
        preconditionFailure("the seeded auth key makes MtProtoKit cryptography unnecessary")
    }

    func rsaEncrypt(withPublicKey publicKey: String, data: Data) -> Data? {
        return nil
    }

    func rsaEncryptPKCS1OAEP(withPublicKey publicKey: String, data: Data) -> Data? {
        return nil
    }

    func parseRSAPublicKey(_ publicKey: String) -> MTRsaPublicKey {
        preconditionFailure("the seeded auth key makes MtProtoKit cryptography unnecessary")
    }

    func macosRSAEncrypt(_ publicKey: String, data: Data) -> Data {
        return Data()
    }
}

private final class StateRecorder: NetworkEngineSessionDelegate {
    private let lock = NSLock()
    private var states: [NetworkEngineConnectionState] = []

    func networkSessionAuthorizationRequired() {
    }

    func networkSessionSoftAuthReset() {
    }

    func networkSessionConnectionStateChanged(_ state: NetworkEngineConnectionState) {
        self.lock.lock()
        self.states.append(state)
        self.lock.unlock()
    }

    var sawConnected: Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.states.contains(where: { $0.isConnected })
    }
}

private struct CallResult: Equatable {
    let tag: UInt32
    let payload: Data
}

final class RustEngineEndToEndTests: XCTestCase {
    private static let datacenterId = 2
    private static let timeout: TimeInterval = 15.0

    private var server: TestServerProcess!
    private var context: MTContext!
    private var engine: NetworkEngine!

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard let binary = TestServerProcess.binaryPath() else {
            throw XCTSkip("build third-party/mtproto-engine first: cargo build --release -p mtproto-testserver")
        }
        guard RustEngineRuntime.shared != nil else {
            XCTFail("engine did not start")
            return
        }
        self.server = try TestServerProcess(binary: binary)

        let context = self.makeContext(useTempAuthKeys: false)
        self.setAddress(of: context, preferForMedia: false)
        context.updateAuthInfoForDatacenter(withId: RustEngineEndToEndTests.datacenterId, authInfo: self.authInfo(key: self.server.key), selector: .persistent)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        self.context = context

        guard let engine = RustNetworkEngineFactory().makeEngine(context: context, isAppExtension: false) else {
            XCTFail("factory declined a plain configuration")
            return
        }
        XCTAssertEqual(engine.kind, NetworkEngineKind.rust)
        self.engine = engine
    }

    override func tearDown() {
        self.engine = nil
        self.context = nil
        self.server = nil
        super.tearDown()
    }

    private func makeContext(useTempAuthKeys: Bool) -> MTContext {
        let serialization = Serialization()
        var apiEnvironment = MTApiEnvironment(deviceModelName: "MTProtoRustEngine end-to-end tests")
        apiEnvironment.apiId = 9
        apiEnvironment.appVersion = "1.0"
        apiEnvironment.langPack = "macos"
        apiEnvironment.layer = NSNumber(value: Int(serialization.currentLayer()))
        apiEnvironment.disableUpdates = false
        apiEnvironment = apiEnvironment.withUpdatedLangPackCode("en")
        let context = MTContext(serialization: serialization, encryptionProvider: UnusedEncryptionProvider(), apiEnvironment: apiEnvironment, isTestingEnvironment: false, useTempAuthKeys: useTempAuthKeys)
        context.keychain = InMemoryKeychain()
        return context
    }

    private func setAddress(of context: MTContext, preferForMedia: Bool) {
        let address = MTDatacenterAddress(ip: self.server.address, port: UInt16(self.server.port), preferForMedia: preferForMedia, restrictToTcp: false, cdn: false, preferForProxy: false, secret: nil)
        context.updateAddressSetForDatacenter(withId: RustEngineEndToEndTests.datacenterId, addressSet: MTDatacenterAddressSet(addressList: [address]), forceUpdateSchemes: true)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
    }

    private func authInfo(key: Data) -> MTDatacenterAuthInfo {
        let keyHash = MTSha1(key)
        var authKeyId: Int64 = 0
        _ = withUnsafeMutableBytes(of: &authKeyId) { buffer in
            keyHash.copyBytes(to: buffer, from: keyHash.count - 8 ..< keyHash.count)
        }
        let now = Int64(Date().timeIntervalSince1970)
        let saltInfo = MTDatacenterSaltInfo(salt: self.server.salt, firstValidMessageId: (now - 86_400) << 32, lastValidMessageId: (now + 86_400) << 32)!
        return MTDatacenterAuthInfo(authKey: key, authKeyId: authKeyId, validUntilTimestamp: Int32.max, saltSet: [saltInfo], authKeyAttributes: [:])!
    }

    private static func append(_ value: UInt32, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }

    private static func readUInt32(_ data: Data, _ offset: Int) -> UInt32? {
        guard offset + 4 <= data.count else {
            return nil
        }
        return data.subdata(in: offset ..< offset + 4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian
    }

    private func call(tag: UInt32, payload: Data = Data()) -> Data {
        var data = Data()
        RustEngineEndToEndTests.append(callConstructor, to: &data)
        RustEngineEndToEndTests.append(tag, to: &data)
        if payload.count < 254 {
            data.append(UInt8(payload.count))
        } else {
            RustEngineEndToEndTests.append(UInt32(payload.count) << 8 | 254, to: &data)
        }
        data.append(payload)
        while data.count % 4 != 0 {
            data.append(0)
        }
        return data
    }

    private static func parse(_ data: Data) -> Any? {
        guard readUInt32(data, 0) == callResultConstructor, let tag = readUInt32(data, 4), data.count > 8 else {
            return nil
        }
        let first = Int(data[data.startIndex + 8])
        let length: Int
        let start: Int
        if first < 254 {
            length = first
            start = 9
        } else {
            guard let header = readUInt32(data, 8) else {
                return nil
            }
            length = Int(header >> 8)
            start = 12
        }
        guard start + length <= data.count else {
            return nil
        }
        return CallResult(tag: tag, payload: data.subdata(in: data.startIndex + start ..< data.startIndex + start + length))
    }

    private func request(
        tag: UInt32,
        payload: Data = Data(),
        options: NetworkEngineRequestOptions = NetworkEngineRequestOptions(),
        shouldContinueAfterError: @escaping (NetworkEngineErrorContext) -> Bool = { _ in false },
        acknowledged: (() -> Void)? = nil,
        completed: @escaping (Result<NetworkEngineResponse, NetworkEngineRequestFailure>) -> Void
    ) -> NetworkEngineRequest {
        let description = "call \(tag)"
        return NetworkEngineRequest(
            payload: self.call(tag: tag, payload: payload),
            metadata: WrappedRequestMetadata(metadata: description, tag: nil),
            shortMetadata: WrappedRequestShortMetadata(shortMetadata: description),
            parse: RustEngineEndToEndTests.parse,
            options: options,
            shouldContinueAfterError: shouldContinueAfterError,
            dependsOn: nil,
            acknowledged: acknowledged,
            progress: nil,
            completed: completed
        )
    }

    private func makeSession(delegate: NetworkEngineSessionDelegate? = nil, role: NetworkEngineSessionRole = .main) -> NetworkEngineSession {
        let session = self.engine.makeSession(datacenterId: RustEngineEndToEndTests.datacenterId, role: role, usageCalculationInfo: nil, delegate: delegate)
        session.setPaused(false)
        return session
    }

    func testRequestCompletesThroughContextEngineAndServer() {
        let recorder = StateRecorder()
        let session = self.makeSession(delegate: recorder)
        defer { session.stop() }
        let done = self.expectation(description: "completed")
        let payload = Data("hello from swift".utf8)
        let disposable = session.requestService.add(self.request(tag: 7, payload: payload) { result in
            switch result {
            case let .success(response):
                XCTAssertEqual(response.result as? CallResult, CallResult(tag: 7, payload: payload))
                XCTAssertGreaterThan(response.info.timestamp, 1_600_000_000)
            case let .failure(failure):
                XCTFail("\(failure.error.errorCode) \(failure.error.errorDescription ?? "")")
            }
            done.fulfill()
        })
        self.wait(for: [done], timeout: RustEngineEndToEndTests.timeout)
        disposable.dispose()
        XCTAssertTrue(recorder.sawConnected)
        XCTAssertEqual(self.server.executions(tag: 7), 1)
    }

    func testMediaWorkerFollowsItsAddressesBetweenMediaAndMainKeys() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.makeContext(useTempAuthKeys: true)
        let serverKey = self.authInfo(key: self.server.key)
        let unknownKey = self.authInfo(key: Data((0 ..< 256).map { _ in UInt8.random(in: 0 ... 255) }))
        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: serverKey, selector: .persistent)
        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: serverKey, selector: .ephemeralMain)
        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: unknownKey, selector: .ephemeralMedia)
        self.setAddress(of: context, preferForMedia: true)
        guard let engine = RustNetworkEngineFactory().makeEngine(context: context, isAppExtension: false) else {
            XCTFail("factory declined a temporary key configuration")
            return
        }
        let session = engine.makeSession(datacenterId: datacenterId, role: .worker(masterDatacenterId: datacenterId, isMedia: true, isCdn: false), usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }

        self.setAddress(of: context, preferForMedia: false)
        guard self.completes(tag: 21, on: session) else {
            return
        }
        XCTAssertEqual(self.server.obfuscationDatacenterIds().last, datacenterId)

        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: serverKey, selector: .ephemeralMedia)
        self.setAddress(of: context, preferForMedia: true)
        guard self.completes(tag: 22, on: session) else {
            return
        }
        XCTAssertEqual(self.server.obfuscationDatacenterIds().last, -datacenterId)
    }

    private func completes(tag: UInt32, on session: NetworkEngineSession) -> Bool {
        let done = XCTestExpectation(description: "request \(tag) completed")
        let disposable = session.requestService.add(self.request(tag: tag) { result in
            if case let .failure(failure) = result {
                XCTFail("\(failure.error.errorCode) \(failure.error.errorDescription ?? "")")
            }
            done.fulfill()
        })
        let waited = XCTWaiter().wait(for: [done], timeout: RustEngineEndToEndTests.timeout)
        disposable.dispose()
        if waited != .completed {
            XCTFail("request \(tag) did not complete")
            return false
        }
        return true
    }

    func testConcurrentRequestsFromManyThreadsCompleteExactlyOnce() {
        let session = self.makeSession()
        defer { session.stop() }
        let count = 400
        let lock = NSLock()
        var completions: [Int: Int] = [:]
        let done = self.expectation(description: "all completed")
        done.expectedFulfillmentCount = count
        var disposables: [Disposable] = []
        DispatchQueue.concurrentPerform(iterations: count) { index in
            var payload = Data(count: 4)
            payload.withUnsafeMutableBytes { $0.storeBytes(of: UInt32(index).littleEndian, as: UInt32.self) }
            let disposable = session.requestService.add(self.request(tag: 100, payload: payload) { result in
                guard case let .success(response) = result, let value = response.result as? CallResult else {
                    XCTFail("request \(index) failed")
                    done.fulfill()
                    return
                }
                XCTAssertEqual(value.payload, payload)
                lock.lock()
                completions[index, default: 0] += 1
                lock.unlock()
                done.fulfill()
            })
            lock.lock()
            disposables.append(disposable)
            lock.unlock()
        }
        self.wait(for: [done], timeout: RustEngineEndToEndTests.timeout)
        XCTAssertEqual(completions.count, count)
        XCTAssertTrue(completions.values.allSatisfy { $0 == 1 })
        XCTAssertEqual(self.server.executions(tag: 100), count)
        disposables.forEach { $0.dispose() }
    }

    func testCancelledRequestNeverCompletes() {
        let session = self.makeSession()
        defer { session.stop() }
        let cancelled = self.request(tag: tagNever) { _ in
            XCTFail("a cancelled request must not complete")
        }
        let disposable = session.requestService.add(cancelled)
        disposable.dispose()
        let done = self.expectation(description: "next request completes")
        let next = session.requestService.add(self.request(tag: 8) { result in
            if case .failure = result {
                XCTFail("follow-up request failed")
            }
            done.fulfill()
        })
        self.wait(for: [done], timeout: RustEngineEndToEndTests.timeout)
        next.dispose()
    }

    func testFloodWaitAsksTheRequestBeforeRetrying() {
        let session = self.makeSession()
        defer { session.stop() }
        let lock = NSLock()
        var contexts: [NetworkEngineErrorContext] = []
        let done = self.expectation(description: "completed after the flood wait")
        let disposable = session.requestService.add(self.request(tag: tagFloodOnce, shouldContinueAfterError: { context in
            lock.lock()
            contexts.append(context)
            lock.unlock()
            return true
        }) { result in
            if case let .failure(failure) = result {
                XCTFail("\(failure.error.errorCode) \(failure.error.errorDescription ?? "")")
            }
            done.fulfill()
        })
        self.wait(for: [done], timeout: RustEngineEndToEndTests.timeout)
        disposable.dispose()
        XCTAssertEqual(contexts.count, 1)
        XCTAssertEqual(contexts.first?.floodWaitSeconds, 1)
        XCTAssertEqual(contexts.first?.floodWaitErrorText, "FLOOD_WAIT_1")
        XCTAssertEqual(self.server.executions(tag: tagFloodOnce), 2)
    }

    func testFloodWaitDeclinedByTheRequestFailsWithTheServerError() {
        let session = self.makeSession()
        defer { session.stop() }
        let done = self.expectation(description: "failed")
        let disposable = session.requestService.add(self.request(tag: tagFloodOnce, shouldContinueAfterError: { _ in false }) { result in
            switch result {
            case .success:
                XCTFail("declined flood wait must fail")
            case let .failure(failure):
                XCTAssertEqual(failure.error.errorCode, 420)
                XCTAssertEqual(failure.error.errorDescription, "FLOOD_WAIT_1")
            }
            done.fulfill()
        })
        self.wait(for: [done], timeout: RustEngineEndToEndTests.timeout)
        disposable.dispose()
    }

    func testDroppedConnectionCompletesOnceWithoutReexecution() {
        let session = self.makeSession()
        defer { session.stop() }
        let lock = NSLock()
        var completions = 0
        let done = self.expectation(description: "completed")
        let disposable = session.requestService.add(self.request(tag: tagDropConnectionOnce) { result in
            if case .failure = result {
                XCTFail("request failed")
            }
            lock.lock()
            completions += 1
            lock.unlock()
            done.fulfill()
        })
        self.wait(for: [done], timeout: RustEngineEndToEndTests.timeout)
        disposable.dispose()
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertEqual(completions, 1)
        let stats = self.server.stats()
        XCTAssertEqual(self.server.executions(tag: tagDropConnectionOnce), 1)
        XCTAssertGreaterThanOrEqual((stats["connections"] as? NSNumber)?.intValue ?? 0, 2)
        XCTAssertEqual((stats["state_requests"] as? NSNumber)?.intValue, 0)
    }

    func testServerSaltChangeIsPersistedThroughTheContext() {
        let session = self.makeSession()
        defer { session.stop() }
        let done = self.expectation(description: "completed")
        let disposable = session.requestService.add(self.request(tag: tagBadSaltOnce) { result in
            if case .failure = result {
                XCTFail("request failed")
            }
            done.fulfill()
        })
        self.wait(for: [done], timeout: RustEngineEndToEndTests.timeout)
        disposable.dispose()
        XCTAssertEqual(self.server.executions(tag: tagBadSaltOnce), 1)
        let expected = self.server.salt &+ 1
        let deadline = Date().addingTimeInterval(5.0)
        var persisted = false
        while Date() < deadline && !persisted {
            MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
            let authInfo = self.context.authInfoForDatacenter(withId: RustEngineEndToEndTests.datacenterId, selector: .persistent)
            persisted = authInfo?.saltSet.contains(where: { ($0 as? MTDatacenterSaltInfo)?.salt == expected }) ?? false
            if !persisted {
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
        XCTAssertTrue(persisted, "MTContext must stay the single writer of salts")
    }

    func testOnlyNonCdnSessionsMoveTheAppClock() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let cdn = self.engine.makeSession(datacenterId: datacenterId, role: .worker(masterDatacenterId: datacenterId, isMedia: false, isCdn: true), usageCalculationInfo: nil, delegate: nil)
        let main = self.engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        defer {
            cdn.stop()
            main.stop()
        }
        guard let cdnSession = cdn as? RustNetworkSession, let mainSession = main as? RustNetworkSession else {
            XCTFail("the Rust engine made a session of another type")
            return
        }
        let initial = self.context.globalTimeDifference()
        let deliver: (RustNetworkSession, Double) -> Void = { session, difference in
            var event = MTEvent()
            event.kind = MTEventKindTimeDifferenceUpdated
            event.value1 = difference
            session.handleEngineEvent(withUnsafePointer(to: &event) { RustEngineEvent($0) })
            MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        }

        deliver(cdnSession, initial + 86_400.0)
        XCTAssertEqual(self.context.globalTimeDifference(), initial, "a CDN must not set the app-wide clock")

        deliver(mainSession, initial + 30.0)
        XCTAssertEqual(self.context.globalTimeDifference(), initial + 30.0)
    }

    func testWorkerSessionSharesTheEngineWithTheMainSession() {
        let main = self.makeSession()
        let worker = self.makeSession(role: .worker(masterDatacenterId: RustEngineEndToEndTests.datacenterId, isMedia: true, isCdn: false))
        defer {
            main.stop()
            worker.stop()
        }
        let done = self.expectation(description: "both completed")
        done.expectedFulfillmentCount = 2
        let first = main.requestService.add(self.request(tag: 11) { result in
            if case .failure = result {
                XCTFail("main request failed")
            }
            done.fulfill()
        })
        let second = worker.requestService.add(self.request(tag: 12) { result in
            if case .failure = result {
                XCTFail("worker request failed")
            }
            done.fulfill()
        })
        self.wait(for: [done], timeout: RustEngineEndToEndTests.timeout)
        first.dispose()
        second.dispose()
    }
}
