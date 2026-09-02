import Foundation
import TelegramCore

public extension WalletContext {
    enum FiatCurrency: Int32, CaseIterable, Codable, Hashable, Sendable {
        case usd, eur, rub, cny
        case aed, afn, all, amd, ars, aud
        case azn, bam, bdt, bgn, bhd, bnd
        case bob, brl, byn, cad, chf, clp
        case cop, crc, czk, dkk, dop, dzd
        case egp, etb, gbp, gel, ghs, gtq
        case hkd, hnl, hrk, huf, idr, ils
        case inr, iqd, irr, isk, jmd, jod
        case jpy, kes, kgs, krw, kzt, lbp
        case lkr, mad, mdl, mmk, mnt, mop
        case mur, mvr, mxn, myr, mzn, ngn
        case nio, nok, npr, nzd, pab, pen
        case php, pkr, pln, pyg, qar, ron
        case rsd, sar, sek, sgd, syp, thb
        case tjs, tryCurrency, ttd, twd, tzs
        case uah, ugx, uyu, uzs, vnd, yer
        case zar

        public var code: String {
            if self == .tryCurrency {
                return "TRY"
            }
            return String(describing: self).uppercased()
        }

        public var symbol: String {
            switch self {
            case .usd: return "$"
            case .eur: return "€"
            case .rub: return "₽"
            case .cny: return "¥"
            case .afn: return "؋"
            case .amd: return "֏"
            case .aud: return "A$"
            case .azn: return "₼"
            case .bdt: return "৳"
            case .brl: return "R$"
            case .cad: return "CA$"
            case .crc: return "₡"
            case .egp: return "E£"
            case .gbp: return "£"
            case .gel: return "₾"
            case .ghs: return "GH₵"
            case .hkd: return "HK$"
            case .ils: return "₪"
            case .inr: return "₹"
            case .jpy: return "JP¥"
            case .krw: return "₩"
            case .kzt: return "₸"
            case .mnt: return "₮"
            case .mxn: return "MX$"
            case .ngn: return "₦"
            case .nzd: return "NZ$"
            case .php: return "₱"
            case .pyg: return "₲"
            case .thb: return "฿"
            case .tryCurrency: return "₺"
            case .twd: return "NT$"
            case .uah: return "₴"
            case .vnd: return "₫"
            default: return self.code
            }
        }
    }

    struct FiatRate: Codable, Equatable, Sendable {
        public let unitsPerUsd: Double
        public let unitsPerGram: Double
        public init(unitsPerUsd: Double, unitsPerGram: Double) {
            self.unitsPerUsd = unitsPerUsd
            self.unitsPerGram = unitsPerGram
        }
    }

    struct FiatState: Equatable, Sendable {
        public let selectedCurrency: FiatCurrency
        public let rates: Resource<[FiatCurrency: FiatRate]>
        public init(selectedCurrency: FiatCurrency, rates: Resource<[FiatCurrency: FiatRate]>) {
            self.selectedCurrency = selectedCurrency
            self.rates = rates
        }
        public var selectedRate: FiatRate? { self.rates.currentValue?[self.selectedCurrency] }
    }

    struct WalletInfo: Equatable, Sendable {
        public let address: String
        public let publicKey: String
        public let backupEnabled: Bool
        public let canExportPhrase: Bool
        public let canEnableBackup: Bool
        public let canSign: Bool
        public var canDisableBackup: Bool { self.backupEnabled && self.canSign }
        public var canRevealPhrase: Bool { self.canSign || self.canExportPhrase }
        
        public init(
            address: String,
            publicKey: String,
            backupEnabled: Bool = false,
            canExportPhrase: Bool = false,
            canEnableBackup: Bool = false,
            canSign: Bool = false
        ) {
            self.address = address
            self.publicKey = publicKey
            self.backupEnabled = backupEnabled
            self.canExportPhrase = canExportPhrase
            self.canEnableBackup = canEnableBackup
            self.canSign = canSign
        }
    }

