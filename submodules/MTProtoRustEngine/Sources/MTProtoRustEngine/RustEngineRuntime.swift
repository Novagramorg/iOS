import Foundation
import SwiftSignalKit
import MtProtoKit
import TelegramCore
import MTProtoEngineFFI
import MTProtoRustEngineMapping

let rustEngineLogTag = "MTProtoRust"

func rustEngineLog(_ text: @autoclosure () -> String) {
    if MTLogEnabled() {
        Logger.shared.log(rustEngineLogTag, text())
    }
}

func rustEngineImportantLog(_ text: String) {
    Logger.shared.log(rustEngineLogTag, text)
    Logger.shared.shortLog(rustEngineLogTag, text)
}

final class RustEngineMailbox {
    weak var session: RustNetworkSession?
    let queue: Queue

    init(queue: Queue) {
        self.queue = queue
    }
}

private func rustEngineEventCallback(context: UnsafeMutableRawPointer?, session: MTSessionHandle, event: UnsafePointer<MTEvent>?) {
    guard let event = event else {
        return
    }
    let copied = RustEngineEvent(event)
    guard let context = context else {
        return
    }
    let runtime = Unmanaged<RustEngineRuntime>.fromOpaque(context).takeUnretainedValue()
    runtime.dispatch(handle: session, event: copied)
}

private func rustEngineLogCallback(context: UnsafeMutableRawPointer?, level: Int32, message: MTString) {
    if level > 1 && !MTLogEnabled() {
        return
    }
    let text = rustEngineString(message)
    if level <= 1 {
        Logger.shared.log(rustEngineLogTag, text)
        Logger.shared.shortLog(rustEngineLogTag, text)
    } else {
        Logger.shared.log(rustEngineLogTag, text)
    }
}

final class RustEngineRuntime: NSObject, MTNetworkAvailabilityDelegate {
    static let shared: RustEngineRuntime? = {
        let runtime = RustEngineRuntime()
        if runtime.engine == nil {
            rustEngineImportantLog("[MTProtoRust] mt_engine_create failed")
            return nil
        }
        runtime.start()
        return runtime
    }()

    private(set) var engine: OpaquePointer?
    private let lock = NSLock()
    private var mailboxes: [MTSessionHandle: RustEngineMailbox] = [:]
    private var networkAvailability: MTNetworkAvailability?
    private var isNetworkAvailableValue: Bool = true

    private override init() {
        super.init()

        rustEngineVerifyAssumptions()

        let abiVersion = mt_engine_abi_version()
        if abiVersion != 1 {
            rustEngineImportantLog("[MTProtoRust] unsupported engine ABI version \(abiVersion)")
            return
        }
        self.engine = mt_engine_create(0, Unmanaged.passUnretained(self).toOpaque(), rustEngineEventCallback, rustEngineLogCallback)
    }

    private func start() {
        self.networkAvailability = MTNetworkAvailability(delegate: self)
    }

    var isNetworkAvailable: Bool {
        self.lock.lock()
        let value = self.isNetworkAvailableValue
        self.lock.unlock()
        return value
    }

    func nextRequestId() -> UInt64 {
        guard let engine = self.engine else {
            return 0
        }
        return mt_engine_next_request_id(engine)
    }

    func createSession(setup: UnsafePointer<MTSessionSetup>, mailbox: RustEngineMailbox) -> MTSessionHandle {
        guard let engine = self.engine else {
            return 0
        }
        self.lock.lock()
        let handle = mt_session_create(engine, setup)
        if handle != 0 {
            self.mailboxes[handle] = mailbox
        }
        self.lock.unlock()
        return handle
    }

    func destroySession(handle: MTSessionHandle) {
        guard let engine = self.engine, handle != 0 else {
            return
        }
        self.lock.lock()
        self.mailboxes.removeValue(forKey: handle)
        self.lock.unlock()
        mt_session_destroy(engine, handle)
    }

