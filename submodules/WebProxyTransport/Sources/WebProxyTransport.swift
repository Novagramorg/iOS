import Foundation
import MtProtoKit
import SwiftSignalKit

public enum WebProxyCarrierStatus: Equatable {
    case inactive
    case connecting
    case ready
    case failed
}

public protocol WebProxyCarrier: AnyObject {
    func apply(configuration: WebProxyConfiguration?)
    func setViewHost(_ host: WebProxyCarrierViewHost?)
    func makeConnectionInterface(delegate: MTTcpConnectionInterfaceDelegate, delegateQueue: DispatchQueue) -> MTTcpConnectionInterface
    var statusSignal: Signal<WebProxyCarrierStatus, NoError> { get }
}

public final class WebProxyTransport: WebProxyCarrier {
    public static let shared = WebProxyTransport()

    private enum CarrierState {
        case inactive
        case loading
        case waitingForWelcome
        case ready
    }

    private final class StreamState {
        weak var connection: WebProxyConnectionInterface?
        var opened = false
        var closing = false
        var sendCredit = WebProxyProtocol.initialWindow
        var receiveCredit = WebProxyProtocol.initialWindow
        var pendingWrites: [Data] = []
        var pendingWriteBytes = 0

        init(connection: WebProxyConnectionInterface) {
            self.connection = connection
        }
    }

    private let queue = DispatchQueue(label: "org.telegram.WebProxyTransport")
    private let statusPromise = ValuePromise<WebProxyCarrierStatus>(.inactive, ignoreRepeated: true)

    private var configuration: WebProxyConfiguration?
    private var demand = WebProxyDemandSet()
    /// Main-queue confined; never touched from `self.queue`.
    private let viewAttachment = WebProxyViewAttachment()
    private var carrier: WebProxyWebViewCarrier?
    private var carrierState: CarrierState = .inactive
    private var generation: UInt64 = 0
    private var nextStreamId: UInt32 = 1
    private var streams: [UInt32: StreamState] = [:]
    private var tombstones: [UInt32] = []
    private var tombstoneSet = Set<UInt32>()
    private var queuedBytes = 0
    private var queuedItems = 0
    private var incomingBytes = 0
    private var retryAttempt = 0
    private var retryWorkItem: DispatchWorkItem?
    private var handshakeTimeoutWorkItem: DispatchWorkItem?
    private var stableResetWorkItem: DispatchWorkItem?
    private var decoder = WebProxyFrameDecoder()
    private var lastPageStatus: WebProxyPageStatus?

    private init() {
    }

    public var statusSignal: Signal<WebProxyCarrierStatus, NoError> {
        return self.statusPromise.get()
    }

    public func apply(configuration: WebProxyConfiguration?) {
        self.queue.async {
            guard self.configuration != configuration else { return }
            if configuration == nil {
                WebProxyDiagnostics.info("configuration disabled")
            } else {
                WebProxyDiagnostics.info("configuration applied")
            }
            self.configuration = configuration
            self.stopCarrier(reportInactive: false)
            self.retryAttempt = 0
            self.updateCarrierActivation()
        }
    }

    public func setViewHost(_ host: WebProxyCarrierViewHost?) {
        DispatchQueue.main.async {
            self.viewAttachment.setHost(host)
        }
    }

    /// Registers or releases one holder's interest in the carrier. Idempotent per token.
    public func setCarrierDemand(_ token: AnyHashable, wanted: Bool) {
        self.queue.async {
            guard self.demand.set(token, wanted: wanted) else { return }
            if wanted {
                self.retryAttempt = 0
            }
            self.updateCarrierActivation()
        }
    }

    /// The carrier runs exactly while a configuration is present and someone wants it.
    private func updateCarrierActivation() {
        if self.configuration != nil && !self.demand.isEmpty {
            guard self.carrierState == .inactive, self.retryWorkItem == nil else { return }
            self.startCarrier()
        } else {
            self.stopCarrier(reportInactive: true)
        }
    }

    public func makeConnectionInterface(delegate: MTTcpConnectionInterfaceDelegate, delegateQueue: DispatchQueue) -> MTTcpConnectionInterface {
        return WebProxyConnectionInterface(transport: self, delegate: delegate, delegateQueue: delegateQueue)
    }

