import Foundation
import MtProtoKit
import Postbox
import SwiftSignalKit
import TelegramApi

public extension TelegramEngine {
    final class Wallet {
        let account: Account

        init(account: Account) {
            self.account = account
        }

        public func getState() -> Signal<WalletState, WalletGetStateError> {
            return _internal_getWalletState(account: self.account)
        }

        public func getExistingWaltBalance() -> Signal<WalletExistingBalance?, NoError> {
            return _internal_getExistingWaltBalance(account: self.account)
        }

        public func getGaslessInfo() -> Signal<WalletGaslessInfo, WalletGetGaslessInfoError> {
            return _internal_getWalletGaslessInfo(account: self.account)
        }

        public func sendTransfer(dataNormal: Data, dataGasless: Data? = nil, randomId: Int64, pendingMessage: WalletPendingTransferMessageReference? = nil) -> Signal<WalletSendTransferResult, WalletSendTransferError> {
            return _internal_sendWalletTransfer(account: self.account, dataNormal: dataNormal, dataGasless: dataGasless, randomId: randomId, pendingMessage: pendingMessage)
        }

        public func createPendingTransferMessage(peerId: EnginePeer.Id, operationId: String, randomId: Int64, amount: Int64, address: String, comment: String?, commentEncrypted: Bool, timestamp: Int32) -> Signal<WalletPendingTransferMessageReference?, NoError> {
            return _internal_createPendingWalletTransferMessage(account: self.account, peerId: peerId, operationId: operationId, randomId: randomId, amount: amount, address: address, comment: comment, commentEncrypted: commentEncrypted, timestamp: timestamp)
        }

        public func acceptPendingTransferMessage(_ reference: WalletPendingTransferMessageReference, transfer: WalletSentTransfer, receivedAt: Int32) -> Signal<Void, NoError> {
            return _internal_acceptPendingWalletTransferMessage(postbox: self.account.postbox, reference: reference, transfer: transfer, receivedAt: receivedAt)
        }

        public func removePendingTransferMessage(_ reference: WalletPendingTransferMessageReference) -> Signal<Void, NoError> {
            return _internal_removePendingWalletTransferMessage(postbox: self.account.postbox, reference: reference)
        }

        public func resolvePendingTransferMessage(_ reference: WalletPendingTransferMessageReference, chainTraceId: String) -> Signal<Void, NoError> {
            return _internal_resolvePendingWalletTransferMessage(postbox: self.account.postbox, reference: reference, chainTraceId: chainTraceId)
        }

        public func resolvePendingTransferMessage(_ reference: WalletPendingTransferMessageReference, transactionId: String, failed: Bool = false) -> Signal<Void, NoError> {
            return _internal_resolvePendingWalletTransferMessage(postbox: self.account.postbox, reference: reference, transactionId: transactionId, failed: failed)
        }

        public func hasUnresolvedPendingTransferMessage(_ reference: WalletPendingTransferMessageReference) -> Signal<Bool, NoError> {
            return _internal_hasUnresolvedPendingWalletTransferMessage(postbox: self.account.postbox, reference: reference)
        }

        public func getTransactionsByIDs(ids: [String]) -> Signal<WalletTransactions, WalletGetTransactionsError> {
            return _internal_getWalletTransactionsByIDs(account: self.account, ids: ids)
        }

        public func getTransactionsByMsgHash(msgHash: [String]) -> Signal<WalletTransactions, WalletGetTransactionsError> {
            return _internal_getWalletTransactionsByMsgHash(account: self.account, msgHash: msgHash)
        }

        public func transferUpdates() -> Signal<[WalletTransferUpdate], NoError> {
            return self.account.stateManager.walletTransferUpdates()
        }

        public func stateUpdates() -> Signal<WalletState, NoError> {
            return self.account.stateManager.walletStateUpdates()
            |> map { WalletState(apiState: $0) }
        }

        public func getUserAddresses(
            userIds: [EnginePeer.Id] = [],
            addresses: [String] = [],
            force: Bool = false
        ) -> Signal<[WalletUserAddress], WalletGetUserAddressesError> {
            return _internal_getWalletUserAddresses(
                account: self.account,
                userIds: userIds,
                addresses: addresses,
                force: force
            )
        }

        public func getTransactions(
            inbound: Bool,
            outbound: Bool,
            offset: String,
            limit: Int32
        ) -> Signal<WalletTransactions, WalletGetTransactionsError> {
            return _internal_getWalletTransactions(
                account: self.account,
                inbound: inbound,
                outbound: outbound,
                offset: offset,
                limit: limit
            )
        }

        public func getBackupHolders() -> Signal<[WalletBackupHolder], WalletOperationError> {
            return _internal_getWalletBackupHolders(account: self.account)
        }

        public func enableBackup(encryptedParts: [Data], password: String? = nil) -> Signal<WalletState, WalletOperationError> {
            return _internal_enableWalletBackup(account: self.account, encryptedParts: encryptedParts, password: password)
        }

        public func requestSecretPhraseExport(password: String? = nil) -> Signal<WalletSecretPhraseExport, WalletOperationError> {
            return _internal_requestWalletSecretPhraseExport(account: self.account, password: password)
        }

        public func fetchEncryptedSecretPhrasePart(
            datacenterId: Int32,
            token: String,
            publicKey: Data
        ) -> Signal<Data, WalletOperationError> {
            return _internal_fetchEncryptedWalletSecretPhrasePart(
                account: self.account,
                datacenterId: datacenterId,
                token: token,
                publicKey: publicKey
            )
        }

        public func disableBackup(password: String? = nil, newPublicKey: Data? = nil, proof: WalletOwnershipProof? = nil) -> Signal<WalletState, WalletOperationError> {
            return _internal_disableWalletBackup(account: self.account, password: password, newPublicKey: newPublicKey, proof: proof)
        }

        public func replaceWallet(replacement: WalletReplacement, password: String? = nil) -> Signal<WalletState, WalletOperationError> {
            return _internal_replaceWallet(account: self.account, replacement: replacement, password: password)
        }

        public func getProofChallenge() -> Signal<WalletProofChallenge, WalletOperationError> {
            return _internal_getWalletProofChallenge(account: self.account)
        }

        public func getStreamingUrl() -> Signal<WalletStreamingUrl, TonApiRequestError> {
            return _internal_getStreamingUrl(account: self.account)
        }

        public func performGetRequest(endpoint: String, query: String? = nil) -> Signal<String, TonApiRequestError> {
            var flags: Int32 = 0
            if query != nil {
                flags |= 1 << 1
            }

            return _internal_performTonApiRequest(
                account: self.account,
                flags: flags,
                endpoint: endpoint,
                query: query,
                payload: nil
            )
        }

        public func performPostRequest(endpoint: String, payload: String? = nil) -> Signal<String, TonApiRequestError> {
            var flags: Int32 = 1 << 0
            if payload != nil {
                flags |= 1 << 2
            }

            return _internal_performTonApiRequest(
                account: self.account,
                flags: flags,
                endpoint: endpoint,
                query: nil,
                payload: payload
            )
        }
    }
}
