import Foundation
import WalletEngineFFI

enum SessionResponse {
    case signed(TonConnectSignedResult)
    case error(TonConnectRpcErrorCode, String)
    case disconnect
}

protocol ProtocolSession: Sendable {
    func phase() throws -> TonConnectSessionPhase
    func prompt() throws -> TonConnectConnectPrompt?
    func requests(now: UInt64) throws -> [TonConnectIncomingRequest]
    func ingest(_ chunk: Data, now: UInt64) throws -> [TonConnectIncomingRequest]
    func eventsURL() throws -> String
    func persisted() throws -> String
    func pendingPost() throws -> TonConnectPreparedPost?
    func completePost() throws
    func approve(account: TonConnectAccountInfo, proof: TonConnectProofReply?, device: TonConnectDevice) throws
    func reject() throws
    func respond(id: String, response: SessionResponse) throws
    func disconnect() throws
}

struct EngineSession: ProtocolSession {
    let value: TonConnectSession
    func phase() throws -> TonConnectSessionPhase { try self.value.phase() }
    func prompt() throws -> TonConnectConnectPrompt? { try self.value.connectPrompt() }
    func requests(now: UInt64) throws -> [TonConnectIncomingRequest] { try self.value.pendingRequests(now: now) }
    func ingest(_ chunk: Data, now: UInt64) throws -> [TonConnectIncomingRequest] { try self.value.ingestSseChunk(chunk: chunk, now: now) }
    func eventsURL() throws -> String { try self.value.beginEventsSubscription() }
    func persisted() throws -> String { try self.value.persisted() }
    func pendingPost() throws -> TonConnectPreparedPost? { try self.value.pendingPost() }
    func completePost() throws { try self.value.completePendingPost() }
    func approve(account: TonConnectAccountInfo, proof: TonConnectProofReply?, device: TonConnectDevice) throws {
        _ = try self.value.approveConnect(account: account, proof: proof, device: device)
    }
    func reject() throws { _ = try self.value.rejectConnect(message: "User declined the connection") }
    func disconnect() throws { _ = try self.value.disconnect() }
    func respond(id: String, response: SessionResponse) throws {
        switch response {
        case let .signed(.send(boc)): _ = try self.value.prepareSendSuccess(requestId: id, signedBoc: boc)
        case let .signed(.sign(boc)): _ = try self.value.prepareSignMessageSuccess(requestId: id, internalBoc: boc)
        case let .error(code, message): _ = try self.value.prepareError(requestId: id, code: code, message: message)
        case .disconnect: _ = try self.value.prepareDisconnectSuccess(requestId: id)
        }
    }
}
