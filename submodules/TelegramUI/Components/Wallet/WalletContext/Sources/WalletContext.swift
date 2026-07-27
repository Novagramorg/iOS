import Foundation
import Combine
import SwiftSignalKit
import TelegramCore
import TONWalletKit

private let walletApiKey = "84f56a3a13a49c973bba18b3b69e5589c0a87c5227631629941155ef6ab0b555"
private let walletFiatRatesUrl = "https://api.mywallet.io/currency-rates"
private let walletFiatRatesRefreshInterval: TimeInterval = 15.0 * 60.0

public final class WalletContext {
    public enum FiatCurrency: String, CaseIterable, Hashable {
        case usd = "USD"
        case eur = "EUR"
        case rub = "RUB"
        case cny = "CNY"

        public var symbol: String {
            switch self {
            case .usd:
                return "$"
            case .eur:
                return "€"
            case .rub:
                return "₽"
            case .cny:
                return "¥"
            }
        }
    }

    public struct FiatRate: Equatable {
        public let unitsPerUsd: Double
        public let unitsPerGram: Double

        public init(unitsPerUsd: Double, unitsPerGram: Double) {
            self.unitsPerUsd = unitsPerUsd
            self.unitsPerGram = unitsPerGram
        }
    }

    public struct FiatState: Equatable {
        public let selectedCurrency: FiatCurrency
        public let rates: Resource<[FiatCurrency: FiatRate]>

        public init(
            selectedCurrency: FiatCurrency,
            rates: Resource<[FiatCurrency: FiatRate]>
        ) {
            self.selectedCurrency = selectedCurrency
            self.rates = rates
        }

        public var selectedRate: FiatRate? {
            return self.rates.currentValue?[self.selectedCurrency]
        }
    }

    public enum WalletVersion: String, Codable, Equatable {
        case v4R2
        case v5R1
    }

    public struct WalletInfo: Equatable {
        public let address: String
        public let publicKey: String
        public let version: WalletVersion

        public init(address: String, publicKey: String, version: WalletVersion) {
            self.address = address
            self.publicKey = publicKey
            self.version = version
        }
    }

    public enum FatalStorageError: Error, Equatable {
        case keychainStatus(Int32)
        case corrupted
        case unsupportedVersion
        case identityMismatch
    }

    public enum SynchronizationError: Error, Equatable {
        case unavailable
        case network
        case timeout
        case http(statusCode: Int)
        case invalidData
        case sdk

        public var isRetryable: Bool {
            switch self {
            case .unavailable, .network, .timeout, .sdk:
                return true
            case let .http(statusCode):
                return statusCode == 408 || statusCode == 429 || statusCode >= 500
            case .invalidData:
                return false
            }
        }
    }

    public enum Resource<Value: Equatable>: Equatable {
        case idle
        case loading(previous: Value?)
        case value(Value, updatedAt: Int32)
        case stale(previous: Value?, error: SynchronizationError, lastSuccessfulAt: Int32?)

        public var currentValue: Value? {
            switch self {
            case .idle:
                return nil
            case let .loading(previous):
                return previous
            case let .value(value, _):
                return value
            case let .stale(previous, _, _):
                return previous
            }
        }

        public var lastSuccessfulAt: Int32? {
            switch self {
            case .idle, .loading:
                return nil
            case let .value(_, updatedAt):
                return updatedAt
            case let .stale(_, _, lastSuccessfulAt):
                return lastSuccessfulAt
            }
        }
    }

    public struct Transaction: Equatable {
        public enum Direction: Equatable {
            case incoming
            case outgoing
            case unknown
        }

        public enum Currency: Equatable {
            case ton
            case usdt
        }

        public let id: String
        public let logicalTime: String
        public let timestamp: Int32
        public let direction: Direction
        public let amount: Int64
        public let fee: Int64
        public let counterparty: String?
        public let comment: String?
        public let currency: Currency

        public init(
            id: String,
            logicalTime: String,
            timestamp: Int32,
            direction: Direction,
            amount: Int64,
            fee: Int64,
            counterparty: String?,
            comment: String?,
            currency: Currency = .ton
        ) {
            self.id = id
            self.logicalTime = logicalTime
            self.timestamp = timestamp
            self.direction = direction
            self.amount = amount
            self.fee = fee
            self.counterparty = counterparty
            self.comment = comment
            self.currency = currency
        }
    }

    public struct TransactionsState: Equatable {
        public let items: [Transaction]
        public let offset: Int
        public let canLoadMore: Bool
        public let isLoadingMore: Bool
        public let error: SynchronizationError?

        public init(
            items: [Transaction],
            offset: Int,
            canLoadMore: Bool,
            isLoadingMore: Bool,
            error: SynchronizationError?
        ) {
            self.items = items
            self.offset = offset
            self.canLoadMore = canLoadMore
            self.isLoadingMore = isLoadingMore
            self.error = error
        }
    }

    public struct Collectible: Equatable {
        public let address: String
        public let name: String
        public let imageUrl: String?
        public let receivedAt: Int32?

        public init(address: String, name: String, imageUrl: String?, receivedAt: Int32? = nil) {
            self.address = address
            self.name = name
            self.imageUrl = imageUrl
            self.receivedAt = receivedAt
        }
    }

    public struct CollectiblesState: Equatable {
        public let items: [Collectible]
        public let offset: Int
        public let canLoadMore: Bool
        public let isLoadingMore: Bool
        public let error: SynchronizationError?

        public init(
            items: [Collectible],
            offset: Int,
            canLoadMore: Bool,
            isLoadingMore: Bool,
            error: SynchronizationError?
        ) {
            self.items = items
            self.offset = offset
            self.canLoadMore = canLoadMore
            self.isLoadingMore = isLoadingMore
            self.error = error
        }

        public static var empty: CollectiblesState {
            return CollectiblesState(items: [], offset: 0, canLoadMore: false, isLoadingMore: false, error: nil)
        }
    }

    public struct PendingTransfer: Codable, Equatable {
        public enum Status: String, Codable, Equatable {
            case broadcasting
            case pending
        }

        public let id: String
        public let recipient: String
        public let amount: Int64
        public let comment: String?
        public let createdAt: Int32
        public let status: Status

        public init(
            id: String,
            recipient: String,
            amount: Int64,
            comment: String?,
            createdAt: Int32,
            status: Status
        ) {
            self.id = id
            self.recipient = recipient
            self.amount = amount
            self.comment = comment
            self.createdAt = createdAt
            self.status = status
        }
    }

    public enum ActiveOperation: Equatable {
        case creating
        case inspectingImport
        case importing
        case preparingTransfer
        case submittingTransfer
        case loadingMoreTransactions
        case loadingMoreCollectibles
        case deleting
    }

    public enum Phase: Equatable {
        case restoring
        case empty
        case wallet(WalletInfo)
        case failed(FatalStorageError)
    }

    public struct State: Equatable {
        public let phase: Phase
        public let balance: Resource<Int64>
        public let transactions: TransactionsState
        public let collectibles: CollectiblesState
        public let pendingTransfers: [PendingTransfer]
        public let activeOperation: ActiveOperation?
        public let fiat: FiatState

        public init(
            phase: Phase,
            balance: Resource<Int64>,
            transactions: TransactionsState,
            collectibles: CollectiblesState = .empty,
            pendingTransfers: [PendingTransfer],
            activeOperation: ActiveOperation?,
            fiat: FiatState = FiatState(selectedCurrency: .usd, rates: .idle)
        ) {
            self.phase = phase
            self.balance = balance
            self.transactions = transactions
            self.collectibles = collectibles
            self.pendingTransfers = pendingTransfers
            self.activeOperation = activeOperation
            self.fiat = fiat
        }
    }

    public enum WalletError: Error, Equatable {
        case unavailable
        case noWallet
        case walletAlreadyExists
        case invalidMnemonic
        case unsupportedMnemonicLength
        case invalidAddress
        case invalidAmount
        case operationInProgress
        case previewFailed
        case previewIncomplete
        case preparedTransferExpired
        case preparedTransferNotFound
        case storage(FatalStorageError)
        case network
        case sdk(String)
    }

    public struct CreatedWallet: Equatable {
        public let info: WalletInfo
        public let words: [String]

        public init(info: WalletInfo, words: [String]) {
            self.info = info
            self.words = words
        }
    }

    public struct ImportCandidate: Equatable {
        public let version: WalletVersion
        public let address: String
        public let balance: Int64?
        public let isActive: Bool?

        public init(version: WalletVersion, address: String, balance: Int64?, isActive: Bool?) {
            self.version = version
            self.address = address
            self.balance = balance
            self.isActive = isActive
        }
    }

    public struct ImportInspection: Equatable {
        public let wordsCount: Int
        public let candidates: [ImportCandidate]
        public let suggestedVersion: WalletVersion?

        public init(wordsCount: Int, candidates: [ImportCandidate], suggestedVersion: WalletVersion?) {
            self.wordsCount = wordsCount
            self.candidates = candidates
            self.suggestedVersion = suggestedVersion
        }
    }

    public struct PreparedTransfer: Equatable {
        public let id: String
        public let recipient: String
        public let amount: Int64
        public let comment: String?
        public let fee: Int64
        public let expiresAt: Int32

        public init(id: String, recipient: String, amount: Int64, comment: String?, fee: Int64, expiresAt: Int32) {
            self.id = id
            self.recipient = recipient
            self.amount = amount
            self.comment = comment
            self.fee = fee
            self.expiresAt = expiresAt
        }
    }

    public struct SubmittedTransfer: Equatable {
        public let pendingTransfer: PendingTransfer

        public init(pendingTransfer: PendingTransfer) {
            self.pendingTransfer = pendingTransfer
        }
    }

    public var state: Signal<State, NoError> {
        return Signal { [weak self] subscriber in
            guard let self else {
                subscriber.putCompletion()
                return EmptyDisposable
            }

            self.withMainQueue {
                self.stateSubscriberCount += 1
                self.evaluateRuntimeDemand()
            }
            let disposable = self.statePromise.get().start(next: { value in
                subscriber.putNext(value)
            })
            return ActionDisposable { [weak self] in
                disposable.dispose()
                self?.withMainQueue {
                    guard let self else {
                        return
                    }
                    self.stateSubscriberCount = max(0, self.stateSubscriberCount - 1)
                    self.evaluateRuntimeDemand()
                }
            }
        }
    }

    public var stateValue: State {
        assert(Queue.mainQueue().isCurrent())
        return self.currentState
    }

    private struct PreparedTransferRecord {
        let walletAddress: String
        let transfer: PreparedTransfer
        let request: TONTransactionRequest
    }

    private struct StreamTransactionOverlay {
        var status: TONStreamingUpdateStatus
        var transactionKeys: Set<String>
    }

    private struct FiatRatesResponse: Decodable {
        let rates: [String: String]
    }

    private let log: (String) -> Void
    private let toncenterProxy: WalletToncenterProxy
    private let vault: WalletKeychainVault
    private let statePromise: ValuePromise<State>
    private var currentState: State
    private var secretRecord: SecretRecord?
    private var metadataRecord: MetadataRecord?

    private var kit: TONWalletKit?
    private var wallet: (any TONWalletProtocol)?
    private var walletInitializationTask: Task<any TONWalletProtocol, Error>?
    private var runtimeTask: Task<Void, Never>?
    private var synchronizationTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var streamRetryTask: Task<Void, Never>?
    private var pendingPollTask: Task<Void, Never>?
    private var streamSnapshotTask: Task<Void, Never>?
    private var streamingProvider: (any TONStreamingProviderProtocol)?
    private var streamingCancellables = Set<AnyCancellable>()
    private var isStreamingConnected = false
    private var isStartingStreaming = false