    struct TonConnectPermission: Equatable, Sendable {
        public let name: String
        public let title: String?
        public let text: String?
        public init(name: String, title: String?, text: String?) {
            self.name = name
            self.title = title
            self.text = text
        }
    }

    struct TonConnectRequest: Equatable, Sendable {
        public let id: String
        public let applicationName: String
        public let domain: String
        public let iconUrl: String?
        public let permissions: [TonConnectPermission]
        public let requestsProof: Bool
        public init(id: String, applicationName: String, domain: String, iconUrl: String?, permissions: [TonConnectPermission], requestsProof: Bool) {
            self.id = id
            self.applicationName = applicationName
            self.domain = domain
            self.iconUrl = iconUrl
            self.permissions = permissions
            self.requestsProof = requestsProof
        }
    }

    struct TonConnectOperationRequest: Equatable, Sendable {
        public enum Method: Equatable, Sendable { case sendTransaction, signMessage }
        public struct Message: Equatable, Sendable {
            public enum Payload: Equatable, Sendable { case empty, comment(String), raw(String) }
            public let id: String
            public let destination: String
            public let amountNanograms: String
            public let payload: Payload
            public let stateInit: String?
            public init(id: String, destination: String, amountNanograms: String, payload: Payload, stateInit: String?) {
                self.id = id
                self.destination = destination
                self.amountNanograms = amountNanograms
                self.payload = payload
                self.stateInit = stateInit
            }
        }
        public struct Action: Equatable, Sendable {
            public let id: String
            public let kind: String
            public let succeeded: Bool
            public let accounts: [String]
            public init(id: String, kind: String, succeeded: Bool, accounts: [String]) {
                self.id = id
                self.kind = kind
                self.succeeded = succeeded
                self.accounts = accounts
            }
        }
        public let id: String
        public let applicationName: String
        public let domain: String
        public let iconUrl: String?
        public let method: Method
        public let messages: [Message]
        public let feeNanograms: String?
        public let validUntil: UInt64?
        public let relayerWillSubmit: Bool
        public let needsWalletStateInit: Bool
        public let warnings: [String]
        public let actions: [Action]
        public init(
            id: String,
            applicationName: String,
            domain: String,
            iconUrl: String?,
            method: Method,
            messages: [Message],
            feeNanograms: String?,
            validUntil: UInt64?,
            relayerWillSubmit: Bool,
            needsWalletStateInit: Bool,
            warnings: [String],
            actions: [Action]
        ) {
            self.id = id
            self.applicationName = applicationName
            self.domain = domain
            self.iconUrl = iconUrl
            self.method = method
            self.messages = messages
            self.feeNanograms = feeNanograms
            self.validUntil = validUntil
            self.relayerWillSubmit = relayerWillSubmit
            self.needsWalletStateInit = needsWalletStateInit
            self.warnings = warnings
            self.actions = actions
        }
    }

    enum TonConnectPresentation: Sendable {
        case request(TonConnectRequest)
        case operation(TonConnectOperationRequest)
        case dismiss(requestId: String)
        case error(String)
    }

    enum FatalStorageError: Error, Equatable, Sendable {
        case keychainStatus(Int32), corrupted, unsupportedVersion, identityMismatch
    }

    enum SynchronizationError: Error, Equatable, Sendable {
        case unavailable, network, timeout, invalidData, sdk
        case http(statusCode: Int)
        public var isRetryable: Bool {
            switch self {
            case .unavailable, .network, .timeout, .sdk: return true
            case let .http(code): return code == 408 || code == 429 || code >= 500
            case .invalidData: return false
            }
        }
    }

    enum Resource<Value: Equatable>: Equatable {
        case idle
        case loading(previous: Value?)
        case value(Value, updatedAt: Int32)
        case stale(previous: Value?, error: SynchronizationError, lastSuccessfulAt: Int32?)
        public var currentValue: Value? {
            switch self {
            case .idle: return nil
            case let .loading(value): return value
            case let .value(value, _): return value
            case let .stale(value, _, _): return value
            }
        }
        public var lastSuccessfulAt: Int32? {
            switch self {
            case .idle, .loading: return nil
            case let .value(_, value): return value
            case let .stale(_, _, value): return value
            }
        }
    }