    fileprivate func open(_ connection: WebProxyConnectionInterface, timeout: TimeInterval) {
        self.queue.async {
            guard self.configuration != nil, self.nextStreamId <= WebProxyProtocol.maximumStreamId else {
                connection.transportDidClose(error: WebProxyTransportError.unavailable)
                if self.nextStreamId > WebProxyProtocol.maximumStreamId {
                    self.failCarrier(.streamIdExhausted)
                }
                return
            }
            let streamId = self.nextStreamId
            self.nextStreamId += 1
            self.streams[streamId] = StreamState(connection: connection)
            connection.assign(streamId: streamId)
            if self.carrierState == .ready {
                self.openStream(streamId)
            }
            if timeout >= 0.0 {
                self.queue.asyncAfter(deadline: .now() + timeout) {
                    guard let stream = self.streams[streamId],
                          stream.connection === connection,
                          !stream.opened else { return }
                    self.closeStream(streamId, sendClose: false, error: WebProxyTransportError.timeout)
                }
            }
        }
    }

    fileprivate func write(_ connection: WebProxyConnectionInterface, data: Data) {
        guard !data.isEmpty else { return }
        self.queue.async {
            guard let streamId = connection.streamId,
                  let stream = self.streams[streamId],
                  !stream.closing else { return }
            let newStreamBytes = stream.pendingWriteBytes + data.count
            let newGlobalBytes = self.queuedBytes + data.count
            guard newStreamBytes <= 8 * 1024 * 1024,
                  newGlobalBytes <= WebProxyProtocol.maximumQueuedBytes,
                  stream.pendingWrites.count < WebProxyProtocol.maximumQueuedItems,
                  self.queuedItems < WebProxyProtocol.maximumQueuedItems else {
                self.closeStream(streamId, sendClose: true, error: WebProxyTransportError.queueLimitExceeded)
                return
            }
            stream.pendingWrites.append(data)
            stream.pendingWriteBytes = newStreamBytes
            self.queuedBytes = newGlobalBytes
            self.queuedItems += 1
            self.flushWrites(streamId)
        }
    }

    fileprivate func read(_ connection: WebProxyConnectionInterface, length: Int, timeout: TimeInterval, tag: Int) {
        self.queue.async {
            guard let streamId = connection.streamId,
                  self.streams[streamId] != nil else { return }
            let consumed = connection.enqueueRead(length: length, tag: tag)
            self.grantWindow(streamId: streamId, consumed: consumed)
            if timeout >= 0.0, connection.hasPendingRead(tag: tag) {
                self.queue.asyncAfter(deadline: .now() + timeout) {
                    guard connection.hasPendingRead(tag: tag),
                          connection.streamId == streamId else { return }
                    self.closeStream(streamId, sendClose: true, error: WebProxyTransportError.timeout)
                }
            }
        }
    }

    fileprivate func close(_ connection: WebProxyConnectionInterface) {
        self.queue.async {
            guard let streamId = connection.streamId else {
                connection.transportDidClose(error: nil)
                return
            }
            self.closeStream(streamId, sendClose: true, error: nil)
        }
    }

