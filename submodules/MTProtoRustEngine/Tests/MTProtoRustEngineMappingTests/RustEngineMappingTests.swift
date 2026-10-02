import XCTest
@testable import MTProtoRustEngineMapping

final class RustEngineMappingTests: XCTestCase {
    func testRequestFlagsAlwaysDelegateRetryDecisions() {
        let flags = rustEngineRequestFlags(wantsQuickAck: false, wantsProgress: false, needsTimeoutTimer: false, withoutUpdates: false)
        XCTAssertEqual(flags, RustEngineRequestFlags.delegateRetryDecisions)
        XCTAssertEqual(flags & RustEngineRequestFlags.automaticFloodWait, 0)
        XCTAssertEqual(flags & RustEngineRequestFlags.retryServerErrors, 0)
        XCTAssertEqual(flags & RustEngineRequestFlags.reportFloodWait, 0)
    }

    func testRequestFlagsFollowRequestFields() {
        let all = rustEngineRequestFlags(wantsQuickAck: true, wantsProgress: true, needsTimeoutTimer: true, withoutUpdates: true)
        XCTAssertEqual(all, RustEngineRequestFlags.delegateRetryDecisions | RustEngineRequestFlags.quickAck | RustEngineRequestFlags.progress | RustEngineRequestFlags.timeoutTimer | RustEngineRequestFlags.withoutUpdates)
        let ackOnly = rustEngineRequestFlags(wantsQuickAck: true, wantsProgress: false, needsTimeoutTimer: false, withoutUpdates: false)
        XCTAssertEqual(ackOnly, RustEngineRequestFlags.delegateRetryDecisions | RustEngineRequestFlags.quickAck)
    }

    func testHeaderBitValues() {
        XCTAssertEqual(RustEngineRequestFlags.automaticFloodWait, 1)
        XCTAssertEqual(RustEngineRequestFlags.reportFloodWait, 2)
        XCTAssertEqual(RustEngineRequestFlags.retryServerErrors, 4)
        XCTAssertEqual(RustEngineRequestFlags.quickAck, 8)
        XCTAssertEqual(RustEngineRequestFlags.progress, 16)
        XCTAssertEqual(RustEngineRequestFlags.timeoutTimer, 32)
        XCTAssertEqual(RustEngineRequestFlags.withoutUpdates, 64)
        XCTAssertEqual(RustEngineRequestFlags.delegateRetryDecisions, 128)
    }

    func testNoopFlagsHaveNoErrorGate() {
        XCTAssertEqual(rustEngineNoopFlags(withoutUpdates: false), RustEngineRequestFlags.automaticFloodWait)
        XCTAssertEqual(rustEngineNoopFlags(withoutUpdates: true), RustEngineRequestFlags.automaticFloodWait | RustEngineRequestFlags.withoutUpdates)
    }

    func testExpectedResponseSize() {
        XCTAssertEqual(rustEngineExpectedResponseSize(0), 0)
        XCTAssertEqual(rustEngineExpectedResponseSize(-5), 0)
        XCTAssertEqual(rustEngineExpectedResponseSize(512 * 1024), 512 * 1024)
        XCTAssertEqual(rustEngineExpectedResponseSize(Int32.max), UInt32(Int32.max))
    }

    func testSaltConversionRoundTrip() {
        let first: Int64 = 1_760_000_000 << 32
        let last: Int64 = (1_760_000_000 + 1800) << 32
        let salt = rustEngineSalt(salt: 0x1234_5678_9abc_def0, firstValidMessageId: first, lastValidMessageId: last)
        XCTAssertEqual(salt.salt, 0x1234_5678_9abc_def0)
        XCTAssertEqual(salt.validSince, 1_760_000_000, accuracy: 0.000001)
        XCTAssertEqual(salt.validUntil, 1_760_001_800, accuracy: 0.000001)
        let range = rustEngineMessageIdRange(salt)
        XCTAssertEqual(range?.first, first)
        XCTAssertEqual(range?.last, last)
    }

    func testFractionalSaltWindow() {
        let salt = RustEngineSalt(salt: 7, validSince: 1_760_000_000.5, validUntil: 1_760_000_600.25)
        let range = rustEngineMessageIdRange(salt)
        XCTAssertEqual(range?.first, (1_760_000_000 << 32) + (1 << 31))
        XCTAssertEqual(range?.last, (1_760_000_600 << 32) + (1 << 30))
    }