    private let environmentDisposable = MetaDisposable()
    private var isApplicationInForeground = false
    private var isAccountCurrent = false
    private var isNetworkAvailable = false
    private var stateSubscriberCount = 0
    private var activeOperationCancellation: WalletOperationCancellation?
    private var synchronizationRequested = false
    private var retryAttempt = 0
    private var streamRetryAttempt = 0
    private var balanceLastSuccessfulAt: Int32?
    private var preparedTransfers: [String: PreparedTransferRecord] = [:]
    private var streamTransactionOverlaysByTrace: [String: StreamTransactionOverlay] = [:]
    private var collectibleMetadataCache: [String: WalletCollectibleMetadata] = [:]
    private var usdtJettonWalletRawAddress: TONRawAddress?
    private var lifecycleGeneration = 0
    private var fiatRatesDataTask: URLSessionDataTask?
    private var fiatRatesRefreshTask: Task<Void, Never>?
    private var fiatRatesRequestGeneration = 0
    private var fiatRatesLastSuccessfulAt: Int32?

    public init(
        engine: TelegramEngine,
        storageNamespace: String,
        applicationInForeground: Signal<Bool, NoError>,
        accountIsCurrent: Signal<Bool, NoError>,
        networkAvailable: Signal<Bool, NoError>,
        log: @escaping (String) -> Void = { _ in }
    ) {
        self.log = log
        self.toncenterProxy = WalletToncenterProxy(engine: engine)
        self.vault = WalletKeychainVault(namespace: storageNamespace)
        let initialState = State(
            phase: .restoring,
            balance: .idle,
            transactions: TransactionsState(items: [], offset: 0, canLoadMore: false, isLoadingMore: false, error: nil),
            pendingTransfers: [],
            activeOperation: nil
        )
        self.currentState = initialState
        self.statePromise = ValuePromise(initialState, ignoreRepeated: true)

        do {
            self.secretRecord = try self.vault.readSecret(SecretRecord.self)
            if self.secretRecord == nil {
                self.metadataRecord = nil
                self.currentState = State(
                    phase: .empty,
                    balance: .idle,
                    transactions: initialState.transactions,
                    pendingTransfers: [],
                    activeOperation: nil
                )
                self.statePromise.set(self.currentState)
            } else {
                self.metadataRecord = try self.vault.readMetadata(MetadataRecord.self) ?? MetadataRecord(
                    schemaVersion: 1,
                    pendingTransfers: []
                )
                self.currentState = State(
                    phase: .restoring,
                    balance: .idle,
                    transactions: initialState.transactions,
                    pendingTransfers: self.metadataRecord?.pendingTransfers ?? [],
                    activeOperation: nil
                )
                self.statePromise.set(self.currentState)
            }
        } catch let error as WalletKeychainVault.Error {
            let storageError = fatalStorageError(error)
            self.currentState = State(
                phase: .failed(storageError),
                balance: .idle,
                transactions: initialState.transactions,
                pendingTransfers: [],
                activeOperation: nil
            )
            self.statePromise.set(self.currentState)
        } catch {
            self.currentState = State(
                phase: .failed(.corrupted),
                balance: .idle,
                transactions: initialState.transactions,
                pendingTransfers: [],
                activeOperation: nil
            )
            self.statePromise.set(self.currentState)
        }

        self.environmentDisposable.set(combineLatest(queue: Queue.mainQueue(),
            applicationInForeground |> distinctUntilChanged,
            accountIsCurrent |> distinctUntilChanged,
            networkAvailable |> distinctUntilChanged
        ).start(next: { [weak self] applicationInForeground, accountIsCurrent, networkAvailable in
            guard let self else {
                return
            }
            self.isApplicationInForeground = applicationInForeground
            self.isAccountCurrent = accountIsCurrent
            self.isNetworkAvailable = networkAvailable
            self.environmentDidChange()
        }))
    }

    deinit {
        self.environmentDisposable.dispose()
        self.toncenterProxy.cancelAll()
        self.walletInitializationTask?.cancel()
        self.runtimeTask?.cancel()
        self.synchronizationTask?.cancel()
        self.retryTask?.cancel()
        self.streamRetryTask?.cancel()
        self.pendingPollTask?.cancel()
        self.streamSnapshotTask?.cancel()
        self.fiatRatesDataTask?.cancel()
        self.fiatRatesRefreshTask?.cancel()
        self.streamingCancellables.removeAll()
        try? self.streamingProvider?.disconnect()
    }

    public func setFiatCurrency(_ currency: FiatCurrency) {
        assert(Queue.mainQueue().isCurrent())
        guard self.currentState.fiat.selectedCurrency != currency else {
            return
        }
        self.replaceState(
            phase: self.currentState.phase,
            balance: self.currentState.balance,
            transactions: self.currentState.transactions,
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: self.currentState.activeOperation,
            fiat: FiatState(selectedCurrency: currency, rates: self.currentState.fiat.rates)
        )
    }

    public func containsMnemonicWord(_ word: String) -> Signal<Bool, WalletError> {
        return self.performUtility { context in
            let kit = try await context.initializedKit()
            return try await kit.containsMnemonicWord(word)
        }
    }

    public func validateMnemonic(words: [String]) -> Signal<Bool, WalletError> {
        return self.performUtility { context in
            let words = try validatedMnemonicWords(words)
            let kit = try await context.initializedKit()
            return try await kit.validateMnemonic(TONMnemonic(value: words))
        }
    }

    public func generateMnemonic() -> Signal<[String], WalletError> {
        return self.performUtility { context in
            let kit = try await context.initializedKit()
            return try await kit.generateMnemonic().value
        }
    }

    public func createWallet() -> Signal<CreatedWallet, WalletError> {
        return self.performOperation(.creating, cancelOnDispose: false) { context in
            guard case .empty = context.currentState.phase, context.secretRecord == nil else {
                throw WalletError.walletAlreadyExists
            }
            context.lifecycleGeneration &+= 1
            let generation = context.lifecycleGeneration
            context.isStartingStreaming = false
            context.balanceLastSuccessfulAt = nil
            context.walletInitializationTask?.cancel()
            context.walletInitializationTask = nil
            context.runtimeTask?.cancel()
            context.runtimeTask = nil

            let kit = try await context.initializedKit()
            try Task.checkCancellation()
            let result = try await kit.createWallet(
                parameters: TONV5R1WalletParameters(network: .mainnet, domain: nil),
                mnemonicLength: .bits128
            )
            let words = normalizedMnemonicWords(result.mnemonic.value)
            guard words.count == TONMnemonicLength.bits128.rawValue else {
                throw WalletError.invalidMnemonic
            }

            let address = try result.walletAdapter.address(testnet: false).value
            let publicKey = try result.walletAdapter.publicKey().value
            let secret = SecretRecord(
                schemaVersion: 1,
                words: words,
                walletVersion: .v5R1,
                network: TONNetwork.mainnet.chainId,
                walletId: nil,
                workchain: nil,
                address: address,
                publicKey: publicKey
            )
            let metadata = MetadataRecord(schemaVersion: 1, pendingTransfers: [])

            try Task.checkCancellation()
            do {
                try context.vault.writeSecret(secret)
            } catch let error as WalletKeychainVault.Error {
                throw WalletError.storage(fatalStorageError(error))
            }
            do {
                try context.vault.writeMetadata(metadata)
            } catch let error as WalletKeychainVault.Error {
                context.secretRecord = secret
                context.metadataRecord = metadata
                context.replaceState(
                    phase: .restoring,
                    balance: .idle,
                    transactions: context.currentState.transactions,
                    collectibles: .empty,
                    pendingTransfers: [],
                    activeOperation: context.currentState.activeOperation
                )
                throw WalletError.storage(fatalStorageError(error))
            }

            do {
                guard context.canUseNetworkRuntime, context.lifecycleGeneration == generation else {
                    throw WalletError.unavailable
                }
                let wallet = try await kit.add(walletAdapter: result.walletAdapter)
                try Task.checkCancellation()
                guard context.canUseNetworkRuntime, context.lifecycleGeneration == generation else {
                    try? await kit.remove(walletId: wallet.id)
                    throw WalletError.unavailable
                }
                context.secretRecord = secret
                context.metadataRecord = metadata
                context.wallet = wallet
                let info = walletInfo(secret: secret)
                context.replaceState(
                    phase: .wallet(info),
                    balance: .loading(previous: nil),
                    transactions: TransactionsState(items: [], offset: 0, canLoadMore: false, isLoadingMore: false, error: nil),
                    collectibles: .empty,
                    pendingTransfers: [],
                    activeOperation: context.currentState.activeOperation
                )
                context.synchronizationRequested = true
                return CreatedWallet(info: info, words: words)
            } catch {
                context.secretRecord = secret
                context.metadataRecord = metadata
                context.replaceState(
                    phase: .restoring,
                    balance: .idle,
                    transactions: context.currentState.transactions,
                    collectibles: .empty,
                    pendingTransfers: [],
                    activeOperation: context.currentState.activeOperation
                )
                throw walletError(error)
            }
        }
    }

    public func inspectImport(words: [String]) -> Signal<ImportInspection, WalletError> {
        return self.performOperation(.inspectingImport) { context in
            guard case .empty = context.currentState.phase, context.secretRecord == nil else {
                throw WalletError.walletAlreadyExists
            }
            let words = try validatedMnemonicWords(words)
            let kit = try await context.initializedKit()
            let mnemonic = TONMnemonic(value: words)
            guard try await kit.validateMnemonic(mnemonic) else {
                throw WalletError.invalidMnemonic
            }

            let signer = try await kit.signer(mnemonic: mnemonic)
            let v4Adapter = try await kit.walletV4R2Adapter(
                signer: signer,
                parameters: TONV4R2WalletParameters(network: .mainnet, domain: nil)
            )
            let v5Adapter = try await kit.walletV5R1Adapter(
                signer: signer,
                parameters: TONV5R1WalletParameters(network: .mainnet, domain: nil)
            )
            let candidates = [
                try await context.inspectCandidate(version: .v4R2, adapter: v4Adapter, kit: kit),
                try await context.inspectCandidate(version: .v5R1, adapter: v5Adapter, kit: kit)
            ]

            let activeCandidates = candidates.filter { $0.isActive == true }
            let suggestedVersion: WalletVersion?
            if candidates.allSatisfy({ $0.isActive != nil }) {
                if activeCandidates.count == 1 {
                    suggestedVersion = activeCandidates[0].version
                } else if activeCandidates.isEmpty {
                    suggestedVersion = .v5R1
                } else {
                    suggestedVersion = nil
                }
            } else {
                suggestedVersion = nil
            }
            return ImportInspection(wordsCount: words.count, candidates: candidates, suggestedVersion: suggestedVersion)
        }
    }