    struct Transaction: Equatable, Sendable {
        public enum Kind: Int32, Codable, Equatable, Sendable {
            case transfer = 0
            case deployContract = 1
        }
        public enum Direction: Int32, Codable, Equatable, Sendable { case incoming = 0, outgoing = 1, unknown = 2 }
        public enum Currency: Int32, Codable, Equatable, Sendable { case ton = 0, usdt = 1 }
        public enum Status: Int32, Codable, Equatable, Sendable { case completed = 0, pending = 1, failed = 2 }
        
        public enum Peer: Equatable, @unchecked Sendable {
            case user(EnginePeer, address: String)
            case address(String)
            case unsupported
            
            public var address: String? {
                let value: String
                switch self {
                case let .user(_, address):
                    value = address
                case let .address(address):
                    value = address
                case .unsupported:
                    return nil
                }
                if !value.isEmpty {
                    return value
                }
                return nil
            }
            
            public var displayName: String? {
                if case let .user(peer, _) = self {
                    return peer.debugDisplayTitle
                }
                return nil
            }
        }
        
        public struct CollectibleTransfer: Codable, Equatable, Sendable {
            public enum Kind: Int32, Codable, Equatable, Sendable { case gift = 0, username = 1, anonymousNumber = 2, other = 3 }
            public let address: String
            public let name: String
            public let imageUrl: String?
            public let lottieUrl: String?
            public let collectionName: String?
            public let collectionUrl: String?
            public let kind: Kind
            public init(address: String, name: String, imageUrl: String?, lottieUrl: String? = nil, collectionName: String? = nil, collectionUrl: String? = nil, kind: Kind) {
                self.address = address; self.name = name; self.imageUrl = imageUrl; self.lottieUrl = lottieUrl
                self.collectionName = collectionName; self.collectionUrl = collectionUrl; self.kind = kind
            }
        }
        public let id: String
        public let transactionHash: String?
        public let logicalTime: String
        public let timestamp: Int32
        public let kind: Kind
        public let direction: Direction
        public let amount: Int64
        public let fee: Int64
        public let peer: Peer
        public let comment: String?
        public let currency: Currency
        public let collectible: CollectibleTransfer?
        public let status: Status
        public init(id: String, transactionHash: String? = nil, logicalTime: String, timestamp: Int32, direction: Direction, amount: Int64, fee: Int64, peer: Peer, comment: String?, currency: Currency = .ton, collectible: CollectibleTransfer? = nil, status: Status = .completed, kind: Kind = .transfer) {
            self.id = id; self.transactionHash = transactionHash
            self.logicalTime = logicalTime; self.timestamp = timestamp; self.kind = kind; self.direction = direction
            self.amount = amount; self.fee = fee; self.peer = peer; self.comment = comment; self.currency = currency
            self.collectible = collectible; self.status = status
        }
        public var isVisibleInWalletHistory: Bool {
            if self.status == .failed || self.kind == .deployContract { return true }
            if self.collectible != nil { return self.direction != .unknown }
            switch self.direction {
            case .incoming: return self.currency == .usdt || self.amount >= 10_000_000
            case .outgoing: return true
            case .unknown: return false
            }
        }
    }

    struct TransactionsState: Equatable, Sendable {
        public let items: [Transaction]
        public let offset: Int
        public let canLoadMore: Bool
        public let isLoadingMore: Bool
        public let error: SynchronizationError?
        public init(items: [Transaction], offset: Int, canLoadMore: Bool, isLoadingMore: Bool, error: SynchronizationError?) {
            self.items = items; self.offset = offset; self.canLoadMore = canLoadMore
            self.isLoadingMore = isLoadingMore; self.error = error
        }
    }

