import Foundation
import MtProtoKit
import Postbox
import SwiftSignalKit
import TelegramApi

public struct TonApiRequestError: Error, Equatable, Sendable {
    public let code: Int32
    public let description: String

    public init(code: Int32, description: String) {
        self.code = code
        self.description = description
    }
}

public struct WalletStreamingUrl: Equatable, Sendable {
    public let url: String
    public let expires: Int32

    public init(url: String, expires: Int32) {
        self.url = url
        self.expires = expires
    }
}

public struct WalletProofChallenge: Equatable, Sendable {
    public let payload: String
    public let expires: Int32
    public let domain: String
    public let timestamp: Int32

    public init(payload: String, expires: Int32, domain: String, timestamp: Int32) {
        self.payload = payload
        self.expires = expires
        self.domain = domain
        self.timestamp = timestamp
    }
}

public struct WalletOwnershipProof: Equatable, Sendable {
    public let timestamp: Int32
    public let signature: Data

    public init(timestamp: Int32, signature: Data) {
        self.timestamp = timestamp
        self.signature = signature
    }
}

public enum WalletState: Equatable, Sendable {
    case empty(creating: Bool)
    case ready(
        backupEnabled: Bool,
        canExportPhrase: Bool,
        canEnableBackup: Bool,
        address: String,
        publicKey: Data,
        balance: Int64
    )
}

public struct WalletUserAddress: Equatable {
    public let userId: EnginePeer.Id
    public let address: String

    public init(userId: EnginePeer.Id, address: String) {
        self.userId = userId
        self.address = address
    }
}

public enum WalletTransactionPeer: Equatable {
    case user(EnginePeer, address: String, domain: String?)
    case address(String, domain: String?)
    case unsupported
}

public struct WalletTransaction: Equatable {
    public let incoming: Bool
    public let failed: Bool
    public let id: String
    public let amount: Int64
    public let fee: Int64
    public let date: Int32
    public let peer: WalletTransactionPeer
    public let comment: String?
    public let commentEncrypted: Bool
    public let txHash: String?

    public init(
        incoming: Bool,
        failed: Bool,
        id: String,
        amount: Int64,
        fee: Int64,
        date: Int32,
        peer: WalletTransactionPeer,
        comment: String?,
        commentEncrypted: Bool = false,
        txHash: String?
    ) {
        self.incoming = incoming
        self.failed = failed
        self.id = id
        self.amount = amount
        self.fee = fee
        self.date = date
        self.peer = peer
        self.comment = comment
        self.commentEncrypted = commentEncrypted
        self.txHash = txHash
    }
}

public struct WalletTransactions: Equatable {
    public let balance: Int64
    public let items: [WalletTransaction]
    public let nextOffset: String?

    public init(balance: Int64, items: [WalletTransaction], nextOffset: String?) {
        self.balance = balance
        self.items = items
        self.nextOffset = nextOffset
    }
}

public struct WalletGaslessInfo: Codable, Equatable, Sendable {
    public let available: Bool
    public let left: Int32
    public let resetAt: Int32
    public let minAmount: Int64
    public let relayerAddress: String

    public init(available: Bool, left: Int32, resetAt: Int32, minAmount: Int64, relayerAddress: String) {
        self.available = available
        self.left = left
        self.resetAt = resetAt
        self.minAmount = minAmount
        self.relayerAddress = relayerAddress
    }
}

public struct WalletSentTransfer: Codable, Equatable, Sendable {
    public let gasless: Bool
    public let msgHash: String
    public let gaslessLeft: Int32
    public let gaslessResetAt: Int32

    public init(gasless: Bool, msgHash: String, gaslessLeft: Int32, gaslessResetAt: Int32) {
        self.gasless = gasless
        self.msgHash = msgHash
        self.gaslessLeft = gaslessLeft
        self.gaslessResetAt = gaslessResetAt
    }
}

public enum WalletGetGaslessInfoError: Error {
    case generic
}

public enum WalletSendTransferError: Error, Equatable, Sendable {
    case invalidData
    case sendFailed
    case network
    case generic
}

public enum WalletGetStateError: Error {
    case generic
}

public enum WalletGetUserAddressesError: Error {
    case generic
}

public enum WalletGetTransactionsError: Error {
    case generic
}

public enum WalletReplacement: Equatable, Sendable {
    case new
    case imported(publicKey: Data, proof: WalletOwnershipProof)
}