    public func importWallet(words: [String], version: WalletVersion) -> Signal<WalletInfo, WalletError> {
        return self.performOperation(.importing, cancelOnDispose: false) { context in
            guard case .empty = context.currentState.phase, context.secretRecord == nil else {
                throw WalletError.walletAlreadyExists
            }
            context.lifecycleGeneration &+= 1
            let generation = context.lifecycleGeneration
            context.isStartingStreaming = false
            context.balanceLastSuccessfulAt = nil
            context.walletInitializationTask?.cancel()
            context.walletInitializationTask = nil
            context.runtimeTask?.cancel()
            context.runtimeTask = nil
            let words = try validatedMnemonicWords(words)
            let kit = try await context.initializedKit()
            let mnemonic = TONMnemonic(value: words)
            guard try await kit.validateMnemonic(mnemonic) else {
                throw WalletError.invalidMnemonic
            }
            let signer = try await kit.signer(mnemonic: mnemonic)
            let adapter: any TONWalletAdapterProtocol
            switch version {
            case .v4R2:
                adapter = try await kit.walletV4R2Adapter(
                    signer: signer,
                    parameters: TONV4R2WalletParameters(network: .mainnet, domain: nil)
                )
            case .v5R1:
                adapter = try await kit.walletV5R1Adapter(
                    signer: signer,
                    parameters: TONV5R1WalletParameters(network: .mainnet, domain: nil)
                )
            }

            let address = try adapter.address(testnet: false).value
            let publicKey = try adapter.publicKey().value
            let secret = SecretRecord(
                schemaVersion: 1,
                words: words,
                walletVersion: version,
                network: TONNetwork.mainnet.chainId,
                walletId: nil,
                workchain: nil,
                address: address,
                publicKey: publicKey
            )
            let metadata = MetadataRecord(schemaVersion: 1, pendingTransfers: [])

            try Task.checkCancellation()
            do {
                try context.vault.writeSecret(secret)
            } catch let error as WalletKeychainVault.Error {
                throw WalletError.storage(fatalStorageError(error))
            }
            do {
                try context.vault.writeMetadata(metadata)
            } catch let error as WalletKeychainVault.Error {
                context.secretRecord = secret
                context.metadataRecord = metadata
                context.replaceState(
                    phase: .restoring,
                    balance: .idle,
                    transactions: context.currentState.transactions,
                    collectibles: .empty,
                    pendingTransfers: [],
                    activeOperation: context.currentState.activeOperation
                )
                throw WalletError.storage(fatalStorageError(error))
            }

            do {
                guard context.canUseNetworkRuntime, context.lifecycleGeneration == generation else {
                    throw WalletError.unavailable
                }
                let wallet = try await kit.add(walletAdapter: adapter)
                try Task.checkCancellation()
                guard context.canUseNetworkRuntime, context.lifecycleGeneration == generation else {
                    try? await kit.remove(walletId: wallet.id)
                    throw WalletError.unavailable
                }
                context.secretRecord = secret
                context.metadataRecord = metadata
                context.wallet = wallet
                let info = walletInfo(secret: secret)
                context.replaceState(
                    phase: .wallet(info),
                    balance: .loading(previous: nil),
                    transactions: TransactionsState(items: [], offset: 0, canLoadMore: false, isLoadingMore: false, error: nil),
                    collectibles: .empty,
                    pendingTransfers: [],
                    activeOperation: context.currentState.activeOperation
                )
                context.synchronizationRequested = true
                return info
            } catch {
                context.secretRecord = secret
                context.metadataRecord = metadata
                context.replaceState(
                    phase: .restoring,
                    balance: .idle,
                    transactions: context.currentState.transactions,
                    collectibles: .empty,
                    pendingTransfers: [],
                    activeOperation: context.currentState.activeOperation
                )
                throw walletError(error)
            }
        }
    }

    public func recoveryPhrase() -> Signal<[String], WalletError> {
        return Signal { [weak self] subscriber in
            assert(Queue.mainQueue().isCurrent())
            guard let self, let secret = self.secretRecord else {
                subscriber.putError(.noWallet)
                return EmptyDisposable
            }
            subscriber.putNext(secret.words)
            subscriber.putCompletion()
            return EmptyDisposable
        }
    }

    public func prepareTransfer(address: String, amount: Int64, comment: String?) -> Signal<PreparedTransfer, WalletError> {
        return self.performOperation(.preparingTransfer) { context in
            guard let secret = context.secretRecord, context.metadataRecord != nil else {
                throw WalletError.noWallet
            }
            let resolved = try resolveTransferInput(address: address, amount: amount, comment: comment)
            let wallet = try await context.initializedWallet()
            guard wallet.address.value == secret.address else {
                throw WalletError.storage(.identityMismatch)
            }

            guard let tokenAmount = TONTokenAmount(nanoUnits: String(resolved.amount)) else {
                throw WalletError.invalidAmount
            }
            let recipient: TONUserFriendlyAddress
            do {
                recipient = try TONUserFriendlyAddress(value: resolved.address)
            } catch {
                throw WalletError.invalidAddress
            }
            guard !recipient.isTestnetOnly else {
                throw WalletError.invalidAddress
            }
            var request = try await wallet.transferTONTransaction(request: TONTransferRequest(
                transferAmount: tokenAmount,
                recipientAddress: recipient,
                comment: resolved.comment
            ))
            let expiresAt = floor(Date().timeIntervalSince1970) + walletPreparedTransferLifetime
            request.validUntil = expiresAt
            let preview = try await wallet.preview(transactionRequest: request)
            try Task.checkCancellation()
            guard context.canUseNetworkRuntime else {
                throw WalletError.unavailable
            }
            guard preview.result == .success else {
                throw WalletError.previewFailed
            }
            guard let trace = preview.trace, !trace.isIncomplete else {
                throw WalletError.previewIncomplete
            }
            let fee = try previewFee(trace.transactions.values)
            let transfer = PreparedTransfer(
                id: UUID().uuidString,
                recipient: resolved.address,
                amount: resolved.amount,
                comment: resolved.comment,
                fee: fee,
                expiresAt: Int32(expiresAt)
            )
            context.preparedTransfers[transfer.id] = PreparedTransferRecord(
                walletAddress: secret.address,
                transfer: transfer,
                request: request
            )
            context.removeExpiredPreparedTransfers()
            return transfer
        }
    }

    public func submitTransfer(_ prepared: PreparedTransfer) -> Signal<SubmittedTransfer, WalletError> {
        return self.performOperation(.submittingTransfer, cancelOnDispose: false) { context in
            guard let secret = context.secretRecord, let metadata = context.metadataRecord else {
                throw WalletError.noWallet
            }
            guard let record = context.preparedTransfers[prepared.id], record.transfer == prepared else {
                throw WalletError.preparedTransferNotFound
            }
            guard record.walletAddress == secret.address else {
                throw WalletError.preparedTransferNotFound
            }
            guard TimeInterval(prepared.expiresAt) > Date().timeIntervalSince1970 else {
                context.preparedTransfers.removeValue(forKey: prepared.id)
                throw WalletError.preparedTransferExpired
            }
            let wallet = try await context.initializedWallet()
            try Task.checkCancellation()

            let broadcasting = PendingTransfer(
                id: prepared.id,
                recipient: prepared.recipient,
                amount: prepared.amount,
                comment: prepared.comment,
                createdAt: currentTimestamp(),
                status: .broadcasting
            )
            var updatedMetadata = metadata
            updatedMetadata.pendingTransfers.removeAll { $0.id == broadcasting.id }
            updatedMetadata.pendingTransfers.append(broadcasting)
            do {
                try context.vault.writeMetadata(updatedMetadata)
            } catch let error as WalletKeychainVault.Error {
                throw WalletError.storage(fatalStorageError(error))
            }
            context.metadataRecord = updatedMetadata
            context.replaceState(
                phase: context.currentState.phase,
                balance: context.currentState.balance,
                transactions: context.currentState.transactions,
                pendingTransfers: updatedMetadata.pendingTransfers,
                activeOperation: context.currentState.activeOperation
            )

            guard context.canUseNetworkRuntime else {
                do {
                    try context.vault.writeMetadata(metadata)
                } catch let error as WalletKeychainVault.Error {
                    throw WalletError.storage(fatalStorageError(error))
                }
                context.metadataRecord = metadata
                context.replaceState(
                    phase: context.currentState.phase,
                    balance: context.currentState.balance,
                    transactions: context.currentState.transactions,
                    pendingTransfers: metadata.pendingTransfers,
                    activeOperation: context.currentState.activeOperation
                )
                throw WalletError.unavailable
            }
            context.activeOperationCancellation = nil
            context.preparedTransfers.removeValue(forKey: prepared.id)
            _ = try await wallet.send(transactionRequest: record.request)
            let pending = PendingTransfer(
                id: broadcasting.id,
                recipient: broadcasting.recipient,
                amount: broadcasting.amount,
                comment: broadcasting.comment,
                createdAt: broadcasting.createdAt,
                status: .pending
            )
            if var responseMetadata = context.metadataRecord,
               responseMetadata.pendingTransfers.contains(where: { $0.id == pending.id }) {
                responseMetadata.pendingTransfers.removeAll { $0.id == pending.id }
                responseMetadata.pendingTransfers.append(pending)
                context.metadataRecord = responseMetadata
                context.replaceState(
                    phase: context.currentState.phase,
                    balance: context.currentState.balance,
                    transactions: context.currentState.transactions,
                    pendingTransfers: responseMetadata.pendingTransfers,
                    activeOperation: context.currentState.activeOperation
                )
                try? context.vault.writeMetadata(responseMetadata)
            }
            context.synchronizationRequested = true
            context.startPendingPollingIfNeeded()
            return SubmittedTransfer(pendingTransfer: pending)
        }
    }

    public func loadMoreTransactions() -> Signal<Void, WalletError> {
        return self.performOperation(.loadingMoreTransactions) { context in
            guard context.currentState.transactions.canLoadMore else {
                return Void()
            }
            if let synchronizationTask = context.synchronizationTask {
                synchronizationTask.cancel()
                await synchronizationTask.value
                context.synchronizationTask = nil
                context.synchronizationRequested = true
            }
            let wallet = try await context.initializedWallet()
            let requestOffset = context.currentState.transactions.offset
            let loadingState = TransactionsState(
                items: context.currentState.transactions.items,
                offset: requestOffset,
                canLoadMore: context.currentState.transactions.canLoadMore,
                isLoadingMore: true,
                error: context.currentState.transactions.error
            )
            context.replaceState(
                phase: context.currentState.phase,
                balance: context.currentState.balance,
                transactions: loadingState,
                pendingTransfers: context.currentState.pendingTransfers,
                activeOperation: context.currentState.activeOperation
            )
            do {
                let response = try await wallet.client.accountTransactions(
                    addresses: [wallet.address],
                    limit: walletTransactionFetchLimit,
                    offset: requestOffset
                )
                try Task.checkCancellation()
                guard context.canUseNetworkRuntime else {
                    throw WalletError.unavailable
                }
                await context.resolveUsdtJettonWalletAddressIfNeeded(wallet: wallet)
                try Task.checkCancellation()
                guard context.canUseNetworkRuntime else {
                    throw WalletError.unavailable
                }
                let page = try walletTransactions(
                    from: response.transactions,
                    usdtJettonWalletRawAddress: context.usdtJettonWalletRawAddress
                )
                let currentTransactions = context.currentState.transactions
                let existingItems = context.transactionsByReconcilingStreamOverlays(
                    in: currentTransactions.items,
                    with: response.transactions
                )
                let items = mergeTransactions(existing: existingItems, new: page)
                let state = TransactionsState(
                    items: items,
                    offset: max(currentTransactions.offset, requestOffset + response.transactions.count),
                    canLoadMore: response.transactions.count == walletTransactionFetchLimit,
                    isLoadingMore: false,
                    error: nil
                )
                context.replaceState(
                    phase: context.currentState.phase,
                    balance: context.currentState.balance,
                    transactions: state,
                    pendingTransfers: context.currentState.pendingTransfers,
                    activeOperation: context.currentState.activeOperation
                )
                return Void()
            } catch {
                let syncError = synchronizationError(error)
                context.logSynchronizationFailure(
                    scope: "transactions_page",
                    error: error,
                    category: syncError
                )
                let currentTransactions = context.currentState.transactions
                let state = TransactionsState(
                    items: currentTransactions.items,
                    offset: currentTransactions.offset,
                    canLoadMore: currentTransactions.canLoadMore,
                    isLoadingMore: false,
                    error: syncError
                )
                context.replaceState(
                    phase: context.currentState.phase,
                    balance: context.currentState.balance,
                    transactions: state,
                    pendingTransfers: context.currentState.pendingTransfers,
                    activeOperation: context.currentState.activeOperation
                )
                throw walletError(error)
            }
        }
    }

