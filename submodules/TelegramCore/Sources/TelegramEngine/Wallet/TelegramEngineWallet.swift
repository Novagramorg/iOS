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

        public func stateUpdates() -> Signal<WalletState, NoError> {
            return self.account.stateManager.walletStateUpdates()
            |> map { WalletState(apiState: $0) }
        }

        public func getUserAddresses(userIds: [EnginePeer.Id]) -> Signal<[WalletUserAddress], WalletGetUserAddressesError> {
            return _internal_getWalletUserAddresses(account: self.account, userIds: userIds)
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

        public func exportSecretPhrase(password: String? = nil) -> Signal<[String], WalletOperationError> {
            return _internal_exportWalletSecretPhrase(account: self.account, password: password)
        }

        public func enableBackup(words: [String], password: String? = nil) -> Signal<WalletState, WalletOperationError> {
            return _internal_enableWalletBackup(account: self.account, words: words, password: password)
        }

        public func disableBackup(password: String? = nil) -> Signal<WalletState, WalletOperationError> {
            return _internal_disableWalletBackup(account: self.account, password: password)
        }

        public func replaceWallet(replacement: WalletReplacement, password: String? = nil) -> Signal<WalletState, WalletOperationError> {
            return _internal_replaceWallet(account: self.account, replacement: replacement, password: password)
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