    struct Collectible: Codable, Equatable, Sendable {
        public enum Kind: Int32, Codable, Equatable, Sendable { case gift = 0, username = 1, anonymousNumber = 2, other = 3 }
        public let address: String
        public let name: String
        public let imageUrl: String?
        public let subtitle: String
        public let kind: Kind
        public let description: String?
        public let lottieUrl: String?
        public let collectionName: String?
        public let collectionUrl: String?
        public let attributes: [String: String]
        public let giftSlug: String?
        public let receivedAt: Int32?
        public init(address: String, name: String, imageUrl: String?, subtitle: String = "NFT", kind: Kind = .other, description: String? = nil, lottieUrl: String? = nil, collectionName: String? = nil, collectionUrl: String? = nil, attributes: [String: String] = [:], giftSlug: String? = nil, receivedAt: Int32? = nil) {
            self.address = address; self.name = name; self.imageUrl = imageUrl; self.subtitle = subtitle; self.kind = kind
            self.description = description; self.lottieUrl = lottieUrl; self.collectionName = collectionName
            self.collectionUrl = collectionUrl; self.attributes = attributes; self.giftSlug = giftSlug; self.receivedAt = receivedAt
        }
    }

    struct CollectiblesState: Equatable, Sendable {
        public let items: [Collectible]
        public let offset: Int
        public let canLoadMore: Bool
        public let isLoadingMore: Bool
        public let error: SynchronizationError?
        public init(items: [Collectible], offset: Int, canLoadMore: Bool, isLoadingMore: Bool, error: SynchronizationError?) {
            self.items = items; self.offset = offset; self.canLoadMore = canLoadMore
            self.isLoadingMore = isLoadingMore; self.error = error
        }
        public static var empty: CollectiblesState { .init(items: [], offset: 0, canLoadMore: false, isLoadingMore: false, error: nil) }
    }

    struct PendingTransfer: Codable, Equatable, Sendable {
        public enum Status: Int32, Codable, Equatable, Sendable {
            case broadcasting = 0
            case pending = 1
            case submissionUnknown = 2
        }
        public let id: String
        public let recipient: String
        public let amount: Int64
        public let comment: String?
        public let collectibleAddress: String?
        public let normalizedHash: String?
        public let createdAt: Int32
        public let status: Status
        public init(id: String, recipient: String, amount: Int64, comment: String?, collectibleAddress: String? = nil, normalizedHash: String? = nil, createdAt: Int32, status: Status) {
            self.id = id; self.recipient = recipient; self.amount = amount; self.comment = comment
            self.collectibleAddress = collectibleAddress; self.normalizedHash = normalizedHash
            self.createdAt = createdAt; self.status = status
        }
    }

    struct PreparedBackupDisable: Equatable, Sendable {
        public enum KeyRotationPhase: Equatable, Sendable {
            case prepared
            case pending
            case confirmed
        }

        public let id: String
        public let walletAddress: String
        public let walletPublicKey: String
        public let words: [String]
        public let newPublicKey: Data
        public let signedBoc: String
        public let seqno: UInt32
        public let expiresAt: Int32
        let keyRotationPhase: KeyRotationPhase
        public init(
            id: String,
            walletAddress: String,
            walletPublicKey: String,
            words: [String],
            newPublicKey: Data,
            signedBoc: String,
            seqno: UInt32,
            expiresAt: Int32,
            keyRotationPhase: KeyRotationPhase = .prepared
        ) {
            self.id = id
            self.walletAddress = walletAddress
            self.walletPublicKey = walletPublicKey
            self.words = words
            self.newPublicKey = newPublicKey
            self.signedBoc = signedBoc
            self.seqno = seqno
            self.expiresAt = expiresAt
            self.keyRotationPhase = keyRotationPhase
        }
    }

    struct PreparedRecoveryPhraseImport: Equatable, Sendable {
        public enum Disposition: Equatable, Sendable {
            case currentWallet
            case replacement
        }

        public let disposition: Disposition
        let recordId: String
        let sourceAddress: String
        let sourcePublicKey: Data
        let candidateAddress: String
        let candidatePublicKey: Data