    public func loadMoreCollectibles() -> Signal<Void, WalletError> {
        return self.performOperation(.loadingMoreCollectibles) { context in
            guard context.currentState.collectibles.canLoadMore else {
                return Void()
            }
            if let synchronizationTask = context.synchronizationTask {
                synchronizationTask.cancel()
                await synchronizationTask.value
                context.synchronizationTask = nil
                context.synchronizationRequested = true
            }
            let wallet = try await context.initializedWallet()
            let requestOffset = context.currentState.collectibles.offset
            let loadingState = CollectiblesState(
                items: context.currentState.collectibles.items,
                offset: requestOffset,
                canLoadMore: context.currentState.collectibles.canLoadMore,
                isLoadingMore: true,
                error: context.currentState.collectibles.error
            )
            context.replaceState(
                phase: context.currentState.phase,
                balance: context.currentState.balance,
                transactions: context.currentState.transactions,
                collectibles: loadingState,
                pendingTransfers: context.currentState.pendingTransfers,
                activeOperation: context.currentState.activeOperation
            )
            do {
                let response = try await wallet.nfts(request: TONNFTsRequest(
                    pagination: TONPagination(limit: walletCollectibleFetchLimit, offset: requestOffset)
                ))
                try Task.checkCancellation()
                guard context.canUseNetworkRuntime else {
                    throw WalletError.unavailable
                }
                let currentCollectibles = context.currentState.collectibles
                let page = try await context.resolvedWalletCollectibles(
                    from: response.nfts,
                    wallet: wallet,
                    previousItems: currentCollectibles.items
                )
                try Task.checkCancellation()
                guard context.canUseNetworkRuntime else {
                    throw WalletError.unavailable
                }
                let items = mergeCollectibles(existing: currentCollectibles.items, new: page)
                let state = CollectiblesState(
                    items: items,
                    offset: max(currentCollectibles.offset, requestOffset + response.nfts.count),
                    canLoadMore: response.nfts.count == walletCollectibleFetchLimit,
                    isLoadingMore: false,
                    error: nil
                )
                context.replaceState(
                    phase: context.currentState.phase,
                    balance: context.currentState.balance,
                    transactions: context.currentState.transactions,
                    collectibles: state,
                    pendingTransfers: context.currentState.pendingTransfers,
                    activeOperation: context.currentState.activeOperation
                )
                return Void()
            } catch {
                let syncError = synchronizationError(error)
                context.logSynchronizationFailure(
                    scope: "collectibles_page",
                    error: error,
                    category: syncError
                )
                let currentCollectibles = context.currentState.collectibles
                let state = CollectiblesState(
                    items: currentCollectibles.items,
                    offset: currentCollectibles.offset,
                    canLoadMore: currentCollectibles.canLoadMore,
                    isLoadingMore: false,
                    error: syncError
                )
                context.replaceState(
                    phase: context.currentState.phase,
                    balance: context.currentState.balance,
                    transactions: context.currentState.transactions,
                    collectibles: state,
                    pendingTransfers: context.currentState.pendingTransfers,
                    activeOperation: context.currentState.activeOperation
                )
                throw walletError(error)
            }
        }
    }

    public func deleteWallet() -> Signal<Void, WalletError> {
        return self.performOperation(
            .deleting,
            cancelOnDispose: false,
            cancelOnEnvironmentLoss: false
        ) { context in
            let hasStoredSecret: Bool
            do {
                if context.secretRecord != nil {
                    hasStoredSecret = true
                } else {
                    hasStoredSecret = try context.vault.containsSecret()
                }
            } catch let error as WalletKeychainVault.Error {
                throw WalletError.storage(fatalStorageError(error))
            }
            guard hasStoredSecret else {
                throw WalletError.noWallet
            }

            let previousWalletId = context.wallet?.id
            let previousKit = context.kit
            context.lifecycleGeneration &+= 1
            context.toncenterProxy.setEnabled(false)
            context.isStartingStreaming = false
            context.balanceLastSuccessfulAt = nil
            context.walletInitializationTask?.cancel()
            context.walletInitializationTask = nil
            context.runtimeTask?.cancel()
            context.runtimeTask = nil
            context.synchronizationTask?.cancel()
            context.synchronizationTask = nil
            context.retryTask?.cancel()
            context.retryTask = nil
            context.pendingPollTask?.cancel()
            context.pendingPollTask = nil
            context.streamSnapshotTask?.cancel()
            context.streamSnapshotTask = nil
            context.stopStreaming()
            context.wallet = nil
            context.kit = nil
            context.secretRecord = nil
            context.metadataRecord = nil
            context.preparedTransfers.removeAll()
            context.streamTransactionOverlaysByTrace.removeAll()
            context.collectibleMetadataCache.removeAll()
            context.usdtJettonWalletRawAddress = nil
            context.synchronizationRequested = false
            context.replaceState(
                phase: .restoring,
                balance: .idle,
                transactions: TransactionsState(items: [], offset: 0, canLoadMore: false, isLoadingMore: false, error: nil),
                collectibles: .empty,
                pendingTransfers: [],
                activeOperation: context.currentState.activeOperation
            )

            var firstStorageError: FatalStorageError?
            var didDeleteSecret = false
            do {
                try context.vault.deleteSecret()
                didDeleteSecret = true
            } catch let error as WalletKeychainVault.Error {
                firstStorageError = fatalStorageError(error)
            } catch {
                firstStorageError = .corrupted
            }
            do {
                try context.vault.deleteMetadata()
            } catch let error as WalletKeychainVault.Error {
                if firstStorageError == nil {
                    firstStorageError = fatalStorageError(error)
                }
            } catch {
                if firstStorageError == nil {
                    firstStorageError = .corrupted
                }
            }
            context.replaceState(
                phase: didDeleteSecret ? .empty : .failed(firstStorageError ?? .corrupted),
                balance: .idle,
                transactions: TransactionsState(items: [], offset: 0, canLoadMore: false, isLoadingMore: false, error: nil),
                collectibles: .empty,
                pendingTransfers: [],
                activeOperation: context.currentState.activeOperation
            )

            if let previousWalletId, let previousKit {
                Task { @MainActor in
                    try? await previousKit.remove(walletId: previousWalletId)
                }
            }
            if let firstStorageError {
                throw WalletError.storage(firstStorageError)
            }
            return Void()
        }
    }

    private func performUtility<Value>(
        _ body: @escaping (WalletContext) async throws -> Value
    ) -> Signal<Value, WalletError> {
        return Signal { [weak self] subscriber in
            let cancellation = WalletOperationCancellation()
            let task = Task { @MainActor [weak self] in
                guard let self else {
                    subscriber.putError(.unavailable)
                    return
                }
                do {
                    let value = try await body(self)
                    try Task.checkCancellation()
                    subscriber.putNext(value)
                    subscriber.putCompletion()
                } catch let error as WalletError {
                    subscriber.putError(error)
                } catch is CancellationError {
                    subscriber.putError(.unavailable)
                } catch {
                    subscriber.putError(walletError(error))
                }
            }
            cancellation.setTask(task)
            return ActionDisposable {
                cancellation.cancel()
            }
        }
    }

    private func performOperation<Value>(
        _ operation: ActiveOperation,
        cancelOnDispose: Bool = true,
        cancelOnEnvironmentLoss: Bool = true,
        body: @escaping (WalletContext) async throws -> Value
    ) -> Signal<Value, WalletError> {
        return Signal { [weak self] subscriber in
            let cancellation = WalletOperationCancellation()
            let task = Task { @MainActor [weak self] in
                guard let self else {
                    subscriber.putError(.unavailable)
                    return
                }
                guard self.currentState.activeOperation == nil else {
                    subscriber.putError(.operationInProgress)
                    return
                }
                if cancelOnEnvironmentLoss {
                    self.activeOperationCancellation = cancellation
                }
                self.setActiveOperation(operation)
                defer {
                    if self.activeOperationCancellation === cancellation {
                        self.activeOperationCancellation = nil
                    }
                    self.setActiveOperation(nil)
                    self.evaluateRuntimeDemand()
                }
                do {
                    let value = try await body(self)
                    try Task.checkCancellation()
                    subscriber.putNext(value)
                    subscriber.putCompletion()
                } catch let error as WalletError {
                    subscriber.putError(error)
                } catch is CancellationError {
                    subscriber.putError(.unavailable)
                } catch {
                    subscriber.putError(walletError(error))
                }
            }
            cancellation.setTask(task)
            return ActionDisposable {
                if cancelOnDispose {
                    cancellation.cancel()
                }
            }
        }
    }

    private func setActiveOperation(_ operation: ActiveOperation?) {
        self.replaceState(
            phase: self.currentState.phase,
            balance: self.currentState.balance,
            transactions: self.currentState.transactions,
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: operation
        )
        if operation == nil, self.synchronizationRequested {
            self.requestSynchronization()
        }
    }