    func testPlaceholderSaltIsDropped() {
        XCTAssertNil(rustEngineMessageIdRange(RustEngineSalt(salt: 0, validSince: -.infinity, validUntil: -.infinity)))
        XCTAssertNil(rustEngineMessageIdRange(RustEngineSalt(salt: 0, validSince: 0, validUntil: .infinity)))
        XCTAssertNil(rustEngineMessageIdRange(RustEngineSalt(salt: 0, validSince: .nan, validUntil: 10)))
        XCTAssertNil(rustEngineMessageIdRange(RustEngineSalt(salt: 0, validSince: 10, validUntil: 10)))
        XCTAssertNil(rustEngineMessageId(seconds: 1e30))
    }

    func testDependencyScansNewestFirst() {
        let candidates = [(id: 1, peer: 10), (id: 2, peer: 20), (id: 3, peer: 10), (id: 4, peer: 30)]
        let index = rustEngineDependencyIndex(candidates: candidates, accepts: { $0.peer == 10 })
        XCTAssertEqual(index.map { candidates[$0].id }, 3)
        XCTAssertNil(rustEngineDependencyIndex(candidates: candidates, accepts: { $0.peer == 40 }))
        XCTAssertNil(rustEngineDependencyIndex(candidates: [Int](), accepts: { _ in true }))
    }

    func testErrorStateIsCumulative() {
        var state = RustEngineErrorState()
        let flood = state.applyRetryDecision(floodWaitSeconds: 3, floodWaitErrorText: "FLOOD_WAIT_3", serverErrors: 0)
        XCTAssertEqual(flood, RustEngineErrorState.Context(floodWaitSeconds: 3, floodWaitErrorText: "FLOOD_WAIT_3", internalServerErrorCount: 0))
        let server = state.applyRetryDecision(floodWaitSeconds: 3, floodWaitErrorText: "FLOOD_WAIT_3", serverErrors: 1)
        XCTAssertEqual(server, RustEngineErrorState.Context(floodWaitSeconds: 3, floodWaitErrorText: "FLOOD_WAIT_3", internalServerErrorCount: 1))
        let parse = state.applyParseFailure()
        XCTAssertEqual(parse.internalServerErrorCount, 2)
        XCTAssertEqual(parse.floodWaitSeconds, 3)
        state.didResubmit()
        let afterResubmit = state.applyRetryDecision(floodWaitSeconds: 0, floodWaitErrorText: nil, serverErrors: 1)
        XCTAssertEqual(afterResubmit, RustEngineErrorState.Context(floodWaitSeconds: 3, floodWaitErrorText: "FLOOD_WAIT_3", internalServerErrorCount: 3))
    }

    func testErrorStateZeroFloodWaitKeepsText() {
        var state = RustEngineErrorState()
        let context = state.applyRetryDecision(floodWaitSeconds: 0, floodWaitErrorText: "FLOOD_WAIT_0", serverErrors: 0)
        XCTAssertEqual(context.floodWaitSeconds, 0)
        XCTAssertEqual(context.floodWaitErrorText, "FLOOD_WAIT_0")
    }

    func testParseFailurePolicyCapsAtThreeAttempts() {
        XCTAssertTrue(RustEngineParseFailurePolicy.shouldResubmit(parseFailures: 1, gateAllowsRetry: true))
        XCTAssertTrue(RustEngineParseFailurePolicy.shouldResubmit(parseFailures: 2, gateAllowsRetry: true))
        XCTAssertFalse(RustEngineParseFailurePolicy.shouldResubmit(parseFailures: 3, gateAllowsRetry: true))
        XCTAssertFalse(RustEngineParseFailurePolicy.shouldResubmit(parseFailures: 1, gateAllowsRetry: false))
        XCTAssertEqual(RustEngineParseFailurePolicy.errorCode, 500)
        XCTAssertEqual(RustEngineParseFailurePolicy.errorText, "TL_PARSING_ERROR")
        XCTAssertEqual(RustEngineParseFailurePolicy.retryDelay, 2.0)
    }