public enum WalletOperationError: Error, Equatable {
    case generic
    case network
    case preflightNetwork
    case requestPassword
    case invalidPassword
    case twoStepAuthMissing
    case passwordTooFresh(Int32)
    case sessionTooFresh(Int32)
    case backupDisabled
    case backupNotAvailable
    case replacementInvalid
    case publicKeyInvalid
    case proofInvalid
    case proofExpired
    case tokenInvalid
    case tokenExpired
    case clientKeyInvalid
    case partUnavailable
    case invalidBackupData
}

extension WalletState {
    public init(apiState: Api.WalletState) {
        switch apiState {
        case let .walletState(state):
            self = .ready(
                backupEnabled: (state.flags & (1 << 0)) != 0,
                canExportPhrase: (state.flags & (1 << 1)) != 0,
                canEnableBackup: (state.flags & (1 << 2)) != 0,
                address: state.address,
                publicKey: state.publicKey.makeData(),
                balance: state.balance
            )
        case let .walletStateEmpty(state):
            self = .empty(creating: (state.flags & (1 << 0)) != 0)
        }
    }
}

private extension WalletUserAddress {
    init(apiAddress: Api.WalletUserAddress) {
        switch apiAddress {
        case let .walletUserAddress(address):
            self.init(
                userId: EnginePeer.Id(
                    namespace: Namespaces.Peer.CloudUser,
                    id: PeerId.Id._internalFromInt64Value(address.userId)
                ),
                address: address.address
            )
        }
    }
}

private extension WalletTransactionPeer {
    init(apiPeer: Api.WalletTransactionPeer, transaction: Transaction) {
        switch apiPeer {
        case let .walletTransactionPeerAddress(peer):
            self = .address(peer.address, domain: peer.domain)
        case .walletTransactionPeerUnsupported:
            self = .unsupported
        case let .walletTransactionPeerUser(apiPeer):
            let peerId = EnginePeer.Id(
                namespace: Namespaces.Peer.CloudUser,
                id: PeerId.Id._internalFromInt64Value(apiPeer.userId)
            )
            if let peer = transaction.getPeer(peerId) {
                self = .user(EnginePeer(peer), address: apiPeer.address, domain: apiPeer.domain)
            } else {
                self = .address(apiPeer.address, domain: apiPeer.domain)
            }
        }
    }
}

private extension WalletTransaction {
    init(apiTransaction: Api.WalletTransaction, transaction: Transaction) {
        switch apiTransaction {
        case let .walletTransaction(walletTransaction):
            self.init(
                incoming: (walletTransaction.flags & (1 << 0)) != 0,
                failed: (walletTransaction.flags & (1 << 2)) != 0,
                id: walletTransaction.id,
                amount: walletTransaction.amount,
                fee: walletTransaction.fee,
                date: walletTransaction.date,
                peer: WalletTransactionPeer(apiPeer: walletTransaction.peer, transaction: transaction),
                comment: walletTransaction.comment,
                commentEncrypted: (walletTransaction.flags & (1 << 6)) != 0,
                txHash: walletTransaction.txHash
            )
        }
    }
}

private func tonApiRequestError(_ error: MTRpcError) -> TonApiRequestError {
    return TonApiRequestError(code: error.errorCode, description: error.errorDescription)
}

func _internal_getWalletState(account: Account) -> Signal<WalletState, WalletGetStateError> {
    return account.network.request(Api.functions.wallet.getState())
    |> mapError { _ -> WalletGetStateError in
        return .generic
    }
    |> map { result in
        return WalletState(apiState: result)
    }
}

func _internal_getWalletUserAddresses(
    account: Account,
    userIds: [EnginePeer.Id],
    force: Bool
) -> Signal<[WalletUserAddress], WalletGetUserAddressesError> {
    guard !userIds.isEmpty else {
        return .single([])
    }

    return account.postbox.transaction { transaction -> [Api.InputUser]? in
        var inputUsers: [Api.InputUser] = []
        inputUsers.reserveCapacity(userIds.count)
        for userId in userIds {
            if userId == account.peerId {
                inputUsers.append(.inputUserSelf)
            } else if userId.namespace == Namespaces.Peer.CloudUser,
                      let peer = transaction.getPeer(userId),
                      let inputUser = apiInputUser(peer) {
                inputUsers.append(inputUser)
            } else {
                return nil
            }
        }
        return inputUsers
    }
    |> castError(WalletGetUserAddressesError.self)
    |> mapToSignal { inputUsers -> Signal<[WalletUserAddress], WalletGetUserAddressesError> in
        guard let inputUsers else {
            return .fail(.generic)
        }
        var flags: Int32 = 0
        if force {
            flags |= 1 << 0
        }
        return account.network.request(Api.functions.wallet.getUserAddresses(flags: flags, id: inputUsers))
        |> mapError { _ -> WalletGetUserAddressesError in
            return .generic
        }
        |> map { result in
            return result.map { WalletUserAddress(apiAddress: $0) }
        }
    }
}