    private func startCarrier() {
        guard let configuration = self.configuration else { return }
        self.generation &+= 1
        let generation = self.generation
        self.carrierState = .loading
        self.statusPromise.set(.connecting)
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            guard let self, self.generation == generation, self.carrierState != .ready else { return }
            self.failCarrier(.initializationTimeout)
        }
        self.handshakeTimeoutWorkItem = timeoutWorkItem
        self.queue.asyncAfter(deadline: .now() + 25.0, execute: timeoutWorkItem)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let carrier = WebProxyWebViewCarrier(
                configuration: configuration,
                generation: generation,
                received: { [weak self] generation, message in
                    self?.queue.async { self?.receive(message: message, generation: generation) }
                },
                failed: { [weak self] generation, reason in
                    self?.queue.async {
                        guard self?.generation == generation else { return }
                        self?.failCarrier(reason)
                    }
                }
            ) else {
                self.queue.async { self.failCarrier(.construction) }
                return
            }
            self.queue.async {
                guard self.generation == generation, self.configuration == configuration else {
                    DispatchQueue.main.async {
                        self.viewAttachment.setWebView(nil)
                        carrier.invalidate()
                    }
                    return
                }
                self.carrier = carrier
                WebProxyDiagnostics.info("webview carrier created")
                DispatchQueue.main.async {
                    self.viewAttachment.setWebView(carrier.hostedWebView)
                    carrier.start()
                }
            }
        }
    }

    private func stopCarrier(reportInactive: Bool) {
        self.retryWorkItem?.cancel()
        self.retryWorkItem = nil
        self.handshakeTimeoutWorkItem?.cancel()
        self.handshakeTimeoutWorkItem = nil
        self.stableResetWorkItem?.cancel()
        self.stableResetWorkItem = nil
        self.generation &+= 1
        let carrier = self.carrier
        self.carrier = nil
        self.carrierState = .inactive
        for (_, stream) in self.streams {
            stream.connection?.transportDidClose(error: WebProxyTransportError.carrierClosed)
        }
        self.streams.removeAll()
        self.tombstones.removeAll()
        self.tombstoneSet.removeAll()
        self.queuedBytes = 0
        self.queuedItems = 0
        self.incomingBytes = 0
        self.nextStreamId = 1
        self.decoder = WebProxyFrameDecoder()
        self.lastPageStatus = nil
        DispatchQueue.main.async {
            self.viewAttachment.setWebView(nil)
            carrier?.invalidate()
        }
        if reportInactive {
            self.statusPromise.set(.inactive)
        }
    }

    private func failCarrier(_ reason: WebProxyCarrierFailure) {
        guard self.configuration != nil else { return }
        WebProxyDiagnostics.failure(reason)
        self.statusPromise.set(.failed)
        self.stopCarrier(reportInactive: false)
        guard self.configuration != nil, !self.demand.isEmpty else { return }
        let delay = min(30.0, pow(2.0, Double(self.retryAttempt)))
        self.retryAttempt = min(self.retryAttempt + 1, 6)
        let jitter = Double.random(in: 0 ... min(1.0, delay * 0.2))
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.configuration != nil else { return }
            self.retryWorkItem = nil
            self.startCarrier()
        }
        self.retryWorkItem = workItem
        self.queue.asyncAfter(deadline: .now() + delay + jitter, execute: workItem)
    }

    private func receive(message: WebProxyPageMessage, generation: UInt64) {
        guard generation == self.generation else { return }
        switch message {
        case let .control(value):
            let control: WebProxyControlMessage
            do {
                control = try WebProxyControlMessage.decode(value)
            } catch WebProxyControlMessageError.invalidInitialization {
                self.failCarrier(.invalidInitialization)
                return
            } catch {
                self.failCarrier(.invalidControlMessage)
                return
            }

            switch control {
            case let .initialize(nonce):
                guard self.carrierState == .loading, nonce == self.carrier?.nonce else {
                    self.failCarrier(.invalidInitialization)
                    return
                }
                WebProxyDiagnostics.info("page initialization accepted")
                self.carrierState = .waitingForWelcome
                self.send(frame: WebProxyFrame(type: .hello, streamId: 0, payload: Data([1])))
                WebProxyDiagnostics.info("hello sent")
            case let .status(status):
                if self.lastPageStatus != status {
                    self.lastPageStatus = status
                    WebProxyDiagnostics.pageStatus(status)
                }
            case .traffic:
                break
            case .close:
                self.failCarrier(.remoteClose)
            }
        case let .binary(data):
            guard let frames = try? self.decoder.append(data) else {
                self.failCarrier(.frameDecode)
                return
            }
            for frame in frames {
                self.receive(frame: frame)
            }
        }
    }

    private func receive(frame: WebProxyFrame) {
        if self.carrierState != .ready && !(self.carrierState == .waitingForWelcome && frame.type == .welcome) {
            self.failCarrier(.protocolViolation)
            return
        }
        switch frame.type {
        case .welcome:
            guard self.carrierState == .waitingForWelcome else {
                self.failCarrier(.protocolViolation)
                return
            }
            self.carrierState = .ready
            self.handshakeTimeoutWorkItem?.cancel()
            self.handshakeTimeoutWorkItem = nil
            let generation = self.generation
            let stableResetWorkItem = DispatchWorkItem { [weak self] in
                guard let self, self.generation == generation, self.carrierState == .ready else { return }
                self.retryAttempt = 0
                self.stableResetWorkItem = nil
            }
            self.stableResetWorkItem = stableResetWorkItem
            self.queue.asyncAfter(deadline: .now() + 30.0, execute: stableResetWorkItem)
            self.statusPromise.set(.ready)
            WebProxyDiagnostics.info("welcome accepted; carrier ready")
            for streamId in self.streams.keys.sorted() {
                self.openStream(streamId)
            }
        case .data:
            guard self.carrierState == .ready else { self.failCarrier(.protocolViolation); return }
            guard let stream = self.streams[frame.streamId] else {
                if !self.tombstoneSet.contains(frame.streamId) { self.failCarrier(.protocolViolation) }
                return
            }
            guard frame.payload.count <= stream.receiveCredit else {
                self.closeStream(frame.streamId, sendClose: true, error: WebProxyTransportError.flowControlViolation)
                return
            }
            stream.receiveCredit -= frame.payload.count
            guard let connection = stream.connection else {
                self.closeStream(frame.streamId, sendClose: true, error: nil)
                return
            }
            let consumed = connection.enqueueIncoming(frame.payload)
            self.incomingBytes += frame.payload.count
            guard connection.bufferedIncomingBytes <= 8 * 1024 * 1024,
                  self.incomingBytes - consumed <= WebProxyProtocol.maximumQueuedBytes else {
                self.incomingBytes = max(0, self.incomingBytes - consumed)
                self.closeStream(frame.streamId, sendClose: true, error: WebProxyTransportError.queueLimitExceeded)
                return
            }
            self.grantWindow(streamId: frame.streamId, consumed: consumed)
        case .window:
            guard let delta = frame.windowDelta, let stream = self.streams[frame.streamId] else {
                if !self.tombstoneSet.contains(frame.streamId) { self.failCarrier(.protocolViolation) }
                return
            }
            guard UInt64(stream.sendCredit) + UInt64(delta) <= UInt64(UInt32.max) else {
                self.closeStream(frame.streamId, sendClose: true, error: WebProxyTransportError.flowControlViolation)
                return
            }
            stream.sendCredit += Int(delta)
            self.flushWrites(frame.streamId)
        case .close:
            if self.streams[frame.streamId] != nil {
                self.closeStream(frame.streamId, sendClose: false, error: nil)
            } else if !self.tombstoneSet.contains(frame.streamId) {
                self.failCarrier(.protocolViolation)
            }
        case .ping:
            self.send(frame: WebProxyFrame(type: .pong, streamId: 0, payload: frame.payload))
        case .pong:
            break
        case .bye:
            self.failCarrier(.remoteClose)
        case .open, .hello:
            self.failCarrier(.protocolViolation)
        }
    }

    private func openStream(_ streamId: UInt32) {
        guard self.carrierState == .ready,
              let stream = self.streams[streamId],
              !stream.opened,
              !stream.closing else { return }
        stream.opened = true
        self.send(frame: WebProxyFrame(type: .open, streamId: streamId))
        stream.connection?.transportDidOpen()
        self.flushWrites(streamId)
    }

    private func flushWrites(_ streamId: UInt32) {
        guard self.carrierState == .ready,
              let stream = self.streams[streamId],
              stream.opened,
              !stream.closing else { return }
        while stream.sendCredit > 0, !stream.pendingWrites.isEmpty {
            let data = stream.pendingWrites.removeFirst()
            let count = min(data.count, stream.sendCredit, WebProxyProtocol.maximumDataPayload)
            let chunk = data.prefix(count)
            if count < data.count {
                stream.pendingWrites.insert(Data(data.dropFirst(count)), at: 0)
            } else {
                self.queuedItems -= 1
            }
            stream.pendingWriteBytes -= count
            self.queuedBytes -= count
            stream.sendCredit -= count
            self.send(frame: WebProxyFrame(type: .data, streamId: streamId, payload: Data(chunk)))
        }
    }

    private func grantWindow(streamId: UInt32, consumed: Int) {
        guard consumed > 0, let stream = self.streams[streamId] else { return }
        self.incomingBytes = max(0, self.incomingBytes - consumed)
        stream.receiveCredit += consumed
        var remaining = consumed
        while remaining > 0 {
            let delta = UInt32(min(remaining, Int(UInt32.max)))
            self.send(frame: .window(streamId: streamId, delta: delta))
            remaining -= Int(delta)
        }
    }

    private func closeStream(_ streamId: UInt32, sendClose: Bool, error: Error?) {
        guard let stream = self.streams.removeValue(forKey: streamId) else { return }
        stream.closing = true
        self.queuedBytes -= stream.pendingWriteBytes
        self.queuedItems -= stream.pendingWrites.count
        self.incomingBytes = max(0, self.incomingBytes - (stream.connection?.bufferedIncomingBytes ?? 0))
        if sendClose, stream.opened, self.carrierState == .ready {
            self.send(frame: WebProxyFrame(type: .close, streamId: streamId))
        }
        self.addTombstone(streamId)
        stream.connection?.transportDidClose(error: error)
    }

    private func addTombstone(_ streamId: UInt32) {
        self.tombstones.append(streamId)
        self.tombstoneSet.insert(streamId)
        if self.tombstones.count > WebProxyProtocol.tombstoneCount {
            self.tombstoneSet.remove(self.tombstones.removeFirst())
        }
    }

    private func send(frame: WebProxyFrame) {
        guard let data = try? WebProxyFrameEncoder.encode(frame), let carrier = self.carrier else {
            self.failCarrier(.protocolViolation)
            return
        }
        DispatchQueue.main.async { carrier.send(data: data) }
    }
}