    func testMissingKeyActionMatchesMtProtoKit() {
        XCTAssertEqual(rustEngineMissingKeyAction(isCdn: true, requiresForeignAuthToken: false, selectorIsEphemeral: false), .dropAndRequire(isCdn: true))
        XCTAssertEqual(rustEngineMissingKeyAction(isCdn: false, requiresForeignAuthToken: true, selectorIsEphemeral: true), .removeTokenDropAndRequire)
        XCTAssertEqual(rustEngineMissingKeyAction(isCdn: false, requiresForeignAuthToken: true, selectorIsEphemeral: false), .removeTokenDropAndRequire)
        XCTAssertEqual(rustEngineMissingKeyAction(isCdn: false, requiresForeignAuthToken: false, selectorIsEphemeral: true), .dropAndRequire(isCdn: false))
        XCTAssertEqual(rustEngineMissingKeyAction(isCdn: false, requiresForeignAuthToken: false, selectorIsEphemeral: false), .checkIfLoggedOut)
    }

    func testWorkerAuthorizationErrors() {
        XCTAssertTrue(rustEngineWorkerShouldTransferAuthToken(code: 401, text: "AUTH_KEY_UNREGISTERED"))
        XCTAssertTrue(rustEngineWorkerShouldTransferAuthToken(code: 401, text: "SESSION_REVOKED"))
        XCTAssertTrue(rustEngineWorkerShouldTransferAuthToken(code: 401, text: "USER_DEACTIVATED"))
        XCTAssertFalse(rustEngineWorkerShouldTransferAuthToken(code: 401, text: "SESSION_PASSWORD_NEEDED"))
        XCTAssertFalse(rustEngineWorkerShouldTransferAuthToken(code: 400, text: "AUTH_KEY_UNREGISTERED"))
        XCTAssertFalse(rustEngineWorkerShouldTransferAuthToken(code: 406, text: "AUTH_KEY_DUPLICATED"))
    }

    func testSessionRoles() {
        XCTAssertEqual(rustEngineSessionRole(isMain: true, isCdn: false, datacenterId: 2, masterDatacenterId: 2), .main)
        XCTAssertEqual(rustEngineSessionRole(isMain: false, isCdn: false, datacenterId: 2, masterDatacenterId: 2), .worker)
        XCTAssertEqual(rustEngineSessionRole(isMain: false, isCdn: false, datacenterId: 4, masterDatacenterId: 2), .workerRequiringAuthToken)
        XCTAssertEqual(rustEngineSessionRole(isMain: false, isCdn: true, datacenterId: 203, masterDatacenterId: 2), .cdn)
        XCTAssertEqual(RustEngineSessionRole.main.rawValue, 0)
        XCTAssertEqual(RustEngineSessionRole.worker.rawValue, 1)
        XCTAssertEqual(RustEngineSessionRole.workerRequiringAuthToken.rawValue, 2)
        XCTAssertEqual(RustEngineSessionRole.cdn.rawValue, 3)
        XCTAssertFalse(rustEngineRequiresForeignAuthToken(isMain: true, isCdn: false, datacenterId: 4, masterDatacenterId: 2))
        XCTAssertFalse(rustEngineRequiresForeignAuthToken(isMain: false, isCdn: true, datacenterId: 4, masterDatacenterId: 2))
    }

    func testObfuscationDatacenterId() {
        XCTAssertEqual(rustEngineObfuscationDatacenterId(datacenterId: 2, isTestingEnvironment: false, preferForMedia: false), 2)
        XCTAssertEqual(rustEngineObfuscationDatacenterId(datacenterId: 2, isTestingEnvironment: false, preferForMedia: true), -2)
        XCTAssertEqual(rustEngineObfuscationDatacenterId(datacenterId: 2, isTestingEnvironment: true, preferForMedia: false), 10002)
        XCTAssertEqual(rustEngineObfuscationDatacenterId(datacenterId: 2, isTestingEnvironment: true, preferForMedia: true), -10002)
        XCTAssertEqual(rustEngineObfuscationDatacenterId(datacenterId: 203, isTestingEnvironment: false, preferForMedia: false), 203)
    }