    private func environmentDidChange() {
        if !self.canUseNetworkRuntime {
            self.cancelFiatRatesRequest()
            self.toncenterProxy.setEnabled(false)
            self.activeOperationCancellation?.cancel()
            self.synchronizationTask?.cancel()
            self.synchronizationTask = nil
            self.retryTask?.cancel()
            self.retryTask = nil
            self.pendingPollTask?.cancel()
            self.pendingPollTask = nil
            self.streamSnapshotTask?.cancel()
            self.streamSnapshotTask = nil
            self.stopStreaming()
            if !self.isNetworkAvailable, self.stateSubscriberCount > 0 {
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: .stale(
                        previous: self.currentState.balance.currentValue,
                        error: .network,
                        lastSuccessfulAt: self.balanceLastSuccessfulAt
                    ),
                    transactions: TransactionsState(
                        items: self.currentState.transactions.items,
                        offset: self.currentState.transactions.offset,
                        canLoadMore: self.currentState.transactions.canLoadMore,
                        isLoadingMore: false,
                        error: .network
                    ),
                    collectibles: CollectiblesState(
                        items: self.currentState.collectibles.items,
                        offset: self.currentState.collectibles.offset,
                        canLoadMore: self.currentState.collectibles.canLoadMore,
                        isLoadingMore: false,
                        error: .network
                    ),
                    pendingTransfers: self.currentState.pendingTransfers,
                    activeOperation: self.currentState.activeOperation,
                    fiat: FiatState(
                        selectedCurrency: self.currentState.fiat.selectedCurrency,
                        rates: .stale(
                            previous: self.currentState.fiat.rates.currentValue,
                            error: .network,
                            lastSuccessfulAt: self.fiatRatesLastSuccessfulAt
                        )
                    )
                )
            }
            self.releaseRuntimeIfPossible()
        } else {
            self.synchronizationRequested = true
            self.evaluateRuntimeDemand()
        }
    }

    private var canUseNetworkRuntime: Bool {
        return self.isApplicationInForeground && self.isAccountCurrent && self.isNetworkAvailable
    }

    private var hasRuntimeDemand: Bool {
        return self.stateSubscriberCount > 0
            || self.currentState.activeOperation != nil
            || !self.currentState.pendingTransfers.isEmpty
    }

    private func evaluateRuntimeDemand() {
        guard self.canUseNetworkRuntime, self.hasRuntimeDemand else {
            self.releaseRuntimeIfPossible()
            return
        }
        self.toncenterProxy.setEnabled(true)
        self.requestFiatRatesIfNeeded()
        guard self.secretRecord != nil else {
            return
        }
        if self.wallet == nil, self.runtimeTask == nil {
            let generation = self.lifecycleGeneration
            self.runtimeTask = Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                defer {
                    if self.lifecycleGeneration == generation {
                        self.runtimeTask = nil
                    }
                }
                do {
                    _ = try await self.initializedWallet()
                    guard self.lifecycleGeneration == generation, self.secretRecord != nil else {
                        return
                    }
                    self.retryAttempt = 0
                    self.synchronizationRequested = true
                    self.requestSynchronization()
                    self.startPendingPollingIfNeeded()
                } catch let error as WalletError {
                    guard self.lifecycleGeneration == generation else {
                        return
                    }
                    if case let .storage(storageError) = error {
                        self.replaceState(
                            phase: .failed(storageError),
                            balance: self.currentState.balance,
                            transactions: self.currentState.transactions,
                            pendingTransfers: self.currentState.pendingTransfers,
                            activeOperation: self.currentState.activeOperation
                        )
                    } else {
                        let syncError = synchronizationError(error)
                        self.logSynchronizationFailure(
                            scope: "runtime_restore",
                            error: error,
                            category: syncError
                        )
                        self.markSynchronizationUnavailable(error: syncError)
                        if syncError.isRetryable {
                            self.scheduleRetry()
                        }
                    }
                } catch {
                    guard self.lifecycleGeneration == generation else {
                        return
                    }
                    let syncError = synchronizationError(error)
                    self.logSynchronizationFailure(
                        scope: "runtime_restore",
                        error: error,
                        category: syncError
                    )
                    self.markSynchronizationUnavailable(error: syncError)
                    if syncError.isRetryable {
                        self.scheduleRetry()
                    }
                }
            }
        } else {
            self.requestSynchronization()
            self.startPendingPollingIfNeeded()
        }
    }

    private func releaseRuntimeIfPossible() {
        guard self.currentState.activeOperation == nil else {
            return
        }
        if !self.canUseNetworkRuntime || !self.hasRuntimeDemand {
            self.cancelFiatRatesRequest()
            self.toncenterProxy.setEnabled(false)
            self.lifecycleGeneration &+= 1
            self.isStartingStreaming = false
            self.synchronizationTask?.cancel()
            self.synchronizationTask = nil
            self.retryTask?.cancel()
            self.retryTask = nil
            self.pendingPollTask?.cancel()
            self.pendingPollTask = nil
            self.streamSnapshotTask?.cancel()
            self.streamSnapshotTask = nil
            self.synchronizationRequested = true
            self.stopStreaming()
            self.walletInitializationTask?.cancel()
            self.walletInitializationTask = nil
            self.runtimeTask?.cancel()
            self.runtimeTask = nil
            self.wallet = nil
            self.kit = nil
        }
    }

    private func requestFiatRatesIfNeeded() {
        assert(Queue.mainQueue().isCurrent())
        guard self.canUseNetworkRuntime, self.hasRuntimeDemand, self.fiatRatesDataTask == nil else {
            return
        }
        self.fiatRatesRefreshTask?.cancel()
        self.fiatRatesRefreshTask = nil

        let previous = self.currentState.fiat.rates.currentValue
        self.replaceState(
            phase: self.currentState.phase,
            balance: self.currentState.balance,
            transactions: self.currentState.transactions,
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: self.currentState.activeOperation,
            fiat: FiatState(selectedCurrency: self.currentState.fiat.selectedCurrency, rates: .loading(previous: previous))
        )

        guard let url = URL(string: walletFiatRatesUrl) else {
            self.updateFiatRatesFailure(.invalidData)
            return
        }
        self.fiatRatesRequestGeneration &+= 1
        let generation = self.fiatRatesRequestGeneration
        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Queue.mainQueue().async {
                guard let self, self.fiatRatesRequestGeneration == generation else {
                    return
                }
                self.fiatRatesDataTask = nil
                if let error {
                    if (error as? URLError)?.code == .cancelled {
                        return
                    }
                    if (error as? URLError)?.code == .timedOut {
                        self.updateFiatRatesFailure(.timeout)
                    } else {
                        self.updateFiatRatesFailure(.network)
                    }
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.updateFiatRatesFailure(.invalidData)
                    return
                }
                guard (200 ..< 300).contains(httpResponse.statusCode) else {
                    self.updateFiatRatesFailure(.http(statusCode: httpResponse.statusCode))
                    return
                }
                guard let data,
                      let response = try? JSONDecoder().decode(FiatRatesResponse.self, from: data),
                      let tonValue = response.rates["TON"].flatMap(Double.init),
                      tonValue.isFinite,
                      tonValue > 0.0 else {
                    self.updateFiatRatesFailure(.invalidData)
                    return
                }
                var result: [FiatCurrency: FiatRate] = [:]
                for currency in FiatCurrency.allCases {
                    guard let unitsPerUsd = response.rates[currency.rawValue].flatMap(Double.init),
                          unitsPerUsd.isFinite,
                          unitsPerUsd > 0.0 else {
                        self.updateFiatRatesFailure(.invalidData)
                        return
                    }
                    let unitsPerGram = unitsPerUsd / tonValue
                    guard unitsPerGram.isFinite, unitsPerGram > 0.0 else {
                        self.updateFiatRatesFailure(.invalidData)
                        return
                    }
                    result[currency] = FiatRate(unitsPerUsd: unitsPerUsd, unitsPerGram: unitsPerGram)
                }
                let updatedAt = currentTimestamp()
                self.fiatRatesLastSuccessfulAt = updatedAt
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: self.currentState.balance,
                    transactions: self.currentState.transactions,
                    pendingTransfers: self.currentState.pendingTransfers,
                    activeOperation: self.currentState.activeOperation,
                    fiat: FiatState(
                        selectedCurrency: self.currentState.fiat.selectedCurrency,
                        rates: .value(result, updatedAt: updatedAt)
                    )
                )
                self.scheduleFiatRatesRefresh()
            }
        }
        self.fiatRatesDataTask = task
        task.resume()
    }

    private func updateFiatRatesFailure(_ error: SynchronizationError) {
        assert(Queue.mainQueue().isCurrent())
        let previous = self.currentState.fiat.rates.currentValue
        self.replaceState(
            phase: self.currentState.phase,
            balance: self.currentState.balance,
            transactions: self.currentState.transactions,
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: self.currentState.activeOperation,
            fiat: FiatState(
                selectedCurrency: self.currentState.fiat.selectedCurrency,
                rates: .stale(
                    previous: previous,
                    error: error,
                    lastSuccessfulAt: self.fiatRatesLastSuccessfulAt
                )
            )
        )
        self.scheduleFiatRatesRefresh()
    }

    private func scheduleFiatRatesRefresh() {
        guard self.canUseNetworkRuntime, self.hasRuntimeDemand else {
            return
        }
        self.fiatRatesRefreshTask?.cancel()
        self.fiatRatesRefreshTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(walletFiatRatesRefreshInterval * 1_000_000_000.0))
            } catch {
                return
            }
            guard let self else {
                return
            }
            self.fiatRatesRefreshTask = nil
            self.requestFiatRatesIfNeeded()
        }
    }

    private func cancelFiatRatesRequest() {
        self.fiatRatesRequestGeneration &+= 1
        self.fiatRatesDataTask?.cancel()
        self.fiatRatesDataTask = nil
        self.fiatRatesRefreshTask?.cancel()
        self.fiatRatesRefreshTask = nil
    }

    private func initializedKit() async throws -> TONWalletKit {
        guard self.canUseNetworkRuntime else {
            throw WalletError.unavailable
        }
        self.toncenterProxy.setEnabled(true)
        if let kit = self.kit {
            return kit
        }
        let generation = self.lifecycleGeneration
        let toncenterProxy = self.toncenterProxy
        let configuration = TONWalletKitConfiguration(
            networkConfigurations: Set([
                TONWalletKitConfiguration.NetworkConfiguration(
                    network: .mainnet,
                    apiClient: .toncenter(TONWalletKitConfiguration.APIClientConfiguration(
                        key: "",
                        timeout: 30.0,
                        requestHandler: { request in
                            return try await toncenterProxy.perform(request)
                        }
                    ))
                )
            ]),
            walletManifest: TONWalletKitConfiguration.Manifest(
                name: "Telegram Wallet",
                appName: "Telegram",
                imageUrl: "https://telegram.org/img/t_logo.png",
                aboutUrl: "https://telegram.org",
                universalLink: "https://t.me",
                deepLink: "tg://",
                bridgeUrl: "https://connect.ton.org/bridge"
            ),
            storage: .memory,
            bridge: nil,
            features: []
        )
        let kit = TONWalletKit(configuration: configuration)
        try await kit.initialize()
        guard self.canUseNetworkRuntime, self.lifecycleGeneration == generation else {
            throw WalletError.unavailable
        }
        self.kit = kit
        return kit
    }

    private func initializedWallet() async throws -> any TONWalletProtocol {
        guard self.canUseNetworkRuntime else {
            throw WalletError.unavailable
        }
        if let wallet = self.wallet {
            return wallet
        }
        if let task = self.walletInitializationTask {
            let generation = self.lifecycleGeneration
            let wallet = try await task.value
            guard self.canUseNetworkRuntime, self.lifecycleGeneration == generation else {
                throw WalletError.unavailable
            }
            return wallet
        }
        let generation = self.lifecycleGeneration
        let task: Task<any TONWalletProtocol, Error> = Task { @MainActor [weak self] in
            guard let self else {
                throw WalletError.unavailable
            }
            return try await self.restoreWallet(generation: generation)
        }
        self.walletInitializationTask = task
        do {
            let wallet = try await task.value
            if self.lifecycleGeneration == generation {
                self.walletInitializationTask = nil
            }
            guard self.canUseNetworkRuntime, self.lifecycleGeneration == generation else {
                throw WalletError.unavailable
            }
            return wallet
        } catch {
            if self.lifecycleGeneration == generation {
                self.walletInitializationTask = nil
            }
            throw error
        }
    }

    private func restoreWallet(generation: Int) async throws -> any TONWalletProtocol {
        guard self.canUseNetworkRuntime, self.lifecycleGeneration == generation else {
            throw WalletError.unavailable
        }
        guard let secret = self.secretRecord, let metadata = self.metadataRecord else {
            throw WalletError.noWallet
        }
        guard secret.schemaVersion == 1, metadata.schemaVersion == 1 else {
            throw WalletError.storage(.unsupportedVersion)
        }
        guard secret.network == TONNetwork.mainnet.chainId else {
            throw WalletError.storage(.unsupportedVersion)
        }
        let words: [String]
        do {
            words = try validatedMnemonicWords(secret.words)
        } catch {
            throw WalletError.storage(.corrupted)
        }
        let kit = try await self.initializedKit()
        guard self.canUseNetworkRuntime,
              self.lifecycleGeneration == generation,
              self.secretRecord?.address == secret.address else {
            throw WalletError.unavailable
        }
        let mnemonic = TONMnemonic(value: words)
        guard try await kit.validateMnemonic(mnemonic) else {
            throw WalletError.storage(.corrupted)
        }
        guard self.canUseNetworkRuntime,
              self.lifecycleGeneration == generation,
              self.secretRecord?.address == secret.address else {
            throw WalletError.unavailable
        }
        let signer = try await kit.signer(mnemonic: mnemonic)
        let adapter: any TONWalletAdapterProtocol
        switch secret.walletVersion {
        case .v4R2:
            adapter = try await kit.walletV4R2Adapter(
                signer: signer,
                parameters: TONV4R2WalletParameters(
                    network: .mainnet,
                    domain: nil,
                    walletId: secret.walletId,
                    workchain: secret.workchain
                )
            )
        case .v5R1:
            adapter = try await kit.walletV5R1Adapter(
                signer: signer,
                parameters: TONV5R1WalletParameters(
                    network: .mainnet,
                    domain: nil,
                    walletId: secret.walletId,
                    workchain: secret.workchain
                )
            )
        }
        guard self.canUseNetworkRuntime,
              self.lifecycleGeneration == generation,
              self.secretRecord?.address == secret.address else {
            throw WalletError.unavailable
        }
        guard try adapter.address(testnet: false).value == secret.address,
              try adapter.publicKey().value == secret.publicKey else {
            throw WalletError.storage(.identityMismatch)
        }
        let wallet = try await kit.add(walletAdapter: adapter)
        guard self.canUseNetworkRuntime,
              self.lifecycleGeneration == generation,
              self.secretRecord?.address == secret.address,
              let currentMetadata = self.metadataRecord else {
            try? await kit.remove(walletId: wallet.id)
            throw WalletError.unavailable
        }
        self.wallet = wallet
        self.replaceState(
            phase: .wallet(walletInfo(secret: secret)),
            balance: self.currentState.balance,
            transactions: self.currentState.transactions,
            pendingTransfers: currentMetadata.pendingTransfers,
            activeOperation: self.currentState.activeOperation
        )
        return wallet
    }

    private func inspectCandidate(
        version: WalletVersion,
        adapter: any TONWalletAdapterProtocol,
        kit: TONWalletKit
    ) async throws -> ImportCandidate {
        let address = try adapter.address(testnet: false)
        try Task.checkCancellation()
        guard self.canUseNetworkRuntime else {
            throw WalletError.unavailable
        }
        let wallet = try await kit.add(walletAdapter: adapter)
        var balance: Int64?
        var isActive: Bool?
        do {
            let accountState = try await wallet.client.accountState(address: address, seqno: nil)
            balance = int64Amount(accountState.rawBalance)
            isActive = accountState.status != .nonExisting || (balance ?? 0) != 0
        } catch {
            balance = nil
            isActive = nil
        }
        do {
            try Task.checkCancellation()
        } catch {
            try? await kit.remove(walletId: wallet.id)
            throw error
        }
        guard self.canUseNetworkRuntime else {
            try? await kit.remove(walletId: wallet.id)
            throw WalletError.unavailable
        }
        try? await kit.remove(walletId: wallet.id)
        return ImportCandidate(version: version, address: address.value, balance: balance, isActive: isActive)
    }

    private func resolvedWalletCollectibles(
        from nfts: [TONNFT],
        wallet: any TONWalletProtocol,
        previousItems: [Collectible]
    ) async throws -> [Collectible] {
        var result: [Collectible] = []
        var indexByAddress: [String: Int] = [:]
        var receivedAtByAddress: [TONRawAddress: Int32] = [:]
        result.reserveCapacity(nfts.count)

        for collectible in previousItems {
            guard let receivedAt = collectible.receivedAt,
                  receivedAt > 0,
                  let address = try? TONUserFriendlyAddress(value: collectible.address) else {
                continue
            }
            receivedAtByAddress[address.raw] = receivedAt
        }

        for nft in nfts {
            try Task.checkCancellation()

            let address = nft.address.value
            var metadata = walletCollectibleMetadata(from: nft)
            if let cachedMetadata = self.collectibleMetadataCache[address] {
                metadata.merge(cachedMetadata)
            }
            if !metadata.isComplete, let metadataUrl = walletCollectibleMetadataUrl(from: nft) {
                do {
                    let remoteMetadata = try await walletCollectibleMetadata(from: metadataUrl)
                    try Task.checkCancellation()
                    metadata.merge(remoteMetadata)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    if Task.isCancelled {
                        throw CancellationError()
                    }
                    self.log("event=collectible_metadata_failed errorType=\(String(reflecting: type(of: error)))")
                }
            }
            if metadata.name != nil || metadata.imageUrl != nil {
                self.collectibleMetadataCache[address] = metadata
            }

            let collectible = walletCollectible(from: nft, metadata: metadata)
            if let existingIndex = indexByAddress[address] {
                result[existingIndex] = collectible
            } else {
                indexByAddress[address] = result.count
                result.append(collectible)
            }
        }

        do {
            var batchOffset = 0
            while batchOffset < nfts.count {
                try Task.checkCancellation()
                let upperBound = min(nfts.count, batchOffset + walletCollectibleFetchLimit)
                let batch = nfts[batchOffset ..< upperBound].map(\.address)
                let response = try await wallet.client.nftTransfers(request: TONNFTTransfersRequest(
                    ownerAddresses: [wallet.address],
                    itemAddresses: batch,
                    direction: .incoming,
                    pagination: TONPagination(limit: 1000, offset: 0)
                ))
                try Task.checkCancellation()

                for transfer in response.transfers {
                    guard !transfer.transactionAborted, transfer.transactionNow > 0 else {
                        continue
                    }
                    let address = transfer.nftAddress.raw
                    receivedAtByAddress[address] = max(receivedAtByAddress[address] ?? 0, transfer.transactionNow)
                }
                batchOffset = upperBound
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            self.logSynchronizationFailure(scope: "collectibles_receipts", error: error)
        }

        return result.map { collectible in
            guard let address = try? TONUserFriendlyAddress(value: collectible.address) else {
                return collectible
            }
            return Collectible(
                address: collectible.address,
                name: collectible.name,
                imageUrl: collectible.imageUrl,
                receivedAt: receivedAtByAddress[address.raw]
            )
        }
    }

    private func resolveUsdtJettonWalletAddressIfNeeded(wallet: any TONWalletProtocol) async {
        guard self.usdtJettonWalletRawAddress == nil else {
            return
        }
        let generation = self.lifecycleGeneration
        do {
            let masterAddress = try TONUserFriendlyAddress(value: walletUsdtJettonMasterAddress)
            let address = try await wallet.jettonWalletAddress(jettonAddress: masterAddress)
            try Task.checkCancellation()
            guard self.canUseNetworkRuntime,
                  self.lifecycleGeneration == generation,
                  self.wallet?.address.raw == wallet.address.raw else {
                return
            }
            self.usdtJettonWalletRawAddress = address.raw
        } catch is CancellationError {
        } catch {
            guard self.lifecycleGeneration == generation else {
                return
            }
            self.logSynchronizationFailure(scope: "usdt_wallet_resolution", error: error)
        }
    }

    private func requestSynchronization() {
        guard self.synchronizationRequested,
              self.canUseNetworkRuntime,
              self.hasRuntimeDemand,
              self.currentState.activeOperation == nil,
              self.synchronizationTask == nil,
              let wallet = self.wallet else {
            return
        }
        self.synchronizationRequested = false
        let lifecycleGeneration = self.lifecycleGeneration
        let previousBalance = self.currentState.balance.currentValue
        let balanceState: Resource<Int64>
        if case .stale = self.currentState.balance {
            balanceState = self.currentState.balance
        } else {
            balanceState = .loading(previous: previousBalance)
        }
        self.replaceState(
            phase: self.currentState.phase,
            balance: balanceState,
            transactions: TransactionsState(
                items: self.currentState.transactions.items,
                offset: self.currentState.transactions.offset,
                canLoadMore: self.currentState.transactions.canLoadMore,
                isLoadingMore: false,
                error: self.currentState.transactions.error
            ),
            collectibles: CollectiblesState(
                items: self.currentState.collectibles.items,
                offset: self.currentState.collectibles.offset,
                canLoadMore: self.currentState.collectibles.canLoadMore,
                isLoadingMore: false,
                error: self.currentState.collectibles.error
            ),
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: self.currentState.activeOperation
        )
        self.synchronizationTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            var hadError = false
            var shouldRetry = false
            do {
                let balance = try await wallet.balance()
                try Task.checkCancellation()
                guard self.lifecycleGeneration == lifecycleGeneration,
                      self.secretRecord != nil,
                      self.wallet?.address.raw == wallet.address.raw else {
                    return
                }
                guard let value = int64Amount(balance) else {
                    throw WalletError.sdk("Balance is outside Int64 range")
                }
                let updatedAt = currentTimestamp()
                self.balanceLastSuccessfulAt = updatedAt
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: .value(value, updatedAt: updatedAt),
                    transactions: self.currentState.transactions,
                    pendingTransfers: self.currentState.pendingTransfers,
                    activeOperation: self.currentState.activeOperation
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled,
                      self.lifecycleGeneration == lifecycleGeneration,
                      self.secretRecord != nil,
                      self.wallet?.address.raw == wallet.address.raw else {
                    return
                }
                hadError = true
                let syncError = synchronizationError(error)
                self.logSynchronizationFailure(
                    scope: "balance_snapshot",
                    error: error,
                    category: syncError
                )
                shouldRetry = shouldRetry || syncError.isRetryable
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: .stale(
                        previous: self.currentState.balance.currentValue,
                        error: syncError,
                        lastSuccessfulAt: self.currentState.balance.lastSuccessfulAt ?? self.balanceLastSuccessfulAt
                    ),
                    transactions: self.currentState.transactions,
                    pendingTransfers: self.currentState.pendingTransfers,
                    activeOperation: self.currentState.activeOperation
                )
            }

            do {
                let response = try await wallet.client.accountTransactions(
                    addresses: [wallet.address],
                    limit: walletTransactionFetchLimit,
                    offset: 0
                )
                try Task.checkCancellation()
                guard self.lifecycleGeneration == lifecycleGeneration,
                      self.secretRecord != nil,
                      self.wallet?.address.raw == wallet.address.raw else {
                    return
                }
                await self.resolveUsdtJettonWalletAddressIfNeeded(wallet: wallet)
                try Task.checkCancellation()
                guard self.lifecycleGeneration == lifecycleGeneration,
                      self.secretRecord != nil,
                      self.wallet?.address.raw == wallet.address.raw else {
                    return
                }
                let transactions = try walletTransactions(
                    from: response.transactions,
                    usdtJettonWalletRawAddress: self.usdtJettonWalletRawAddress
                )
                let authoritativeExisting = self.transactionsByReconcilingStreamOverlays(
                    in: self.currentState.transactions.items,
                    with: response.transactions
                )
                let merged = mergeTransactions(existing: authoritativeExisting, new: transactions)
                let state = TransactionsState(
                    items: merged,
                    offset: max(self.currentState.transactions.offset, response.transactions.count),
                    canLoadMore: response.transactions.count == walletTransactionFetchLimit || self.currentState.transactions.canLoadMore,
                    isLoadingMore: false,
                    error: nil
                )
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: self.currentState.balance,
                    transactions: state,
                    pendingTransfers: self.confirmPendingTransfers(with: transactions),
                    activeOperation: self.currentState.activeOperation
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled,
                      self.lifecycleGeneration == lifecycleGeneration,
                      self.secretRecord != nil,
                      self.wallet?.address.raw == wallet.address.raw else {
                    return
                }
                hadError = true
                let syncError = synchronizationError(error)
                self.logSynchronizationFailure(
                    scope: "transactions_snapshot",
                    error: error,
                    category: syncError
                )
                shouldRetry = shouldRetry || syncError.isRetryable
                let state = TransactionsState(
                    items: self.currentState.transactions.items,
                    offset: self.currentState.transactions.offset,
                    canLoadMore: self.currentState.transactions.canLoadMore,
                    isLoadingMore: false,
                    error: syncError
                )
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: self.currentState.balance,
                    transactions: state,
                    pendingTransfers: self.currentState.pendingTransfers,
                    activeOperation: self.currentState.activeOperation
                )
            }

            do {
                let refreshLimit = max(walletCollectibleFetchLimit, self.currentState.collectibles.offset)
                let response = try await wallet.nfts(request: TONNFTsRequest(
                    pagination: TONPagination(limit: refreshLimit, offset: 0)
                ))
                try Task.checkCancellation()
                guard self.lifecycleGeneration == lifecycleGeneration,
                      self.secretRecord != nil,
                      self.wallet?.address.raw == wallet.address.raw else {
                    return
                }
                let items = try await self.resolvedWalletCollectibles(
                    from: response.nfts,
                    wallet: wallet,
                    previousItems: self.currentState.collectibles.items
                )
                try Task.checkCancellation()
                guard self.lifecycleGeneration == lifecycleGeneration,
                      self.secretRecord != nil,
                      self.wallet?.address.raw == wallet.address.raw else {
                    return
                }
                let state = CollectiblesState(
                    items: items,
                    offset: response.nfts.count,
                    canLoadMore: response.nfts.count == refreshLimit,
                    isLoadingMore: false,
                    error: nil
                )
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: self.currentState.balance,
                    transactions: self.currentState.transactions,
                    collectibles: state,
                    pendingTransfers: self.currentState.pendingTransfers,
                    activeOperation: self.currentState.activeOperation
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled,
                      self.lifecycleGeneration == lifecycleGeneration,
                      self.secretRecord != nil,
                      self.wallet?.address.raw == wallet.address.raw else {
                    return
                }
                hadError = true
                let syncError = synchronizationError(error)
                self.logSynchronizationFailure(
                    scope: "collectibles_snapshot",
                    error: error,
                    category: syncError
                )
                shouldRetry = shouldRetry || syncError.isRetryable
                let state = CollectiblesState(
                    items: self.currentState.collectibles.items,
                    offset: self.currentState.collectibles.offset,
                    canLoadMore: self.currentState.collectibles.canLoadMore,
                    isLoadingMore: false,
                    error: syncError
                )
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: self.currentState.balance,
                    transactions: self.currentState.transactions,
                    collectibles: state,
                    pendingTransfers: self.currentState.pendingTransfers,
                    activeOperation: self.currentState.activeOperation
                )
            }

            guard self.lifecycleGeneration == lifecycleGeneration else {
                return
            }
            self.synchronizationTask = nil
            if hadError {
                if shouldRetry {
                    self.scheduleRetry()
                } else {
                    self.retryAttempt = 0
                    self.retryTask?.cancel()
                    self.retryTask = nil
                    self.streamRetryAttempt = 0
                    self.streamRetryTask?.cancel()
                    self.streamRetryTask = nil
                }
            } else {
                self.retryAttempt = 0
                self.retryTask?.cancel()
                self.retryTask = nil
            }
            if !hadError || shouldRetry {
                self.startStreamingIfNeeded()
            }
            let hasQueuedSynchronization = self.synchronizationRequested
            if hasQueuedSynchronization {
                self.requestSynchronization()
            }
            self.releaseRuntimeIfPossible()
        }
    }

    private func scheduleRetry() {
        guard self.retryTask == nil, self.canUseNetworkRuntime, self.hasRuntimeDemand else {
            return
        }
        let delays: [Double] = [1.0, 2.0, 4.0, 8.0, 15.0, 30.0, 60.0]
        let delay = delays[min(self.retryAttempt, delays.count - 1)] * Double.random(in: 0.85 ... 1.15)
        self.retryAttempt = min(self.retryAttempt + 1, delays.count - 1)
        self.retryTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000.0))
            } catch {
                return
            }
            guard let self else {
                return
            }
            self.retryTask = nil
            self.synchronizationRequested = true
            self.evaluateRuntimeDemand()
        }
    }

    private func startPendingPollingIfNeeded() {
        guard !self.currentState.pendingTransfers.isEmpty,
              self.pendingPollTask == nil,
              self.canUseNetworkRuntime,
              !self.isStreamingConnected else {
            return
        }
        self.pendingPollTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            while true {
                let now = Int64(currentTimestamp())
                guard self.currentState.pendingTransfers.contains(where: {
                    Int64($0.createdAt) + 60 > now
                }) else {
                    break
                }
                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                } catch {
                    return
                }
                let updatedNow = Int64(currentTimestamp())
                guard self.canUseNetworkRuntime,
                      self.currentState.pendingTransfers.contains(where: {
                          Int64($0.createdAt) + 60 > updatedNow
                      }) else {
                    break
                }
                self.synchronizationRequested = true
                self.requestSynchronization()
            }
            self.pendingPollTask = nil
            self.releaseRuntimeIfPossible()
        }
    }

    private func startStreamingIfNeeded() {
        guard self.streamingProvider == nil,
              !self.isStartingStreaming,
              self.streamRetryTask == nil,
              self.canUseNetworkRuntime,
              self.hasRuntimeDemand,
              let kit = self.kit,
              let wallet = self.wallet else {
            return
        }
        let generation = self.lifecycleGeneration
        self.isStartingStreaming = true
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                if self.lifecycleGeneration == generation {
                    self.isStartingStreaming = false
                }
            }
            guard self.streamingProvider == nil,
                  self.canUseNetworkRuntime,
                  self.hasRuntimeDemand,
                  self.lifecycleGeneration == generation else {
                return
            }
            do {
                let provider = try await kit.streamingProvider(config: TONTonCenterStreamingProviderConfig(
                    network: .mainnet,
                    apiKey: walletApiKey
                ))
                guard self.canUseNetworkRuntime,
                      self.hasRuntimeDemand,
                      self.lifecycleGeneration == generation,
                      self.wallet?.address.raw == wallet.address.raw else {
                    try? provider.disconnect()
                    return
                }
                self.streamingProvider = provider

                provider.balance(address: wallet.address.value)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { [weak self] completion in
                        guard let self, self.lifecycleGeneration == generation else {
                            return
                        }
                        if case let .failure(error) = completion {
                            self.logSynchronizationFailure(scope: "balance_stream", error: error)
                            self.streamingDidDisconnect()
                        }
                    }, receiveValue: { [weak self] update in
                        guard let self,
                              self.lifecycleGeneration == generation,
                              update.address.raw == wallet.address.raw,
                              let balance = int64Amount(update.rawBalance) else {
                            return
                        }
                        let updatedAt = currentTimestamp()
                        self.balanceLastSuccessfulAt = updatedAt
                        self.replaceState(
                            phase: self.currentState.phase,
                            balance: .value(balance, updatedAt: updatedAt),
                            transactions: self.currentState.transactions,
                            pendingTransfers: self.currentState.pendingTransfers,
                            activeOperation: self.currentState.activeOperation
                        )
                    })
                    .store(in: &self.streamingCancellables)

                provider.transactions(address: wallet.address.value)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { [weak self] completion in
                        guard let self, self.lifecycleGeneration == generation else {
                            return
                        }
                        if case let .failure(error) = completion {
                            self.logSynchronizationFailure(scope: "transactions_stream", error: error)
                            self.streamingDidDisconnect()
                        }
                    }, receiveValue: { [weak self] update in
                        guard let self,
                              self.lifecycleGeneration == generation,
                              update.address.raw == wallet.address.raw else {
                            return
                        }
                        let traceKey = transactionTraceKey(update.traceHash.value)
                        if update.status == .invalidated {
                            let items = self.transactionsByRemovingStreamOverlay(
                                for: traceKey,
                                from: self.currentState.transactions.items
                            )
                            let state = TransactionsState(
                                items: items,
                                offset: self.currentState.transactions.offset,
                                canLoadMore: self.currentState.transactions.canLoadMore,
                                isLoadingMore: self.currentState.transactions.isLoadingMore,
                                error: self.currentState.transactions.error
                            )
                            self.replaceState(
                                phase: self.currentState.phase,
                                balance: self.currentState.balance,
                                transactions: state,
                                pendingTransfers: self.currentState.pendingTransfers,
                                activeOperation: self.currentState.activeOperation
                            )
                            self.scheduleCoalescedStreamSnapshot()
                            return
                        }
                        do {
                            let transactions = try walletTransactions(
                                from: update.transactions,
                                usdtJettonWalletRawAddress: self.usdtJettonWalletRawAddress
                            )
                            let keys = Set(transactions.map(transactionKey))
                            let existingItems = self.transactionsByRemovingStreamOverlay(
                                for: traceKey,
                                from: self.currentState.transactions.items
                            )
                            self.streamTransactionOverlaysByTrace[traceKey] = StreamTransactionOverlay(
                                status: update.status,
                                transactionKeys: keys
                            )
                            let merged = mergeTransactions(existing: existingItems, new: transactions)
                            let state = TransactionsState(
                                items: merged,
                                offset: self.currentState.transactions.offset,
                                canLoadMore: self.currentState.transactions.canLoadMore,
                                isLoadingMore: self.currentState.transactions.isLoadingMore,
                                error: nil
                            )
                            self.replaceState(
                                phase: self.currentState.phase,
                                balance: self.currentState.balance,
                                transactions: state,
                                pendingTransfers: update.status == .pending
                                    ? self.currentState.pendingTransfers
                                    : self.confirmPendingTransfers(with: transactions),
                                activeOperation: self.currentState.activeOperation
                            )
                            self.scheduleCoalescedStreamSnapshot()
                        } catch {
                            self.logSynchronizationFailure(scope: "transactions_stream_decode", error: error)
                            self.scheduleCoalescedStreamSnapshot()
                        }
                    })
                    .store(in: &self.streamingCancellables)

                provider.connectionChange()
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { [weak self] completion in
                        guard let self, self.lifecycleGeneration == generation else {
                            return
                        }
                        if case let .failure(error) = completion {
                            self.logSynchronizationFailure(scope: "connection_stream", error: error)
                        }
                        self.streamingDidDisconnect()
                    }, receiveValue: { [weak self] isConnected in
                        guard let self, self.lifecycleGeneration == generation else {
                            return
                        }
                        self.isStreamingConnected = isConnected
                        if isConnected {
                            self.streamRetryAttempt = 0
                            self.streamRetryTask?.cancel()
                            self.streamRetryTask = nil
                            self.pendingPollTask?.cancel()
                            self.pendingPollTask = nil
                            self.scheduleCoalescedStreamSnapshot()
                        } else {
                            self.streamingDidDisconnect()
                        }
                    })
                    .store(in: &self.streamingCancellables)

                try provider.connect()
            } catch {
                guard self.lifecycleGeneration == generation else {
                    return
                }
                self.logSynchronizationFailure(scope: "stream_start", error: error)
                self.stopStreaming()
                self.synchronizationRequested = true
                self.requestSynchronization()
                self.scheduleStreamRetry()
                self.startPendingPollingIfNeeded()
            }
        }
    }

    private func transactionsByRemovingStreamOverlay(
        for traceKey: String,
        from transactions: [Transaction]
    ) -> [Transaction] {
        guard let overlay = self.streamTransactionOverlaysByTrace.removeValue(forKey: traceKey) else {
            return transactions
        }
        return transactions.filter { !overlay.transactionKeys.contains(transactionKey($0)) }
    }

    private func transactionsByReconcilingStreamOverlays(
        in existing: [Transaction],
        with restTransactions: [TONTransaction]
    ) -> [Transaction] {
        var transactionKeysByTrace: [String: Set<String>] = [:]
        for transaction in restTransactions {
            transactionKeysByTrace[transactionTraceKey(transaction.traceExternalHash.value), default: []]
                .insert(transactionHashKey(transaction.hash.value))
        }

        var removableKeys = Set<String>()
        for (traceKey, transactionKeys) in transactionKeysByTrace {
            guard var overlay = self.streamTransactionOverlaysByTrace[traceKey] else {
                continue
            }
            removableKeys.formUnion(overlay.transactionKeys)
            if overlay.status == .finalized {
                self.streamTransactionOverlaysByTrace.removeValue(forKey: traceKey)
            } else {
                // REST can observe a transaction before the stream finalizes its trace.
                // Keep tracking the canonical hashes so an empty invalidation update can remove them.
                overlay.transactionKeys = transactionKeys
                self.streamTransactionOverlaysByTrace[traceKey] = overlay
            }
        }
        guard !removableKeys.isEmpty else {
            return existing
        }
        return existing.filter { !removableKeys.contains(transactionKey($0)) }
    }

    private func streamingDidDisconnect() {
        guard self.streamingProvider != nil else {
            return
        }
        self.stopStreaming()
        self.synchronizationRequested = true
        self.requestSynchronization()
        self.scheduleStreamRetry()
        self.startPendingPollingIfNeeded()
    }

    private func stopStreaming() {
        self.isStreamingConnected = false
        self.streamRetryTask?.cancel()
        self.streamRetryTask = nil
        self.streamingCancellables.removeAll()
        if let provider = self.streamingProvider {
            try? provider.disconnect()
        }
        self.streamingProvider = nil
        self.streamSnapshotTask?.cancel()
        self.streamSnapshotTask = nil
    }

    private func scheduleStreamRetry() {
        guard self.streamRetryTask == nil,
              self.canUseNetworkRuntime,
              self.hasRuntimeDemand else {
            return
        }
        let delays: [Double] = [1.0, 2.0, 4.0, 8.0, 15.0, 30.0, 60.0]
        let delay = delays[min(self.streamRetryAttempt, delays.count - 1)] * Double.random(in: 0.85 ... 1.15)
        self.streamRetryAttempt = min(self.streamRetryAttempt + 1, delays.count - 1)
        self.streamRetryTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000.0))
            } catch {
                return
            }
            guard let self else {
                return
            }
            self.streamRetryTask = nil
            self.startStreamingIfNeeded()
        }
    }

    private func scheduleCoalescedStreamSnapshot() {
        guard self.streamSnapshotTask == nil else {
            return
        }
        self.streamSnapshotTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 750_000_000)
            } catch {
                return
            }
            guard let self else {
                return
            }
            self.streamSnapshotTask = nil
            self.synchronizationRequested = true
            self.requestSynchronization()
        }
    }

    private func confirmPendingTransfers(with transactions: [Transaction]) -> [PendingTransfer] {
        guard var metadata = self.metadataRecord else {
            return self.currentState.pendingTransfers
        }
        let original = metadata.pendingTransfers
        metadata.pendingTransfers.removeAll { pending in
            transactions.contains { transaction in
                guard transaction.direction == .outgoing,
                      transaction.counterparty == pending.recipient,
                      transaction.amount == pending.amount,
                      abs(Int64(transaction.timestamp) - Int64(pending.createdAt)) <= 10 * 60 else {
                    return false
                }
                return transaction.comment == pending.comment
            }
        }
        if metadata.pendingTransfers != original {
            self.metadataRecord = metadata
            try? self.vault.writeMetadata(metadata)
        }
        return metadata.pendingTransfers
    }

    private func markSynchronizationUnavailable(error: SynchronizationError) {
        self.replaceState(
            phase: self.currentState.phase,
            balance: .stale(
                previous: self.currentState.balance.currentValue,
                error: error,
                lastSuccessfulAt: self.currentState.balance.lastSuccessfulAt
            ),
            transactions: TransactionsState(
                items: self.currentState.transactions.items,
                offset: self.currentState.transactions.offset,
                canLoadMore: self.currentState.transactions.canLoadMore,
                isLoadingMore: false,
                error: error
            ),
            collectibles: CollectiblesState(
                items: self.currentState.collectibles.items,
                offset: self.currentState.collectibles.offset,
                canLoadMore: self.currentState.collectibles.canLoadMore,
                isLoadingMore: false,
                error: error
            ),
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: self.currentState.activeOperation
        )
    }

    private func removeExpiredPreparedTransfers() {
        let now = currentTimestamp()
        self.preparedTransfers = self.preparedTransfers.filter { $0.value.transfer.expiresAt > now }
    }

    private func logSynchronizationFailure(
        scope: String,
        error: Error,
        category: SynchronizationError? = nil
    ) {
        let category = category ?? synchronizationError(error)
        var fields = [
            "event=sync_failed",
            "scope=\(scope)",
            "category=\(synchronizationErrorLogCategory(category))",
            "retryAttempt=\(self.retryAttempt)",
            "streamRetryAttempt=\(self.streamRetryAttempt)",
            "errorType=\(String(reflecting: type(of: error)))"
        ]
        if let reason = synchronizationErrorLogReason(error) {
            fields.append("reason=\(reason)")
        }
        if let path = synchronizationErrorLogPath(error) {
            fields.append("path=\(path)")
        }
        self.log(fields.joined(separator: " "))
    }

    private func replaceState(
        phase: Phase,
        balance: Resource<Int64>,
        transactions: TransactionsState,
        collectibles: CollectiblesState? = nil,
        pendingTransfers: [PendingTransfer],
        activeOperation: ActiveOperation?,
        fiat: FiatState? = nil
    ) {
        let state = State(
            phase: phase,
            balance: balance,
            transactions: transactions,
            collectibles: collectibles ?? self.currentState.collectibles,
            pendingTransfers: pendingTransfers,
            activeOperation: activeOperation,
            fiat: fiat ?? self.currentState.fiat
        )
        if state != self.currentState {
            self.currentState = state
            self.statePromise.set(state)
        }
    }

    private func withMainQueue(_ f: @escaping () -> Void) {
        if Queue.mainQueue().isCurrent() {
            f()
        } else {
            Queue.mainQueue().async(f)
        }
    }
}

