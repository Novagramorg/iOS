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

public enum WalletState: Equatable {
    case empty(provisioning: Bool)
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
    case user(EnginePeer)
    case address(String)
    case unsupported
}

public struct WalletTransaction: Equatable {
    public let incoming: Bool
    public let pending: Bool
    public let failed: Bool
    public let id: String
    public let amount: Int64
    public let fee: Int64
    public let date: Int32
    public let peer: WalletTransactionPeer
    public let comment: String?
    public let txHash: String?

    public init(
        incoming: Bool,
        pending: Bool,
        failed: Bool,
        id: String,
        amount: Int64,
        fee: Int64,
        date: Int32,
        peer: WalletTransactionPeer,
        comment: String?,
        txHash: String?
    ) {
        self.incoming = incoming
        self.pending = pending
        self.failed = failed
        self.id = id
        self.amount = amount
        self.fee = fee
        self.date = date
        self.peer = peer
        self.comment = comment
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

public enum WalletGetStateError: Error {
    case generic
}

public enum WalletGetUserAddressesError: Error {
    case generic
}

public enum WalletGetTransactionsError: Error {
    case generic
}

public enum WalletReplacement: Equatable {
    case new
    case imported(publicKey: Data)
}

public enum WalletOperationError: Error, Equatable {
    case generic
    case network
    case requestPassword
    case invalidPassword
    case twoStepAuthMissing
    case passwordTooFresh(Int32)
    case sessionTooFresh(Int32)
    case backupDisabled
    case backupNotAvailable
    case replacementInvalid
    case publicKeyInvalid
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
            self = .empty(provisioning: (state.flags & (1 << 0)) != 0)
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
            self = .address(peer.address)
        case .walletTransactionPeerUnsupported:
            self = .unsupported
        case let .walletTransactionPeerUser(peer):
            let peerId = EnginePeer.Id(
                namespace: Namespaces.Peer.CloudUser,
                id: PeerId.Id._internalFromInt64Value(peer.userId)
            )
            if let peer = transaction.getPeer(peerId) {
                self = .user(EnginePeer(peer))
            } else {
                self = .unsupported
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
                pending: (walletTransaction.flags & (1 << 1)) != 0,
                failed: (walletTransaction.flags & (1 << 2)) != 0,
                id: walletTransaction.id,
                amount: walletTransaction.amount,
                fee: walletTransaction.fee,
                date: walletTransaction.date,
                peer: WalletTransactionPeer(apiPeer: walletTransaction.peer, transaction: transaction),
                comment: walletTransaction.comment,
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
    userIds: [EnginePeer.Id]
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
        return account.network.request(Api.functions.wallet.getUserAddresses(id: inputUsers))
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