public enum WebProxyTransportError: Error {
    case unavailable
    case carrierClosed
    case queueLimitExceeded
    case flowControlViolation
    case timeout
}

public final class WebProxyConnectionInterface: NSObject, MTTcpConnectionInterface {
    private struct ReadRequest {
        let length: Int
        let tag: Int
    }

    private weak var delegate: MTTcpConnectionInterfaceDelegate?
    private let delegateQueue: DispatchQueue
    private unowned let transport: WebProxyTransport
    fileprivate var streamId: UInt32?
    fileprivate var bufferedIncomingBytes: Int { self.incoming.count }
    private var incoming = Data()
    private var reads: [ReadRequest] = []
    private var closed = false

    fileprivate init(transport: WebProxyTransport, delegate: MTTcpConnectionInterfaceDelegate, delegateQueue: DispatchQueue) {
        self.transport = transport
        self.delegate = delegate
        self.delegateQueue = delegateQueue
    }

    public func setGetLogPrefix(_ getLogPrefix: (() -> String)?) {
    }

    public func setUsageCalculationInfo(_ usageCalculationInfo: MTNetworkUsageCalculationInfo?) {
    }

    public func connect(toHost inHost: String, onPort port: UInt16, viaInterface inInterface: String?, withTimeout timeout: TimeInterval, error errPtr: NSErrorPointer) -> Bool {
        self.transport.open(self, timeout: timeout)
        return true
    }