private func synchronizationError(_ error: Error) -> WalletContext.SynchronizationError {
    if error is WalletDataError {
        return .invalidData
    }
    if let error = error as? WalletContext.WalletError {
        switch error {
        case .unavailable:
            return .unavailable
        case .network:
            return .network
        case let .sdk(message):
            return categorizedSynchronizationError(message) ?? .sdk
        default:
            return .sdk
        }
    }
    if let error = error as? URLError {
        if error.code == .timedOut {
            return .timeout
        }
        return .network
    }
    return categorizedSynchronizationError(error.localizedDescription) ?? .sdk
}

private func categorizedSynchronizationError(_ message: String) -> WalletContext.SynchronizationError? {
    let tokens = message.split(whereSeparator: { character in
        return !character.isLetter && !character.isNumber
    })
    if tokens.count >= 2 {
        for index in 0 ..< tokens.count - 1 {
            let token = tokens[index].lowercased()
            var statusCode: Int?
            if token == "http" {
                statusCode = Int(tokens[index + 1])
            } else if token == "status" {
                if let value = Int(tokens[index + 1]) {
                    statusCode = value
                } else if index + 2 < tokens.count, tokens[index + 1].lowercased() == "code" {
                    statusCode = Int(tokens[index + 2])
                }
            }
            if let statusCode, (100 ... 599).contains(statusCode) {
                return .http(statusCode: statusCode)
            }
        }
    }

    let lowercaseMessage = message.lowercased()
    if lowercaseMessage.contains("timed out")
        || lowercaseMessage.contains("timeout") {
        return .timeout
    }
    if lowercaseMessage.contains("invalid hash")
        || lowercaseMessage.contains("can not convert to addressfriendly")
        || lowercaseMessage.contains("cannot convert to addressfriendly")
        || lowercaseMessage.contains("data couldn’t be read")
        || lowercaseMessage.contains("data couldn't be read")
        || lowercaseMessage.contains("data could not be read")
        || lowercaseMessage.contains("tonwalletkit decoding ") {
        return .invalidData
    }
    if lowercaseMessage.contains("network")
        || lowercaseMessage.contains("offline")
        || lowercaseMessage.contains("failed to fetch")
        || lowercaseMessage.contains("internet connection")
        || lowercaseMessage.contains("not connected")
        || lowercaseMessage.contains("could not connect")
        || lowercaseMessage.contains("connection lost") {
        return .network
    }
    return nil
}