    fileprivate func dispatch(handle: MTSessionHandle, event: RustEngineEvent) {
        self.lock.lock()
        let mailbox = self.mailboxes[handle]
        self.lock.unlock()
        guard let mailbox = mailbox else {
            return
        }
        mailbox.queue.async {
            mailbox.session?.handleEngineEvent(event)
        }
    }

    func networkAvailabilityChanged(_ networkAvailability: MTNetworkAvailability!, networkIsAvailable: Bool) {
        guard let engine = self.engine else {
            return
        }
        self.lock.lock()
        self.isNetworkAvailableValue = networkIsAvailable
        self.lock.unlock()

        rustEngineImportantLog("[MTProtoRust] network availability changed: \(networkIsAvailable ? "available" : "unavailable")")
        mt_engine_set_network_available(engine, networkIsAvailable ? 1 : 0)
        if networkIsAvailable {
            mt_engine_reset_connections(engine)
        }
    }
}

private func rustEngineVerifyAssumptions() {
    assert(RustEngineRequestFlags.automaticFloodWait == UInt32(MTRequestFlagAutomaticFloodWait))
    assert(RustEngineRequestFlags.reportFloodWait == UInt32(MTRequestFlagReportFloodWait))
    assert(RustEngineRequestFlags.retryServerErrors == UInt32(MTRequestFlagRetryServerErrors))
    assert(RustEngineRequestFlags.quickAck == UInt32(MTRequestFlagQuickAck))
    assert(RustEngineRequestFlags.progress == UInt32(MTRequestFlagProgress))
    assert(RustEngineRequestFlags.timeoutTimer == UInt32(MTRequestFlagTimeoutTimer))
    assert(RustEngineRequestFlags.withoutUpdates == UInt32(MTRequestFlagWithoutUpdates))
    assert(RustEngineRequestFlags.delegateRetryDecisions == UInt32(MTRequestFlagDelegateRetryDecisions))
    assert(RustEngineSessionRole.main.rawValue == UInt8(MTSessionRoleMain))
    assert(RustEngineSessionRole.worker.rawValue == UInt8(MTSessionRoleWorker))
    assert(RustEngineSessionRole.workerRequiringAuthToken.rawValue == UInt8(MTSessionRoleWorkerRequiringAuthToken))
    assert(RustEngineSessionRole.cdn.rawValue == UInt8(MTSessionRoleCdn))
    assert(RustEngineEventKind.retryDecisionRequired.rawValue == MTEventKindRetryDecisionRequired.rawValue)
    assert(RustEngineEventKind.completed.rawValue == MTEventKindCompleted.rawValue)
    assert(RustEngineEventKind.update.rawValue == MTEventKindUpdate.rawValue)
    assert(RustEngineEventKind.connectionState.rawValue == MTEventKindConnectionState.rawValue)
    assert(RustEngineVerificationKind.apns.rawValue == Int32(MTVerificationKindApns))
    assert(RustEngineVerificationKind.recaptcha.rawValue == Int32(MTVerificationKindRecaptcha))
    assert(RustContextListener.instancesRespond(to: NSSelectorFromString("contextDatacenterAuthInfoUpdated:datacenterId:authInfo:selector:")))
    assert(RustContextListener.instancesRespond(to: NSSelectorFromString("contextDatacenterAuthTokenUpdated:datacenterId:authToken:")))
    assert(RustContextListener.instancesRespond(to: NSSelectorFromString("contextDatacenterAuthInfoRequestFailed:datacenterId:selector:")))
    assert(RustContextListener.instancesRespond(to: NSSelectorFromString("contextDatacenterAuthTokenTransferFailed:datacenterId:")))
    assert(RustContextListener.instancesRespond(to: NSSelectorFromString("contextDatacenterTransportSchemesUpdated:datacenterId:shouldReset:")))
    assert(RustContextListener.instancesRespond(to: NSSelectorFromString("contextApiEnvironmentUpdated:apiEnvironment:")))
    assert(!RustContextListener.instancesRespond(to: NSSelectorFromString("isContextNetworkAccessAllowed:")))
    assert(!RustContextListener.instancesRespond(to: NSSelectorFromString("contextLoggedOut:")))
}