func _internal_getWalletTransactions(
    account: Account,
    inbound: Bool,
    outbound: Bool,
    offset: String,
    limit: Int32
) -> Signal<WalletTransactions, WalletGetTransactionsError> {
    var flags: Int32 = 0
    if inbound {
        flags |= 1 << 0
    }
    if outbound {
        flags |= 1 << 1
    }

    return account.network.request(Api.functions.wallet.getTransactions(
        flags: flags,
        offset: offset,
        limit: limit
    ))
    |> mapError { _ -> WalletGetTransactionsError in
        return .generic
    }
    |> mapToSignal { result -> Signal<WalletTransactions, WalletGetTransactionsError> in
        return _internal_walletTransactionsResult(account: account, result: result)
    }
}

func _internal_getWalletGaslessInfo(account: Account) -> Signal<WalletGaslessInfo, WalletGetGaslessInfoError> {
    return account.network.request(Api.functions.wallet.getGaslessInfo(), automaticFloodWait: false)
    |> mapError { _ -> WalletGetGaslessInfoError in .generic }
    |> map { result in
        switch result {
        case let .gaslessInfo(info):
            return WalletGaslessInfo(
                available: (info.flags & (1 << 0)) != 0,
                left: info.left,
                resetAt: info.resetAt,
                minAmount: info.minAmount,
                relayerAddress: info.relayerAddress
            )
        }
    }
}

func _internal_sendWalletTransfer(account: Account, dataNormal: Data, dataGasless: Data?, pendingMessage: WalletPendingTransferMessageReference? = nil) -> Signal<WalletSentTransfer, WalletSendTransferError> {
    guard !dataNormal.isEmpty, dataNormal.count <= 16 * 1024,
          (dataGasless?.count ?? 0) <= 16 * 1024 else {
        if let pendingMessage {
            return _internal_removePendingWalletTransferMessage(postbox: account.postbox, reference: pendingMessage)
            |> castError(WalletSendTransferError.self)
            |> mapToSignal { _ in .fail(.invalidData) }
        }
        return .fail(.invalidData)
    }
    return account.network.request(Api.functions.wallet.sendTransfer(
        flags: dataGasless == nil ? 0 : (1 << 0),
        dataNormal: Buffer(data: dataNormal),
        dataGasless: dataGasless.map { Buffer(data: $0) }
    ), automaticFloodWait: false)
    |> mapError { error -> WalletSendTransferError in
        switch error.errorDescription {
        case "WALLET_TRANSFER_DATA_INVALID":
            return .invalidData
        case "WALLET_TRANSFER_SEND_FAILED":
            return .sendFailed
        default:
            return error.errorCode < 0 ? .network : .generic
        }
    }
    |> mapToSignal { result -> Signal<WalletSentTransfer, WalletSendTransferError> in
        switch result {
        case let .sentTransfer(transfer):
            let result = WalletSentTransfer(
                gasless: (transfer.flags & (1 << 0)) != 0,
                msgHash: transfer.msgHash,
                gaslessLeft: transfer.gaslessLeft,
                gaslessResetAt: transfer.gaslessResetAt
            )
            if let pendingMessage {
                return _internal_acceptPendingWalletTransferMessage(postbox: account.postbox, reference: pendingMessage, transfer: result, receivedAt: pendingWalletTransferTimestamp())
                |> castError(WalletSendTransferError.self)
                |> map { _ in result }
            }
            return .single(result)
        }
    }
    |> `catch` { error -> Signal<WalletSentTransfer, WalletSendTransferError> in
        if let pendingMessage, error == .invalidData || error == .sendFailed {
            return _internal_removePendingWalletTransferMessage(postbox: account.postbox, reference: pendingMessage)
            |> castError(WalletSendTransferError.self)
            |> mapToSignal { _ in .fail(error) }
        }
        return .fail(error)
    }
}