    func testAddressOrder() {
        XCTAssertEqual(rustEngineAddressOrder(isIpv6: [false, true, false], preferredIndex: 2, allowIpv6: false), [2, 0])
        XCTAssertEqual(rustEngineAddressOrder(isIpv6: [false, true, false], preferredIndex: 1, allowIpv6: true), [1, 0, 2])
        XCTAssertEqual(rustEngineAddressOrder(isIpv6: [false, true, false], preferredIndex: nil, allowIpv6: true), [0, 2, 1])
        XCTAssertEqual(rustEngineAddressOrder(isIpv6: [true, true], preferredIndex: nil, allowIpv6: false), [0, 1])
        XCTAssertEqual(rustEngineAddressOrder(isIpv6: [false], preferredIndex: 5, allowIpv6: false), [0])
        XCTAssertEqual(rustEngineAddressOrder(isIpv6: [], preferredIndex: nil, allowIpv6: true), [])
    }

    func testConnectionFlags() {
        let none = RustEngineConnectionFlags(rawValue: 0)
        XCTAssertFalse(none.isNetworkAvailable || none.isConnected || none.isUpdatingConnectionContext || none.isPerformingServiceTasks || none.proxyHasConnectionIssues)
        let all = RustEngineConnectionFlags(rawValue: 31)
        XCTAssertTrue(all.isNetworkAvailable && all.isConnected && all.isUpdatingConnectionContext && all.isPerformingServiceTasks && all.proxyHasConnectionIssues)
        let connected = RustEngineConnectionFlags(rawValue: 1 | 2)
        XCTAssertTrue(connected.isNetworkAvailable)
        XCTAssertTrue(connected.isConnected)
        XCTAssertFalse(connected.isUpdatingConnectionContext)
        let proxyIssues = RustEngineConnectionFlags(rawValue: 1 | 16)
        XCTAssertTrue(proxyIssues.proxyHasConnectionIssues)
        XCTAssertFalse(proxyIssues.isConnected)
    }

    func testUpdatesTooLongDetection() {
        XCTAssertTrue(rustEngineIsUpdatesTooLong(Data([0x7e, 0xaf, 0x17, 0xe3])))
        XCTAssertTrue(rustEngineIsUpdatesTooLong(Data([0x7e, 0xaf, 0x17, 0xe3, 0x00])))
        XCTAssertFalse(rustEngineIsUpdatesTooLong(Data([0x7e, 0xaf, 0x17])))
        XCTAssertFalse(rustEngineIsUpdatesTooLong(Data([0x78, 0x2e, 0xe3, 0x74])))
        let sliced = Data([0xff, 0x7e, 0xaf, 0x17, 0xe3]).dropFirst()
        XCTAssertTrue(rustEngineIsUpdatesTooLong(sliced))
    }

    func testVerificationMapping() {
        XCTAssertEqual(RustEngineVerificationKind(rawValue: 1), .apns)
        XCTAssertEqual(RustEngineVerificationKind(rawValue: 2), .recaptcha)
        XCTAssertNil(RustEngineVerificationKind(rawValue: 3))
        XCTAssertEqual(RustEngineVerificationKind.apns.timeoutErrorText, "APNS_PUSH_TIMEOUT")
        XCTAssertEqual(RustEngineVerificationKind.recaptcha.timeoutErrorText, "RECAPTCHA_TIMEOUT")
        XCTAssertGreaterThan(RustEngineVerificationKind.timeout, 15.0)
    }

    func testOptionalText() {
        XCTAssertNil(rustEngineOptionalText(""))
        XCTAssertEqual(rustEngineOptionalText("FLOOD_WAIT_5"), "FLOOD_WAIT_5")
    }

    func testMainSessionAuthorizationRequiredLogsOut() {
        // A main-session 401 must reach Network.loggedOut, as with MtProtoKit: a session terminated
        // from another device has to drop the account. Routing it through MTContext.checkIfLoggedOut
        // instead never logged out, because that probe completes on the session's own stored
        // temporary key without contacting the server.
        XCTAssertEqual(rustEngineAuthorizationRequiredAction(isMain: true), .logOut)
        XCTAssertEqual(rustEngineAuthorizationRequiredAction(isMain: false), .ignore)
    }
}