        init(
            disposition: Disposition,
            recordId: String,
            sourceAddress: String,
            sourcePublicKey: Data,
            candidateAddress: String,
            candidatePublicKey: Data
        ) {
            self.disposition = disposition
            self.recordId = recordId
            self.sourceAddress = sourceAddress
            self.sourcePublicKey = sourcePublicKey
            self.candidateAddress = candidateAddress
            self.candidatePublicKey = candidatePublicKey
        }
    }

    enum ActiveOperation: Equatable, Sendable {
        case creating, importing, recoveringPhrase, preparingRecoveryPhraseImport, completingRecoveryPhraseImport
        case enablingBackup, preparingBackupDisable, disablingBackup
        case preparingTransfer, submittingTransfer, loadingMoreTransactions, loadingMoreCollectibles
    }
    enum Phase: Equatable, Sendable { case restoring, provisioning, empty, wallet(WalletInfo), failed(FatalStorageError) }

    struct State: Equatable, Sendable {
        public let phase: Phase
        public let balance: Resource<Int64>
        public let transactions: TransactionsState
        public let collectibles: CollectiblesState
        public let pendingTransfers: [PendingTransfer]
        public let activeOperation: ActiveOperation?
        public let fiat: FiatState
        public init(phase: Phase, balance: Resource<Int64>, transactions: TransactionsState, collectibles: CollectiblesState = .empty, pendingTransfers: [PendingTransfer], activeOperation: ActiveOperation?, fiat: FiatState = .init(selectedCurrency: .usd, rates: .idle)) {
            self.phase = phase; self.balance = balance; self.transactions = transactions; self.collectibles = collectibles
            self.pendingTransfers = pendingTransfers; self.activeOperation = activeOperation; self.fiat = fiat
        }
    }

    enum WalletError: Error, Equatable, Sendable {
        case unavailable, noWallet, invalidMnemonic
        case invalidAddress, invalidAmount, operationInProgress, previewFailed, previewIncomplete
        case preparedTransferExpired, preparedTransferNotFound, network
        case requestPassword, invalidPassword, twoStepAuthMissing, authorizationCancelled
        case passwordTooFresh(Int32), sessionTooFresh(Int32)
        case backupDisabled, backupNotAvailable, replacementInvalid, publicKeyInvalid
        case keyRotationFailed
        case tokenInvalid, tokenExpired, clientKeyInvalid, partUnavailable, invalidBackupData
        case insufficientBalance(required: Int64)
        case storage(FatalStorageError)
        case sdk(String)
    }

    struct ResolvedTransferRecipient: Equatable, Sendable {
        public let address: String, displayName: String?
        public init(address: String, displayName: String?) { self.address = address; self.displayName = displayName }
    }
    struct CreatedWallet: Equatable, Sendable {
        public let info: WalletInfo
        public init(info: WalletInfo) { self.info = info }
    }
    struct PreparedTransfer: Equatable, Sendable {
        public let id: String, recipient: String
        public let amount: Int64
        public let comment: String?
        public let collectible: Collectible?
        public let fee: Int64
        public let expiresAt: Int32
        public init(id: String, recipient: String, amount: Int64, comment: String?, collectible: Collectible? = nil, fee: Int64, expiresAt: Int32) {
            self.id = id; self.recipient = recipient; self.amount = amount; self.comment = comment
            self.collectible = collectible; self.fee = fee; self.expiresAt = expiresAt
        }
    }
    struct SubmittedTransfer: Equatable, Sendable {
        public let pendingTransfer: PendingTransfer
        public init(pendingTransfer: PendingTransfer) { self.pendingTransfer = pendingTransfer }
    }
}

extension WalletContext.Resource: Sendable where Value: Sendable {
}

extension WalletContext.ActiveOperation {
    var defersServerWalletState: Bool {
        switch self {
        case .creating, .importing, .preparingRecoveryPhraseImport, .completingRecoveryPhraseImport:
            return true
        case .recoveringPhrase, .enablingBackup, .preparingBackupDisable, .disablingBackup,
             .preparingTransfer, .submittingTransfer, .loadingMoreTransactions, .loadingMoreCollectibles:
            return false
        }
    }
}