    public func write(_ data: Data) {
        self.transport.write(self, data: data)
    }

    public func readData(toLength length: UInt, withTimeout timeout: TimeInterval, tag: Int) {
        guard length <= UInt(Int.max) else { return }
        self.transport.read(self, length: Int(length), timeout: timeout, tag: tag)
    }

    public func disconnect() {
        self.transport.close(self)
    }

    public func resetDelegate() {
        self.delegate = nil
    }

    fileprivate func assign(streamId: UInt32) {
        self.streamId = streamId
    }

    fileprivate func transportDidOpen() {
        guard !self.closed else { return }
        let delegate = self.delegate
        self.delegateQueue.async { [weak delegate] in
            delegate?.connectionInterfaceDidConnect()
        }
    }

    fileprivate func enqueueIncoming(_ data: Data) -> Int {
        guard !self.closed else { return 0 }
        self.incoming.append(data)
        return self.drainReads()
    }

    fileprivate func enqueueRead(length: Int, tag: Int) -> Int {
        guard !self.closed, length > 0 else { return 0 }
        self.reads.append(ReadRequest(length: length, tag: tag))
        return self.drainReads()
    }

    fileprivate func hasPendingRead(tag: Int) -> Bool {
        return self.reads.contains(where: { $0.tag == tag })
    }

    private func drainReads() -> Int {
        var consumed = 0
        while let request = self.reads.first, self.incoming.count >= request.length {
            self.reads.removeFirst()
            let data = self.incoming.prefix(request.length)
            self.incoming.removeFirst(request.length)
            consumed += request.length
            let delegate = self.delegate
            self.delegateQueue.async { [weak delegate] in
                delegate?.connectionInterfaceDidReadPartialData(ofLength: UInt(request.length), tag: request.tag)
                delegate?.connectionInterfaceDidRead(Data(data), withTag: request.tag, networkType: 0)
            }
        }
        return consumed
    }

    fileprivate func transportDidClose(error: Error?) {
        guard !self.closed else { return }
        self.closed = true
        self.incoming.removeAll()
        self.reads.removeAll()
        let delegate = self.delegate
        self.delegateQueue.async { [weak delegate] in
            delegate?.connectionInterfaceDidDisconnectWithError(error)
        }
    }
}