private func synchronizationErrorLogCategory(_ error: WalletContext.SynchronizationError) -> String {
    switch error {
    case .unavailable:
        return "unavailable"
    case .network:
        return "network"
    case .timeout:
        return "timeout"
    case let .http(statusCode):
        return "http_\(statusCode)"
    case .invalidData:
        return "invalid_data"
    case .sdk:
        return "sdk"
    }
}

private func synchronizationErrorLogReason(_ error: Error) -> String? {
    if let urlError = error as? URLError, urlError.code == .timedOut {
        return "url_request_timed_out"
    }

    let message: String
    if let walletError = error as? WalletContext.WalletError,
       case let .sdk(value) = walletError {
        message = value
    } else {
        message = error.localizedDescription
    }
    let lowercaseMessage = message.lowercased()
    if lowercaseMessage.contains("signal is aborted without reason") {
        return "signal_aborted_without_reason"
    }
    if lowercaseMessage.contains("fetch was aborted") {
        return "fetch_aborted"
    }
    if lowercaseMessage.contains("invalid hash: data is required") {
        return "missing_required_hash"
    }
    if lowercaseMessage.contains("can not convert to addressfriendly")
        || lowercaseMessage.contains("cannot convert to addressfriendly") {
        return "invalid_address"
    }
    if lowercaseMessage.contains("undefined is not an object")
        || lowercaseMessage.contains("cannot read properties of undefined") {
        return "invalid_response_shape"
    }
    if lowercaseMessage.contains("data couldn’t be read")
        || lowercaseMessage.contains("data couldn't be read")
        || lowercaseMessage.contains("data could not be read") {
        return "response_decoding_failed"
    }
    if lowercaseMessage.contains("tonwalletkit decoding key_not_found") {
        return "response_decoding_key_not_found"
    }
    if lowercaseMessage.contains("tonwalletkit decoding type_mismatch") {
        return "response_decoding_type_mismatch"
    }
    if lowercaseMessage.contains("tonwalletkit decoding value_not_found") {
        return "response_decoding_value_not_found"
    }
    if lowercaseMessage.contains("tonwalletkit decoding data_corrupted") {
        return "response_decoding_data_corrupted"
    }
    if lowercaseMessage.contains("timed out") || lowercaseMessage.contains("timeout") {
        return "request_timed_out"
    }
    return nil
}