func _internal_getWalletTransactionsByIDs(account: Account, ids: [String]) -> Signal<WalletTransactions, WalletGetTransactionsError> {
    return account.network.request(Api.functions.wallet.getTransactionsByIDs(id: ids), automaticFloodWait: false)
    |> mapError { _ -> WalletGetTransactionsError in .generic }
    |> mapToSignal { result in
        return _internal_walletTransactionsResult(account: account, result: result)
    }
}

func _internal_getWalletTransactionsByMsgHash(account: Account, msgHash: [String]) -> Signal<WalletTransactions, WalletGetTransactionsError> {
    return account.network.request(Api.functions.wallet.getTransactionsByMsgHash(msgHash: msgHash), automaticFloodWait: false)
    |> mapError { _ -> WalletGetTransactionsError in .generic }
    |> mapToSignal { result in
        return _internal_walletTransactionsResult(account: account, result: result)
    }
}

func _internal_walletTransactionsResult(account: Account, result: Api.wallet.Transactions) -> Signal<WalletTransactions, WalletGetTransactionsError> {
    return account.postbox.transaction { transaction -> WalletTransactions in
        switch result {
        case let .transactions(transactions):
            let parsedPeers = AccumulatedPeers(
                transaction: transaction,
                chats: transactions.chats,
                users: transactions.users
            )
            updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)
            return WalletTransactions(
                balance: transactions.balance,
                items: transactions.transactions.map {
                    return WalletTransaction(apiTransaction: $0, transaction: transaction)
                },
                nextOffset: transactions.nextOffset
            )
        }
    }
    |> castError(WalletGetTransactionsError.self)
}

func _internal_getStreamingUrl(account: Account) -> Signal<WalletStreamingUrl, TonApiRequestError> {
    let request = Api.functions.toncenter.getStreamingUrl()

    return currentWebDocumentsHostDatacenterId(
        postbox: account.postbox,
        isTestingEnvironment: account.testingEnvironment
    )
    |> castError(TonApiRequestError.self)
    |> mapToSignal { datacenterId -> Signal<Api.toncenter.StreamingUrl, TonApiRequestError> in
        let targetDatacenterId = Int(datacenterId)
        let signal: Signal<Api.toncenter.StreamingUrl, MTRpcError>
        if account.network.datacenterId == targetDatacenterId {
            signal = account.network.request(request)
        } else {
            signal = account.network.download(datacenterId: targetDatacenterId, isMedia: false, tag: nil)
            |> castError(MTRpcError.self)
            |> mapToSignal { worker in
                return worker.request(request)
            }
        }

        return signal
        |> mapError { error in
            return tonApiRequestError(error)
        }
    }
    |> map { result -> WalletStreamingUrl in
        switch result {
        case let .streamingUrl(streamingUrl):
            return WalletStreamingUrl(url: streamingUrl.url, expires: streamingUrl.expires)
        }
    }
}

func _internal_performTonApiRequest(
    account: Account,
    flags: Int32,
    endpoint: String,
    query: String?,
    payload: String?
) -> Signal<String, TonApiRequestError> {
    let request = Api.functions.toncenter.performApiRequest(
        flags: flags,
        endpoint: endpoint,
        query: query,
        payload: payload
    )

    return currentWebDocumentsHostDatacenterId(
        postbox: account.postbox,
        isTestingEnvironment: account.testingEnvironment
    )
    |> castError(TonApiRequestError.self)
    |> mapToSignal { datacenterId -> Signal<Api.toncenter.ApiResponse, TonApiRequestError> in
        let targetDatacenterId = Int(datacenterId)
        let signal: Signal<Api.toncenter.ApiResponse, MTRpcError>
        if account.network.datacenterId == targetDatacenterId {
            signal = account.network.request(request)
        } else {
            signal = account.network.download(datacenterId: targetDatacenterId, isMedia: false, tag: nil)
            |> castError(MTRpcError.self)
            |> mapToSignal { worker in
                return worker.request(request)
            }
        }

        return signal
        |> mapError { error in
            return tonApiRequestError(error)
        }
    }
    |> map { result -> String in
        switch result {
        case let .apiResponse(apiResponse):
            switch apiResponse.response {
            case let .dataJSON(dataJSON):
                return dataJSON.data
            }
        }
    }
}