private func synchronizationErrorLogPath(_ error: Error) -> String? {
    let message = error.localizedDescription.lowercased()
    guard message.hasPrefix("tonwalletkit decoding "),
          let range = message.range(of: " at ") else {
        return nil
    }
    let path = String(message[range.upperBound...])
    guard !path.isEmpty, path.count <= 256, path.unicodeScalars.allSatisfy({ scalar in
        switch scalar.value {
        case 48 ... 57, 97 ... 122, 46, 91, 93, 95:
            return true
        default:
            return false
        }
    }) else {
        return nil
    }
    return path
}

private func walletError(_ error: Error) -> WalletContext.WalletError {
    if let error = error as? WalletContext.WalletError {
        return error
    }
    if error is URLError {
        return .network
    }
    return .sdk(String(describing: type(of: error)))
}

private func currentTimestamp() -> Int32 {
    return Int32(clamping: Int64(Date().timeIntervalSince1970))
}

private final class WalletOperationCancellation {
    private let lock = NSLock()
    private var task: Task<Void, Never>?
    private var isCancelled = false

    func setTask(_ task: Task<Void, Never>) {
        self.lock.lock()
        if self.isCancelled {
            self.lock.unlock()
            task.cancel()
        } else {
            self.task = task
            self.lock.unlock()
        }
    }

    func cancel() {
        self.lock.lock()
        self.isCancelled = true
        let task = self.task
        self.task = nil
        self.lock.unlock()
        task?.cancel()
    }
}
