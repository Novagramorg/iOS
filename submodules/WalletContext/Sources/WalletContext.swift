import Foundation
import SwiftSignalKit
import TelegramCore
import TONConnect
import TONCore
import TONCrypto
import TONToncenter
import TONWalletKit

private let walletApiKey = "84f56a3a13a49c973bba18b3b69e5589c0a87c5227631629941155ef6ab0b555"
private let walletFiatRatesRefreshInterval: TimeInterval = 15.0 * 60.0
private let walletMetadataCachedItemLimit = 10

public final class WalletContext {
    public enum FiatCurrency: String, CaseIterable, Codable, Hashable {
        case usd = "USD"
        case eur = "EUR"
        case rub = "RUB"
        case cny = "CNY"
        case aed = "AED"
        case afn = "AFN"
        case all = "ALL"
        case amd = "AMD"
        case ars = "ARS"
        case aud = "AUD"
        case azn = "AZN"
        case bam = "BAM"
        case bdt = "BDT"
        case bgn = "BGN"
        case bhd = "BHD"
        case bnd = "BND"
        case bob = "BOB"
        case brl = "BRL"
        case byn = "BYN"
        case cad = "CAD"
        case chf = "CHF"
        case clp = "CLP"
        case cop = "COP"
        case crc = "CRC"
        case czk = "CZK"
        case dkk = "DKK"
        case dop = "DOP"
        case dzd = "DZD"
        case egp = "EGP"
        case etb = "ETB"
        case gbp = "GBP"
        case gel = "GEL"
        case ghs = "GHS"
        case gtq = "GTQ"
        case hkd = "HKD"
        case hnl = "HNL"
        case hrk = "HRK"
        case huf = "HUF"
        case idr = "IDR"
        case ils = "ILS"
        case inr = "INR"
        case iqd = "IQD"
        case irr = "IRR"
        case isk = "ISK"
        case jmd = "JMD"
        case jod = "JOD"
        case jpy = "JPY"
        case kes = "KES"
        case kgs = "KGS"
        case krw = "KRW"
        case kzt = "KZT"
        case lbp = "LBP"
        case lkr = "LKR"
        case mad = "MAD"
        case mdl = "MDL"
        case mmk = "MMK"
        case mnt = "MNT"
        case mop = "MOP"
        case mur = "MUR"
        case mvr = "MVR"
        case mxn = "MXN"
        case myr = "MYR"
        case mzn = "MZN"
        case ngn = "NGN"
        case nio = "NIO"
        case nok = "NOK"
        case npr = "NPR"
        case nzd = "NZD"
        case pab = "PAB"
        case pen = "PEN"
        case php = "PHP"
        case pkr = "PKR"
        case pln = "PLN"
        case pyg = "PYG"
        case qar = "QAR"
        case ron = "RON"
        case rsd = "RSD"
        case sar = "SAR"
        case sek = "SEK"
        case sgd = "SGD"
        case syp = "SYP"
        case thb = "THB"
        case tjs = "TJS"
        case tryCurrency = "TRY"
        case ttd = "TTD"
        case twd = "TWD"
        case tzs = "TZS"
        case uah = "UAH"
        case ugx = "UGX"
        case uyu = "UYU"
        case uzs = "UZS"
        case vnd = "VND"
        case yer = "YER"
        case zar = "ZAR"

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
            case .afn:
                return "؋"
            case .amd:
                return "֏"
            case .aud:
                return "A$"
            case .azn:
                return "₼"
            case .bdt:
                return "৳"
            case .brl:
                return "R$"
            case .cad:
                return "CA$"
            case .crc:
                return "₡"
            case .egp:
                return "E£"
            case .gbp:
                return "£"
            case .gel:
                return "₾"
            case .ghs:
                return "GH₵"
            case .hkd:
                return "HK$"
            case .ils:
                return "₪"
            case .inr:
                return "₹"
            case .jpy:
                return "JP¥"
            case .krw:
                return "₩"
            case .kzt:
                return "₸"
            case .mnt:
                return "₮"
            case .mxn:
                return "MX$"
            case .ngn:
                return "₦"
            case .nzd:
                return "NZ$"
            case .php:
                return "₱"
            case .pyg:
                return "₲"
            case .thb:
                return "฿"
            case .tryCurrency:
                return "₺"
            case .twd:
                return "NT$"
            case .uah:
                return "₴"
            case .vnd:
                return "₫"
            default:
                return self.rawValue
            }
        }
    }

    public struct FiatRate: Codable, Equatable {
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

    public struct TonConnectPermission: Equatable {
        public let name: String
        public let title: String?
        public let text: String?

        public init(name: String, title: String?, text: String?) {
            self.name = name
            self.title = title
            self.text = text
        }
    }

    public struct TonConnectRequest: Equatable {
        public let id: String
        public let applicationName: String
        public let domain: String
        public let iconUrl: String?
        public let permissions: [TonConnectPermission]
        public let requestsProof: Bool

        public init(
            id: String,
            applicationName: String,
            domain: String,
            iconUrl: String?,
            permissions: [TonConnectPermission],
            requestsProof: Bool
        ) {
            self.id = id
            self.applicationName = applicationName
            self.domain = domain
            self.iconUrl = iconUrl
            self.permissions = permissions
            self.requestsProof = requestsProof
        }
    }

    public struct TonConnectTransferRequest: Equatable {
        public struct PreviewItem: Equatable {
            public enum Kind: Equatable {
                case transfer
                case callContract
                case deployContract
                case excess
                case unknown
            }

            public enum Direction: Equatable {
                case incoming
                case outgoing
            }

            public let id: String
            public let kind: Kind
            public let direction: Direction?
            public let address: String?
            public let amount: Int64?
            public let comment: String?

            public init(
                id: String,
                kind: Kind,
                direction: Direction?,
                address: String?,
                amount: Int64?,
                comment: String?
            ) {
                self.id = id
                self.kind = kind
                self.direction = direction
                self.address = address
                self.amount = amount
                self.comment = comment
            }
        }

        public let id: String
        public let applicationName: String
        public let domain: String
        public let iconUrl: String?
        public let recipient: String
        public let amount: Int64
        public let fee: Int64
        public let previewItems: [PreviewItem]

        public init(
            id: String,
            applicationName: String,
            domain: String,
            iconUrl: String?,
            recipient: String,
            amount: Int64,
            fee: Int64,
            previewItems: [PreviewItem] = []
        ) {
            self.id = id
            self.applicationName = applicationName
            self.domain = domain
            self.iconUrl = iconUrl
            self.recipient = recipient
            self.amount = amount
            self.fee = fee
            self.previewItems = previewItems
        }
    }

    public enum TonConnectPresentation {
        case request(TonConnectRequest)
        case transfer(TonConnectTransferRequest)
        case dismiss(requestId: String)
        case error(String)
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

    public struct Transaction: Codable, Equatable {
        public enum Kind: String, Codable, Equatable {
            case transfer
            case deployContract
        }

        public enum Direction: String, Codable, Equatable {
            case incoming
            case outgoing
            case unknown
        }

        public enum Currency: String, Codable, Equatable {
            case ton
            case usdt
        }

        public enum Status: String, Codable, Equatable {
            case completed
            case pending
        }

        public struct CollectibleTransfer: Codable, Equatable {
            public enum Kind: String, Codable, Equatable {
                case gift
                case username
                case anonymousNumber
                case other
            }

            public let address: String
            public let name: String
            public let imageUrl: String?
            public let lottieUrl: String?
            public let collectionName: String?
            public let collectionUrl: String?
            public let kind: Kind

            public init(
                address: String,
                name: String,
                imageUrl: String?,
                lottieUrl: String? = nil,
                collectionName: String? = nil,
                collectionUrl: String? = nil,
                kind: Kind
            ) {
                self.address = address
                self.name = name
                self.imageUrl = imageUrl
                self.lottieUrl = lottieUrl
                self.collectionName = collectionName
                self.collectionUrl = collectionUrl
                self.kind = kind
            }
        }

        public let id: String
        public let transactionHash: String?
        public let externalMessageHash: String?
        public let logicalTime: String
        public let timestamp: Int32
        public let kind: Kind
        public let direction: Direction
        public let amount: Int64
        public let fee: Int64
        public let counterparty: String?
        public let counterpartyName: String?
        public let comment: String?
        public let currency: Currency
        public let collectible: CollectibleTransfer?
        public let status: Status

        public init(
            id: String,
            transactionHash: String? = nil,
            externalMessageHash: String? = nil,
            logicalTime: String,
            timestamp: Int32,
            direction: Direction,
            amount: Int64,
            fee: Int64,
            counterparty: String?,
            counterpartyName: String? = nil,
            comment: String?,
            currency: Currency = .ton,
            collectible: CollectibleTransfer? = nil,
            status: Status = .completed,
            kind: Kind = .transfer
        ) {
            self.id = id
            self.transactionHash = transactionHash
            self.externalMessageHash = externalMessageHash
            self.logicalTime = logicalTime
            self.timestamp = timestamp
            self.kind = kind
            self.direction = direction
            self.amount = amount
            self.fee = fee
            self.counterparty = counterparty
            self.counterpartyName = counterpartyName
            self.comment = comment
            self.currency = currency
            self.collectible = collectible
            self.status = status
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case transactionHash
            case externalMessageHash
            case logicalTime
            case timestamp
            case kind
            case direction
            case amount
            case fee
            case counterparty
            case counterpartyName
            case comment
            case currency
            case collectible
            case status
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decode(String.self, forKey: .id)
            self.transactionHash = try container.decodeIfPresent(String.self, forKey: .transactionHash)
            self.externalMessageHash = try container.decodeIfPresent(String.self, forKey: .externalMessageHash)
            self.logicalTime = try container.decode(String.self, forKey: .logicalTime)
            self.timestamp = try container.decode(Int32.self, forKey: .timestamp)
            self.kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .transfer
            self.direction = try container.decode(Direction.self, forKey: .direction)
            self.amount = try container.decode(Int64.self, forKey: .amount)
            self.fee = try container.decode(Int64.self, forKey: .fee)
            self.counterparty = try container.decodeIfPresent(String.self, forKey: .counterparty)
            self.counterpartyName = try container.decodeIfPresent(String.self, forKey: .counterpartyName)
            self.comment = try container.decodeIfPresent(String.self, forKey: .comment)
            self.currency = try container.decodeIfPresent(Currency.self, forKey: .currency) ?? .ton
            self.collectible = try container.decodeIfPresent(CollectibleTransfer.self, forKey: .collectible)
            self.status = try container.decodeIfPresent(Status.self, forKey: .status) ?? .completed
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.id, forKey: .id)
            try container.encodeIfPresent(self.transactionHash, forKey: .transactionHash)
            try container.encodeIfPresent(self.externalMessageHash, forKey: .externalMessageHash)
            try container.encode(self.logicalTime, forKey: .logicalTime)
            try container.encode(self.timestamp, forKey: .timestamp)
            try container.encode(self.kind, forKey: .kind)
            try container.encode(self.direction, forKey: .direction)
            try container.encode(self.amount, forKey: .amount)
            try container.encode(self.fee, forKey: .fee)
            try container.encodeIfPresent(self.counterparty, forKey: .counterparty)
            try container.encodeIfPresent(self.counterpartyName, forKey: .counterpartyName)
            try container.encodeIfPresent(self.comment, forKey: .comment)
            try container.encode(self.currency, forKey: .currency)
            try container.encodeIfPresent(self.collectible, forKey: .collectible)
            try container.encode(self.status, forKey: .status)
        }

        public var isVisibleInWalletHistory: Bool {
            if self.kind == .deployContract {
                return true
            }
            if self.collectible != nil {
                return self.direction != .unknown
            }
            switch self.direction {
            case .incoming:
                switch self.currency {
                case .ton:
                    return self.amount >= 10_000_000
                case .usdt:
                    return true
                }
            case .outgoing:
                return true
            case .unknown:
                return false
            }
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

    public struct Collectible: Codable, Equatable {
        public enum Kind: String, Codable, Equatable {
            case gift
            case username
            case anonymousNumber
            case other
        }

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

        public init(
            address: String,
            name: String,
            imageUrl: String?,
            subtitle: String = "NFT",
            kind: Kind = .other,
            description: String? = nil,
            lottieUrl: String? = nil,
            collectionName: String? = nil,
            collectionUrl: String? = nil,
            attributes: [String: String] = [:],
            giftSlug: String? = nil,
            receivedAt: Int32? = nil
        ) {
            self.address = address
            self.name = name
            self.imageUrl = imageUrl
            self.subtitle = subtitle
            self.kind = kind
            self.description = description
            self.lottieUrl = lottieUrl
            self.collectionName = collectionName
            self.collectionUrl = collectionUrl
            self.attributes = attributes
            self.giftSlug = giftSlug
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
        public let collectibleAddress: String?
        public let normalizedHash: String?
        public let createdAt: Int32
        public let status: Status

        public init(
            id: String,
            recipient: String,
            amount: Int64,
            comment: String?,
            collectibleAddress: String? = nil,
            normalizedHash: String? = nil,
            createdAt: Int32,
            status: Status
        ) {
            self.id = id
            self.recipient = recipient
            self.amount = amount
            self.comment = comment
            self.collectibleAddress = collectibleAddress
            self.normalizedHash = normalizedHash
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

    public struct ResolvedTransferRecipient: Equatable {
        public let address: String
        public let displayName: String?

        public init(address: String, displayName: String?) {
            self.address = address
            self.displayName = displayName
        }
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
        public let collectible: Collectible?
        public let fee: Int64
        public let expiresAt: Int32

        public init(
            id: String,
            recipient: String,
            amount: Int64,
            comment: String?,
            collectible: Collectible? = nil,
            fee: Int64,
            expiresAt: Int32
        ) {
            self.id = id
            self.recipient = recipient
            self.amount = amount
            self.comment = comment
            self.collectible = collectible
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

    public var tonConnectPresentations: Signal<TonConnectPresentation, NoError> {
        return self.tonConnectPresentationPipe.signal()
    }

    public static func isTonConnectUrl(_ value: String) -> Bool {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "tg" || scheme == "tc" else {
            return false
        }
        var parameters: [String: String] = [:]
        for item in components.queryItems ?? [] {
            if let value = item.value, !value.isEmpty {
                parameters[item.name] = value
            }
        }
        return parameters["v"] == "2"
            && parameters["id"]?.isEmpty == false
            && parameters["r"]?.isEmpty == false
    }

    public static func transferAddress(from value: String) -> String? {
        return Self.normalizedMainnetTransferAddress(value)
    }

    public func resolveTransferRecipient(_ value: String) -> Signal<ResolvedTransferRecipient?, WalletError> {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return .single(nil)
        }

        if let address = Self.normalizedMainnetTransferAddress(value) {
            return .single(ResolvedTransferRecipient(address: address, displayName: nil))
        }

        guard let domain = Self.normalizedTransferDomain(value) else {
            return .single(nil)
        }

        return self.performUtility { context in
            _ = try await context.initializedKit()
            guard let client = context.toncenterClient,
                  let resolvedAddress = try await client.resolveDNS(domain: domain),
                  let address = Self.normalizedMainnetTransferAddress(resolvedAddress) else {
                return nil
            }
            return ResolvedTransferRecipient(address: address, displayName: value)
        }
    }

    private static func normalizedMainnetTransferAddress(_ value: String) -> String? {
        guard let transfer = try? TransferURL.parse(value), !transfer.isTestOnly else {
            return nil
        }
        return transfer.addressString(urlSafe: true, bounceable: false)
    }

    private static func normalizedTransferDomain(_ value: String) -> String? {
        guard value.contains("."),
              !value.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) }) else {
            return nil
        }
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count > 1, components.allSatisfy({ !$0.isEmpty }) else {
            return nil
        }
        return value.lowercased()
    }

    public func processTonConnectUrl(_ value: String) {
        guard Self.isTonConnectUrl(value) else {
            return
        }
        self.withMainQueue { [weak self] in
            guard let self, self.secretRecord != nil else {
                return
            }
            if !self.pendingTonConnectUrls.contains(value) {
                self.pendingTonConnectUrls.append(value)
            }
            self.evaluateRuntimeDemand()
            self.processPendingTonConnectUrlIfPossible()
        }
    }

    public func approveTonConnectRequest(id: String) -> Signal<Void, WalletError> {
        return Signal { [weak self] subscriber in
            guard let self else {
                subscriber.putError(.unavailable)
                return EmptyDisposable
            }
            let cancellation = WalletOperationCancellation()
            self.withMainQueue { [weak self] in
                guard let self,
                      self.canUseNetworkRuntime,
                      let pending = self.pendingTonConnectRequests.first,
                      pending.id == id,
                      case let .connection(_, request) = pending,
                      let wallet = self.wallet,
                      !self.approvingTonConnectRequestIds.contains(id) else {
                    subscriber.putError(.unavailable)
                    return
                }

                self.approvingTonConnectRequestIds.insert(id)
                let generation = self.lifecycleGeneration
                let task = Task { @MainActor [weak self] in
                    guard let self else {
                        subscriber.putError(.unavailable)
                        return
                    }
                    do {
                        guard let kit = self.kit else {
                            throw WalletError.unavailable
                        }
                        try await kit.approve(request, with: wallet)
                        try Task.checkCancellation()
                        guard self.canUseNetworkRuntime,
                              self.lifecycleGeneration == generation,
                              self.pendingTonConnectRequests.first?.id == id else {
                            throw WalletError.unavailable
                        }
                        self.approvingTonConnectRequestIds.remove(id)
                        self.completeTonConnectRequest(id: id)
                        subscriber.putNext(Void())
                        subscriber.putCompletion()
                    } catch is CancellationError {
                        self.approvingTonConnectRequestIds.remove(id)
                        subscriber.putError(.unavailable)
                    } catch {
                        self.approvingTonConnectRequestIds.remove(id)
                        subscriber.putError(walletError(error))
                    }
                }
                cancellation.setTask(task)
            }
            return ActionDisposable {
                cancellation.cancel()
            }
        }
    }

    public func approveTonConnectTransfer(id: String) -> Signal<Void, WalletError> {
        return Signal { [weak self] subscriber in
            guard let self else {
                subscriber.putError(.unavailable)
                return EmptyDisposable
            }
            let cancellation = WalletOperationCancellation()
            self.withMainQueue { [weak self] in
                guard let self,
                      self.canUseNetworkRuntime,
                      let pending = self.pendingTonConnectRequests.first,
                      pending.id == id,
                      case let .transfer(_, request) = pending,
                      self.wallet != nil,
                      !self.approvingTonConnectRequestIds.contains(id) else {
                    subscriber.putError(.unavailable)
                    return
                }

                self.approvingTonConnectRequestIds.insert(id)
                let generation = self.lifecycleGeneration
                let task = Task { @MainActor [weak self] in
                    guard let self else {
                        subscriber.putError(.unavailable)
                        return
                    }
                    do {
                        guard let kit = self.kit else {
                            throw WalletError.unavailable
                        }
                        _ = try await kit.approve(request)
                        try Task.checkCancellation()
                        guard self.canUseNetworkRuntime,
                              self.lifecycleGeneration == generation,
                              self.pendingTonConnectRequests.first?.id == id else {
                            throw WalletError.unavailable
                        }
                        self.approvingTonConnectRequestIds.remove(id)
                        self.completeTonConnectRequest(id: id)
                        self.synchronizationRequested = true
                        self.requestSynchronization()
                        subscriber.putNext(Void())
                        subscriber.putCompletion()
                    } catch is CancellationError {
                        self.approvingTonConnectRequestIds.remove(id)
                        subscriber.putError(.unavailable)
                    } catch {
                        self.approvingTonConnectRequestIds.remove(id)
                        subscriber.putError(walletError(error))
                    }
                }
                cancellation.setTask(task)
            }
            return ActionDisposable {
                cancellation.cancel()
            }
        }
    }

    public func rejectTonConnectRequest(id: String) -> Signal<Void, NoError> {
        return Signal { [weak self] subscriber in
            guard let self else {
                subscriber.putCompletion()
                return EmptyDisposable
            }
            self.withMainQueue { [weak self] in
                guard let self,
                      let index = self.pendingTonConnectRequests.firstIndex(where: { $0.id == id }) else {
                    subscriber.putNext(Void())
                    subscriber.putCompletion()
                    return
                }
                let pending = self.pendingTonConnectRequests.remove(at: index)
                self.approvingTonConnectRequestIds.remove(id)
                if index == 0 {
                    self.presentNextTonConnectRequestIfNeeded()
                }
                Task { @MainActor [weak self] in
                    do {
                        guard let kit = self?.kit else {
                            throw WalletError.unavailable
                        }
                        switch pending {
                        case let .connection(_, request):
                            try await kit.reject(request, reason: "User rejected connection")
                        case let .transfer(_, request):
                            try await kit.reject(request, reason: "User rejected transaction")
                        }
                    } catch {
                        self?.log("ton_connect_reject_failed error=\(String(describing: type(of: error)))")
                    }
                    subscriber.putNext(Void())
                    subscriber.putCompletion()
                }
            }
            return EmptyDisposable
        }
    }

    private struct PreparedTransferRecord {
        let walletAddress: String
        let transfer: PreparedTransfer
        let messages: [TransferMessage]
    }

    private enum PendingTonConnectRequest {
        case connection(model: TonConnectRequest, request: ConnectionRequest)
        case transfer(model: TonConnectTransferRequest, request: SendTransactionRequest)

        var id: String {
            switch self {
            case let .connection(model, _):
                return model.id
            case let .transfer(model, _):
                return model.id
            }
        }
    }

    private struct StreamTransactionOverlay {
        var status: StreamFinality
        var transactionKeys: Set<String>
    }

    private let engine: TelegramEngine
    private let log: (String) -> Void
    private let vault: WalletKeychainVault
    private let tonConnectStorage: WalletTonConnectStorage
    private let statePromise: ValuePromise<State>
    private let tonConnectPresentationPipe = ValuePipe<TonConnectPresentation>()
    private var currentState: State
    private var secretRecord: SecretRecord?
    private var metadataRecord: MetadataRecord?

    private var kit: TonWalletKit?
    private var toncenterClient: ToncenterClient?
    private var wallet: Wallet?
    private var tonConnectEventsTask: Task<Void, Never>?
    private var pendingTonConnectUrls: [String] = []
    private var tonConnectUrlTask: Task<Void, Never>?
    private var pendingTonConnectRequests: [PendingTonConnectRequest] = []
    private var approvingTonConnectRequestIds = Set<String>()
    private var walletInitializationTask: Task<Wallet, Error>?
    private var runtimeTask: Task<Void, Never>?
    private var synchronizationTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var streamRetryTask: Task<Void, Never>?
    private var pendingPollTask: Task<Void, Never>?
    private var streamSnapshotTask: Task<Void, Never>?
    private var streamingTask: Task<Void, Never>?
    private var isStreamingConnected = false

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
    private var invalidatedStreamTraceHashes = Set<String>()
    private var collectibleMetadataCache: [String: WalletCollectibleMetadata] = [:]
    private var usdtJettonWalletRawAddress: String?
    private var lifecycleGeneration = 0
    private let fiatRatesRequestDisposable = MetaDisposable()
    private var fiatRatesRequestInProgress = false
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
        self.engine = engine
        self.log = log
        self.vault = WalletKeychainVault(namespace: storageNamespace)
        self.tonConnectStorage = WalletTonConnectStorage(namespace: storageNamespace)
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
                let cachedBalance: Resource<Int64>
                if let balance = self.metadataRecord?.balance {
                    cachedBalance = .value(balance, updatedAt: self.metadataRecord?.balanceUpdatedAt ?? 0)
                } else {
                    cachedBalance = .idle
                }
                let cachedTransactions = Array((self.metadataRecord?.transactions ?? []).prefix(walletMetadataCachedItemLimit))
                let cachedCollectibles = Array((self.metadataRecord?.collectibles ?? []).prefix(walletMetadataCachedItemLimit))
                let cachedFiatRates: Resource<[FiatCurrency: FiatRate]>
                if let fiatRates = self.metadataRecord?.fiatRates {
                    cachedFiatRates = .value(fiatRates, updatedAt: self.metadataRecord?.fiatRatesUpdatedAt ?? 0)
                } else {
                    cachedFiatRates = .idle
                }
                self.balanceLastSuccessfulAt = self.metadataRecord?.balanceUpdatedAt
                self.fiatRatesLastSuccessfulAt = self.metadataRecord?.fiatRatesUpdatedAt
                self.currentState = State(
                    phase: .restoring,
                    balance: cachedBalance,
                    transactions: TransactionsState(
                        items: cachedTransactions,
                        offset: cachedTransactions.count,
                        canLoadMore: false,
                        isLoadingMore: false,
                        error: nil
                    ),
                    collectibles: CollectiblesState(
                        items: cachedCollectibles,
                        offset: cachedCollectibles.count,
                        canLoadMore: false,
                        isLoadingMore: false,
                        error: nil
                    ),
                    pendingTransfers: self.metadataRecord?.pendingTransfers ?? [],
                    activeOperation: nil,
                    fiat: FiatState(
                        selectedCurrency: self.metadataRecord?.selectedFiatCurrency ?? .usd,
                        rates: cachedFiatRates
                    )
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
        self.walletInitializationTask?.cancel()
        self.runtimeTask?.cancel()
        self.tonConnectEventsTask?.cancel()
        self.tonConnectUrlTask?.cancel()
        self.synchronizationTask?.cancel()
        self.retryTask?.cancel()
        self.streamRetryTask?.cancel()
        self.pendingPollTask?.cancel()
        self.streamSnapshotTask?.cancel()
        self.fiatRatesRequestDisposable.dispose()
        self.fiatRatesRefreshTask?.cancel()
        self.streamingTask?.cancel()
        if let kit = self.kit {
            Task { await kit.stop() }
        }
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

    public func isMnemonicWord(_ word: String) -> Bool {
        return MnemonicWordlist.contains(word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
    }

    public func mnemonicWordSuggestions(for prefix: String, limit: Int) -> [String] {
        let prefix = prefix.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty, limit > 0 else {
            return []
        }
        return Array(MnemonicWordlist.words.lazy.filter { $0.hasPrefix(prefix) }.prefix(limit))
    }

    public func isMnemonicValid(words: [String]) -> Bool {
        return (try? validatedMnemonicWords(words)) != nil
    }

    public func containsMnemonicWord(_ word: String) -> Signal<Bool, WalletError> {
        return self.performUtility { context in
            return context.isMnemonicWord(word)
        }
    }

    public func validateMnemonic(words: [String]) -> Signal<Bool, WalletError> {
        return self.performUtility { _ in
            let words = try validatedMnemonicWords(words)
            return try Mnemonic.validate(words)
        }
    }

    public func generateMnemonic() -> Signal<[String], WalletError> {
        return self.performUtility { _ in
            return try Mnemonic.generate(wordCount: 12)
        }
    }

    public func createWallet() -> Signal<CreatedWallet, WalletError> {
        return self.performOperation(.creating, cancelOnDispose: false) { context in
            guard case .empty = context.currentState.phase, context.secretRecord == nil else {
                throw WalletError.walletAlreadyExists
            }
            context.lifecycleGeneration &+= 1
            let generation = context.lifecycleGeneration
            context.balanceLastSuccessfulAt = nil
            context.walletInitializationTask?.cancel()
            context.walletInitializationTask = nil
            context.runtimeTask?.cancel()
            context.runtimeTask = nil

            let kit = try await context.initializedKit()
            try Task.checkCancellation()
            let words = normalizedMnemonicWords(try Mnemonic.generate(wordCount: 12))
            guard words.count == 12 else {
                throw WalletError.invalidMnemonic
            }
            let signer = try InMemorySigner(mnemonic: words)
            let nativeWallet = try Wallet(v5r1: signer, network: .mainnet)
            let address = nativeWallet.address.toString(bounceable: false)
            let publicKey = nativeWallet.publicKey.hexString
            let secret = SecretRecord(
                schemaVersion: 1,
                words: words,
                walletVersion: .v5R1,
                network: Network.mainnet.chainId,
                walletId: Int(nativeWallet.contractWalletID),
                workchain: Int(nativeWallet.address.workchain),
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
                await kit.register(wallet: nativeWallet)
                try Task.checkCancellation()
                guard context.canUseNetworkRuntime, context.lifecycleGeneration == generation else {
                    await kit.forget(walletID: nativeWallet.id)
                    throw WalletError.unavailable
                }
                context.secretRecord = secret
                context.metadataRecord = metadata
                context.wallet = nativeWallet
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
            guard try Mnemonic.validate(words) else {
                throw WalletError.invalidMnemonic
            }
            let kit = try await context.initializedKit()
            let signer = try InMemorySigner(mnemonic: words)
            let v4Wallet = try Wallet(v4r2: signer, network: .mainnet)
            let v5Wallet = try Wallet(v5r1: signer, network: .mainnet)
            let candidates = [
                try await context.inspectCandidate(version: .v4R2, wallet: v4Wallet, kit: kit),
                try await context.inspectCandidate(version: .v5R1, wallet: v5Wallet, kit: kit)
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
            context.balanceLastSuccessfulAt = nil
            context.walletInitializationTask?.cancel()
            context.walletInitializationTask = nil
            context.runtimeTask?.cancel()
            context.runtimeTask = nil
            let words = try validatedMnemonicWords(words)
            let kit = try await context.initializedKit()
            guard try Mnemonic.validate(words) else {
                throw WalletError.invalidMnemonic
            }
            let signer = try InMemorySigner(mnemonic: words)
            let nativeWallet: Wallet
            switch version {
            case .v4R2:
                nativeWallet = try Wallet(v4r2: signer, network: .mainnet)
            case .v5R1:
                nativeWallet = try Wallet(v5r1: signer, network: .mainnet)
            }

            let address = nativeWallet.address.toString(bounceable: false)
            let publicKey = nativeWallet.publicKey.hexString
            let secret = SecretRecord(
                schemaVersion: 1,
                words: words,
                walletVersion: version,
                network: Network.mainnet.chainId,
                walletId: Int(nativeWallet.contractWalletID),
                workchain: Int(nativeWallet.address.workchain),
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
                await kit.register(wallet: nativeWallet)
                try Task.checkCancellation()
                guard context.canUseNetworkRuntime, context.lifecycleGeneration == generation else {
                    await kit.forget(walletID: nativeWallet.id)
                    throw WalletError.unavailable
                }
                context.secretRecord = secret
                context.metadataRecord = metadata
                context.wallet = nativeWallet
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
            guard wallet.address.toString(bounceable: false) == secret.address else {
                throw WalletError.storage(.identityMismatch)
            }

            guard let tokenAmount = BigUInt(String(resolved.amount)) else {
                throw WalletError.invalidAmount
            }
            guard let recipient = try? Address.parse(resolved.address),
                  (try? Address.parseFriendly(resolved.address).isTestOnly) != true else {
                throw WalletError.invalidAddress
            }
            let payload = try resolved.comment.map { try TransferPayloads.comment($0) }
            let message = TransferMessage(address: recipient, amount: tokenAmount, payload: payload, bounce: false)
            let expiresAt = floor(Date().timeIntervalSince1970) + walletPreparedTransferLifetime
            let kit = try await context.initializedKit()
            let preview = await kit.preview(messages: [message], from: wallet.id)
            try Task.checkCancellation()
            guard context.canUseNetworkRuntime else {
                throw WalletError.unavailable
            }
            guard let preview, !preview.willFail else {
                throw WalletError.previewFailed
            }
            guard !preview.isIncomplete else {
                throw WalletError.previewIncomplete
            }
            guard let fee = Int64(String(preview.fees)) else {
                throw WalletError.previewFailed
            }
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
                messages: [message]
            )
            context.removeExpiredPreparedTransfers()
            return transfer
        }
    }

    public func prepareCollectibleTransfer(
        address: String,
        collectible: Collectible,
        comment: String?
    ) -> Signal<PreparedTransfer, WalletError> {
        return self.performOperation(.preparingTransfer) { context in
            guard let secret = context.secretRecord, context.metadataRecord != nil else {
                throw WalletError.noWallet
            }
            guard let recipientTransfer = try? TransferURL.parse(address),
                  !recipientTransfer.isTestOnly else {
                throw WalletError.invalidAddress
            }
            let recipient = recipientTransfer.address
            guard let itemTransfer = try? TransferURL.parse(collectible.address),
                  !itemTransfer.isTestOnly else {
                throw WalletError.invalidAddress
            }
            let item = itemTransfer.address
            let wallet = try await context.initializedWallet()
            guard wallet.address.toString(bounceable: false) == secret.address else {
                throw WalletError.storage(.identityMismatch)
            }

            let normalizedComment: String?
            if let value = comment?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                normalizedComment = value
            } else {
                normalizedComment = nil
            }
            let forwardAmount = TransferPayloads.defaultForwardAmount
            let payload = try TransferPayloads.nftTransfer(
                newOwner: recipient,
                responseDestination: wallet.address,
                comment: normalizedComment,
                forwardAmount: forwardAmount
            )
            let message = TransferMessage(
                address: item,
                amount: TransferPayloads.defaultNFTGas + forwardAmount,
                payload: payload,
                bounce: true
            )
            let expiresAt = floor(Date().timeIntervalSince1970) + walletPreparedTransferLifetime
            let kit = try await context.initializedKit()
            let preview = await kit.preview(messages: [message], from: wallet.id)
            try Task.checkCancellation()
            guard context.canUseNetworkRuntime else {
                throw WalletError.unavailable
            }
            guard let preview, !preview.willFail else {
                throw WalletError.previewFailed
            }
            guard !preview.isIncomplete else {
                throw WalletError.previewIncomplete
            }
            guard let fee = Int64(String(preview.fees)) else {
                throw WalletError.previewFailed
            }
            let transfer = PreparedTransfer(
                id: UUID().uuidString,
                recipient: address,
                amount: 0,
                comment: normalizedComment,
                collectible: collectible,
                fee: fee,
                expiresAt: Int32(expiresAt)
            )
            context.preparedTransfers[transfer.id] = PreparedTransferRecord(
                walletAddress: secret.address,
                transfer: transfer,
                messages: [message]
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
                collectibleAddress: prepared.collectible?.address,
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
            let kit = try await context.initializedKit()
            let sent: SentTransfer
            do {
                sent = try await kit.send(messages: record.messages, from: wallet.id)
            } catch {
                var rollbackMetadata = context.metadataRecord ?? metadata
                rollbackMetadata.pendingTransfers.removeAll { $0.id == broadcasting.id }
                do {
                    try context.vault.writeMetadata(rollbackMetadata)
                } catch let storageError as WalletKeychainVault.Error {
                    throw WalletError.storage(fatalStorageError(storageError))
                }
                context.metadataRecord = rollbackMetadata
                context.replaceState(
                    phase: context.currentState.phase,
                    balance: context.currentState.balance,
                    transactions: context.currentState.transactions,
                    pendingTransfers: rollbackMetadata.pendingTransfers,
                    activeOperation: context.currentState.activeOperation
                )
                throw error
            }
            let pending = PendingTransfer(
                id: broadcasting.id,
                recipient: broadcasting.recipient,
                amount: broadcasting.amount,
                comment: broadcasting.comment,
                collectibleAddress: broadcasting.collectibleAddress,
                normalizedHash: sent.normalizedHash,
                createdAt: broadcasting.createdAt,
                status: .pending
            )
            if var responseMetadata = context.metadataRecord,
               responseMetadata.pendingTransfers.contains(where: { $0.id == pending.id }) {
                responseMetadata.pendingTransfers.removeAll { $0.id == pending.id }
                responseMetadata.pendingTransfers.append(pending)
                do {
                    try context.vault.writeMetadata(responseMetadata)
                } catch let error as WalletKeychainVault.Error {
                    throw WalletError.storage(fatalStorageError(error))
                }
                context.metadataRecord = responseMetadata
                var pendingTransfers = context.confirmPendingTransfers(
                    with: context.currentState.transactions.items
                )
                if context.invalidatedStreamTraceHashes.remove(sent.normalizedHash.lowercased()) != nil {
                    pendingTransfers = context.invalidatePendingTransfer(
                        normalizedHash: sent.normalizedHash
                    )
                }
                context.replaceState(
                    phase: context.currentState.phase,
                    balance: context.currentState.balance,
                    transactions: context.currentState.transactions,
                    pendingTransfers: pendingTransfers,
                    activeOperation: context.currentState.activeOperation
                )
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
                guard let client = context.toncenterClient else {
                    throw WalletError.unavailable
                }
                let response = try await client.getTracesPage(
                    account: wallet.address.toString(),
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
                let activities = try WalletActivityExtractor.activities(
                    from: response,
                    walletAddress: wallet.address
                )
                let collectibleMetadata = try await context.resolvedWalletActionCollectibles(
                    addresses: collectibleAddresses(in: activities),
                    client: client
                )
                let decodedPage = try walletTransactions(
                    from: activities,
                    usdtJettonWalletAddress: context.usdtJettonWalletRawAddress,
                    collectibles: collectibleMetadata
                )
                let page = await context.resolvedCounterpartyNames(in: decodedPage, client: client)
                let currentTransactions = context.currentState.transactions
                let existingItems = context.transactionsByReconcilingStreamOverlays(
                    in: currentTransactions.items,
                    traceIDs: Set(response.traces.flatMap { trace in
                        [trace.traceID, trace.externalHash].compactMap { $0 }.map(transactionTraceKey)
                    })
                )
                let items = mergeTransactions(existing: existingItems, new: page)
                let state = TransactionsState(
                    items: items,
                    offset: max(currentTransactions.offset, requestOffset + response.traces.count),
                    canLoadMore: response.traces.count == walletTransactionFetchLimit,
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
                guard let kit = context.kit else {
                    throw WalletError.unavailable
                }
                let nfts = try await kit.nfts(
                    of: wallet.id,
                    limit: walletCollectibleFetchLimit,
                    offset: requestOffset
                )
                try Task.checkCancellation()
                guard context.canUseNetworkRuntime else {
                    throw WalletError.unavailable
                }
                let currentCollectibles = context.currentState.collectibles
                let page = try await context.resolvedWalletCollectibles(
                    from: nfts,
                    previousItems: currentCollectibles.items
                )
                try Task.checkCancellation()
                guard context.canUseNetworkRuntime else {
                    throw WalletError.unavailable
                }
                let items = mergeCollectibles(existing: currentCollectibles.items, new: page)
                let state = CollectiblesState(
                    items: items,
                    offset: max(currentCollectibles.offset, requestOffset + nfts.count),
                    canLoadMore: nfts.count == walletCollectibleFetchLimit,
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
            context.cancelPendingTonConnectRequests()
            context.pendingTonConnectUrls.removeAll()
            context.tonConnectUrlTask?.cancel()
            context.tonConnectUrlTask = nil
            context.lifecycleGeneration &+= 1
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
            context.toncenterClient = nil
            context.tonConnectEventsTask?.cancel()
            context.tonConnectEventsTask = nil
            context.secretRecord = nil
            context.metadataRecord = nil
            context.preparedTransfers.removeAll()
            context.streamTransactionOverlaysByTrace.removeAll()
            context.invalidatedStreamTraceHashes.removeAll()
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
            if let previousWalletId, let previousKit {
                await previousKit.forget(walletID: previousWalletId)
            }
            do {
                try await context.tonConnectStorage.clear()
            } catch let error as WalletTonConnectStorage.Error {
                firstStorageError = fatalStorageError(error)
            } catch {
                firstStorageError = .corrupted
            }
            do {
                try context.vault.deleteSecret()
                didDeleteSecret = true
            } catch let error as WalletKeychainVault.Error {
                if firstStorageError == nil {
                    firstStorageError = fatalStorageError(error)
                }
            } catch {
                if firstStorageError == nil {
                    firstStorageError = .corrupted
                }
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

    private func handleTonConnectEvent(_ event: WalletKitEvent) {
        assert(Queue.mainQueue().isCurrent())
        switch event {
        case let .connectionRequest(request):
            self.handleTonConnectConnectionRequest(request)
        case let .sendTransactionRequest(request):
            self.handleTonConnectTransactionRequest(request)
        case let .signMessageRequest(request):
            Task { @MainActor [weak self] in
                do {
                    guard let kit = self?.kit else { return }
                    try await kit.reject(request, reason: "Method not supported")
                } catch {
                    self?.log("ton_connect_sign_message_reject_failed error=\(String(describing: type(of: error)))")
                }
            }
        case let .signDataRequest(request):
            Task { @MainActor [weak self] in
                do {
                    guard let kit = self?.kit else { return }
                    try await kit.reject(request, reason: "Method not supported")
                } catch {
                    self?.log("ton_connect_sign_data_reject_failed error=\(String(describing: type(of: error)))")
                }
            }
        case .disconnected:
            break
        case let .malformedRequest(request):
            self.log("ton_connect_malformed_request id=\(request.id) reason=\(request.reason)")
        case let .bridgeTrouble(_, description):
            self.log("ton_connect_bridge_trouble description=\(description)")
        }
    }

    private func handleTonConnectConnectionRequest(_ request: ConnectionRequest) {
        assert(Queue.mainQueue().isCurrent())

        if request.dApp.manifestFailure != nil {
            //TODO:localize
            let errorText = "The app information could not be verified. Connection was cancelled."
            self.rejectTonConnectConnectionRequest(
                request,
                reason: "Unable to load TON Connect manifest",
                errorText: errorText
            )
            return
        }

        var requestsProof = false
        var permissions: [TonConnectPermission] = []
        for item in request.requestedItems {
            switch item {
            case .address:
                permissions.append(TonConnectPermission(name: "ton_addr", title: nil, text: nil))
            case .proof:
                requestsProof = true
                permissions.append(TonConnectPermission(name: "ton_proof", title: nil, text: nil))
            case let .unknown(name):
                //TODO:localize
                let errorText = "This app requested a wallet permission that is not supported yet."
                self.rejectTonConnectConnectionRequest(
                    request,
                    reason: "Requested item \(name) is not supported",
                    errorText: errorText
                )
                return
            }
        }

        let applicationName = request.dApp.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let domain = request.dApp.domain?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !applicationName.isEmpty, !domain.isEmpty else {
            //TODO:localize
            let errorText = "The app manifest is incomplete. Connection was cancelled."
            self.rejectTonConnectConnectionRequest(
                request,
                reason: "Invalid TON Connect manifest",
                errorText: errorText
            )
            return
        }

        let iconUrl: String?
        if let value = request.dApp.iconURL,
           URL(string: value)?.scheme?.lowercased() == "https" {
            iconUrl = value
        } else {
            iconUrl = nil
        }
        let model = TonConnectRequest(
            id: request.id,
            applicationName: applicationName,
            domain: domain,
            iconUrl: iconUrl,
            permissions: permissions,
            requestsProof: requestsProof
        )
        guard !self.pendingTonConnectRequests.contains(where: { $0.id == model.id }) else {
            return
        }
        let shouldPresent = self.pendingTonConnectRequests.isEmpty
        self.pendingTonConnectRequests.append(.connection(model: model, request: request))
        if shouldPresent {
            self.presentNextTonConnectRequestIfNeeded()
        }
    }

    private func handleTonConnectTransactionRequest(_ request: SendTransactionRequest) {
        assert(Queue.mainQueue().isCurrent())

        let reject: (String, String) -> Void = { [weak self] reason, errorText in
            self?.rejectTonConnectTransactionRequest(request, reason: reason, errorText: errorText)
        }
        guard let wallet = self.wallet, let secret = self.secretRecord else {
            //TODO:localize
            reject("Wallet is unavailable", "The transaction could not be opened because Wallet is unavailable.")
            return
        }
        if request.walletID != wallet.id {
            //TODO:localize
            reject("Transaction targets another wallet", "This transaction was requested for another wallet.")
            return
        }
        if let network = request.network, network != Network.mainnet.chainId {
            //TODO:localize
            reject("Network is not supported", "This transaction uses a network that is not supported.")
            return
        }
        if let fromAddress = request.from,
           (try? Address.canonicalString(fromAddress, bounceable: false))
            != (try? Address.canonicalString(secret.address, bounceable: false)) {
            //TODO:localize
            reject("Transaction sender does not match wallet", "This transaction was requested for another wallet.")
            return
        }
        if let validUntil = request.validUntil, validUntil <= UInt64(Date().timeIntervalSince1970) {
            //TODO:localize
            reject("Transaction request has expired", "This transaction request has expired.")
            return
        }
        guard request.messages.count == 1, let message = request.messages.first else {
            //TODO:localize
            reject("Only one transaction message is supported", "Transactions with multiple recipients are not supported yet.")
            return
        }
        if !message.extraCurrency.isEmpty {
            //TODO:localize
            reject("Extra currencies are not supported", "This transaction uses a currency that is not supported yet.")
            return
        }
        guard let amount = Int64(String(message.amount)), amount >= 0 else {
            //TODO:localize
            reject("Invalid transaction amount", "The transaction amount is invalid.")
            return
        }
        let recipient = message.address.toString(bounceable: false)
        guard !message.isTestOnly else {
            //TODO:localize
            reject("Invalid recipient address", "The transaction recipient address is invalid.")
            return
        }
        guard let preview = request.preview,
              !preview.willFail,
              !preview.isIncomplete,
              let fee = Int64(String(preview.fees)),
              fee >= 0 else {
            //TODO:localize
            reject("Transaction preview is unavailable", "The transaction could not be safely previewed.")
            return
        }

        let applicationName = request.dApp.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let domain = request.dApp.domain?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !applicationName.isEmpty, !domain.isEmpty else {
            //TODO:localize
            reject("Invalid TON Connect app information", "The app information for this transaction is incomplete.")
            return
        }
        let iconUrl: String?
        if let value = request.dApp.iconURL,
           URL(string: value)?.scheme?.lowercased() == "https" {
            iconUrl = value
        } else {
            iconUrl = nil
        }
        let model = TonConnectTransferRequest(
            id: request.id,
            applicationName: applicationName,
            domain: domain,
            iconUrl: iconUrl,
            recipient: recipient,
            amount: amount,
            fee: fee,
            previewItems: preview.operations.map { operation in
                let kind: TonConnectTransferRequest.PreviewItem.Kind
                switch operation.kind {
                case .transfer:
                    kind = .transfer
                case .callContract:
                    kind = .callContract
                case .deployContract:
                    kind = .deployContract
                case .excess:
                    kind = .excess
                case .unknown:
                    kind = .unknown
                }

                let direction: TonConnectTransferRequest.PreviewItem.Direction?
                if let operationDirection = operation.direction {
                    switch operationDirection {
                    case .incoming:
                        direction = .incoming
                    case .outgoing:
                        direction = .outgoing
                    }
                } else {
                    direction = nil
                }

                let address = operation.address.flatMap { value -> String? in
                    guard let parsed = try? Address.parse(value) else {
                        return value
                    }
                    return parsed.toString(bounceable: false)
                }
                let amount = operation.amount.flatMap { Int64(String($0)) }
                return TonConnectTransferRequest.PreviewItem(
                    id: operation.id,
                    kind: kind,
                    direction: direction,
                    address: address,
                    amount: amount,
                    comment: operation.comment
                )
            }
        )
        guard !self.pendingTonConnectRequests.contains(where: { $0.id == model.id }) else {
            return
        }
        let shouldPresent = self.pendingTonConnectRequests.isEmpty
        self.pendingTonConnectRequests.append(.transfer(model: model, request: request))
        if shouldPresent {
            self.presentNextTonConnectRequestIfNeeded()
        }
    }

    private func rejectTonConnectTransactionRequest(
        _ request: SendTransactionRequest,
        reason: String,
        errorText: String
    ) {
        self.tonConnectPresentationPipe.putNext(.error(errorText))
        Task { @MainActor [weak self] in
            do {
                guard let kit = self?.kit else { return }
                try await kit.reject(request, reason: reason)
            } catch {
                self?.log("ton_connect_transaction_reject_failed error=\(String(describing: type(of: error)))")
            }
        }
    }

    private func rejectTonConnectConnectionRequest(
        _ request: ConnectionRequest,
        reason: String,
        errorText: String
    ) {
        self.tonConnectPresentationPipe.putNext(.error(errorText))
        Task { @MainActor [weak self] in
            do {
                guard let kit = self?.kit else { return }
                try await kit.reject(request, reason: reason)
            } catch {
                self?.log("ton_connect_request_reject_failed error=\(String(describing: type(of: error)))")
            }
        }
    }

    private func presentNextTonConnectRequestIfNeeded() {
        guard let request = self.pendingTonConnectRequests.first else {
            return
        }
        switch request {
        case let .connection(model, _):
            self.tonConnectPresentationPipe.putNext(.request(model))
        case let .transfer(model, _):
            self.tonConnectPresentationPipe.putNext(.transfer(model))
        }
    }

    private func completeTonConnectRequest(id: String) {
        guard let index = self.pendingTonConnectRequests.firstIndex(where: { $0.id == id }) else {
            return
        }
        self.pendingTonConnectRequests.remove(at: index)
        if index == 0 {
            Queue.mainQueue().after(0.4, { [weak self] in
                self?.presentNextTonConnectRequestIfNeeded()
            })
        }
    }

    private func cancelPendingTonConnectRequests() {
        guard !self.pendingTonConnectRequests.isEmpty else {
            return
        }
        let requests = self.pendingTonConnectRequests
        self.pendingTonConnectRequests.removeAll()
        self.approvingTonConnectRequestIds.removeAll()
        if let requestId = requests.first?.id {
            self.tonConnectPresentationPipe.putNext(.dismiss(requestId: requestId))
        }
        for request in requests {
            Task { @MainActor [weak self] in
                guard let kit = self?.kit else { return }
                switch request {
                case let .connection(_, request):
                    try? await kit.reject(request, reason: "Wallet is unavailable")
                case let .transfer(_, request):
                    try? await kit.reject(request, reason: "Wallet is unavailable")
                }
            }
        }
    }

    private func processPendingTonConnectUrlIfPossible() {
        guard self.tonConnectUrlTask == nil,
              self.canUseNetworkRuntime,
              self.wallet != nil,
              let kit = self.kit,
              let url = self.pendingTonConnectUrls.first else {
            return
        }
        let generation = self.lifecycleGeneration
        self.tonConnectUrlTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                if self.lifecycleGeneration == generation {
                    self.tonConnectUrlTask = nil
                    self.processPendingTonConnectUrlIfPossible()
                }
            }
            do {
                guard let parsedURL = URL(string: url) else {
                    throw WalletError.invalidAddress
                }
                try await kit.handle(url: parsedURL)
                if self.pendingTonConnectUrls.first == url {
                    self.pendingTonConnectUrls.removeFirst()
                }
            } catch is CancellationError {
                return
            } catch {
                if self.pendingTonConnectUrls.first == url {
                    self.pendingTonConnectUrls.removeFirst()
                }
                self.log("ton_connect_url_failed error=\(String(describing: type(of: error)))")
                //TODO:localize
                let errorText = "Unable to open this TON Connect request."
                self.tonConnectPresentationPipe.putNext(.error(errorText))
            }
        }
    }

    private func environmentDidChange() {
        if !self.canUseNetworkRuntime {
            self.cancelPendingTonConnectRequests()
            self.tonConnectUrlTask?.cancel()
            self.tonConnectUrlTask = nil
            if !self.isApplicationInForeground || !self.isAccountCurrent {
                self.pendingTonConnectUrls.removeAll()
            }
            self.cancelFiatRatesRequest()
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

    private var hasWalletDataRuntimeDemand: Bool {
        return self.stateSubscriberCount > 0
            || self.currentState.activeOperation != nil
            || !self.currentState.pendingTransfers.isEmpty
    }

    private var hasTonConnectRuntimeDemand: Bool {
        return self.secretRecord != nil
    }

    private var hasRuntimeDemand: Bool {
        return self.hasWalletDataRuntimeDemand || self.hasTonConnectRuntimeDemand
    }

    private func evaluateRuntimeDemand() {
        guard self.canUseNetworkRuntime, self.hasRuntimeDemand else {
            self.releaseRuntimeIfPossible()
            return
        }
        if self.hasWalletDataRuntimeDemand {
            self.requestFiatRatesIfNeeded()
        } else {
            self.stopWalletDataRuntime()
        }
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
                    if self.hasWalletDataRuntimeDemand {
                        self.synchronizationRequested = true
                        self.requestSynchronization()
                        self.startPendingPollingIfNeeded()
                    }
                    self.processPendingTonConnectUrlIfPossible()
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
            if self.hasWalletDataRuntimeDemand {
                self.requestSynchronization()
                self.startPendingPollingIfNeeded()
            }
            self.processPendingTonConnectUrlIfPossible()
        }
    }

    private func stopWalletDataRuntime() {
        self.cancelFiatRatesRequest()
        self.synchronizationRequested = true
        self.synchronizationTask?.cancel()
        self.synchronizationTask = nil
        if self.wallet != nil {
            self.retryTask?.cancel()
            self.retryTask = nil
            self.retryAttempt = 0
        }
        self.pendingPollTask?.cancel()
        self.pendingPollTask = nil
        self.streamSnapshotTask?.cancel()
        self.streamSnapshotTask = nil
        self.stopStreaming()
    }

    private func releaseRuntimeIfPossible() {
        guard self.currentState.activeOperation == nil else {
            return
        }
        if !self.canUseNetworkRuntime || !self.hasRuntimeDemand {
            self.cancelFiatRatesRequest()
            self.lifecycleGeneration &+= 1
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
            self.tonConnectUrlTask?.cancel()
            self.tonConnectUrlTask = nil
            self.wallet = nil
            if let kit = self.kit {
                Task { await kit.stop() }
            }
            self.kit = nil
            self.toncenterClient = nil
            self.tonConnectEventsTask?.cancel()
            self.tonConnectEventsTask = nil
        }
    }

    private func requestFiatRatesIfNeeded() {
        assert(Queue.mainQueue().isCurrent())
        guard self.canUseNetworkRuntime, self.hasWalletDataRuntimeDemand, !self.fiatRatesRequestInProgress else {
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

        self.fiatRatesRequestGeneration &+= 1
        let generation = self.fiatRatesRequestGeneration
        self.fiatRatesRequestInProgress = true
        self.fiatRatesRequestDisposable.set((combineLatest(
            self.engine.payments.currencyRates(),
            self.engine.data.get(TelegramEngine.EngineData.Item.Configuration.App())
        )
        |> deliverOnMainQueue).start(next: { [weak self] currencyRates, appConfiguration in
            guard let self, self.fiatRatesRequestGeneration == generation else {
                return
            }
            self.fiatRatesRequestInProgress = false
            guard let currencyRates else {
                self.updateFiatRatesFailure(.network)
                return
            }
            guard let tonUsdRate = appConfiguration.data?["ton_usd_rate"] as? Double,
                  tonUsdRate.isFinite,
                  tonUsdRate > 0.0 else {
                self.updateFiatRatesFailure(.invalidData)
                return
            }

            let supportedCurrencyCodes = Set(FiatCurrency.allCases.map(\.rawValue))
            var ratesByCurrency: [String: Double] = [:]
            for currencyRate in currencyRates {
                guard supportedCurrencyCodes.contains(currencyRate.currency) else {
                    continue
                }
                guard ratesByCurrency[currencyRate.currency] == nil,
                      currencyRate.rate.isFinite,
                      currencyRate.rate > 0.0 else {
                    self.updateFiatRatesFailure(.invalidData)
                    return
                }
                ratesByCurrency[currencyRate.currency] = currencyRate.rate
            }

            var result: [FiatCurrency: FiatRate] = [:]
            for currency in FiatCurrency.allCases {
                guard let unitsPerUsd = ratesByCurrency[currency.rawValue] else {
                    self.updateFiatRatesFailure(.invalidData)
                    return
                }
                let unitsPerGram = unitsPerUsd * tonUsdRate
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
        }))
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
        guard self.canUseNetworkRuntime, self.hasWalletDataRuntimeDemand else {
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
        self.fiatRatesRequestInProgress = false
        self.fiatRatesRequestDisposable.set(nil)
        self.fiatRatesRefreshTask?.cancel()
        self.fiatRatesRefreshTask = nil
    }

    private func initializedKit() async throws -> TonWalletKit {
        guard self.canUseNetworkRuntime else {
            throw WalletError.unavailable
        }
        if let kit = self.kit {
            return kit
        }
        let generation = self.lifecycleGeneration
        try await self.tonConnectStorage.resetLegacyStorage()
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let advertisedFeatures: [Feature] = [
            .sendTransaction(maxMessages: 1, extraCurrency: false)
        ]
        let configuration = WalletKitConfiguration(
            deviceInfo: DeviceInfo(
                platform: "iphone",
                appName: "Telegram",
                appVersion: appVersion,
                features: advertisedFeatures
            ),
            advertisedFeatures: advertisedFeatures,
            defaultBridgeURL: URL(string: "https://connect.ton.org/bridge")!,
            transferValidityWindow: 300,
            emulateBeforeApproval: true
        )
        let client = ToncenterClient(network: .mainnet, apiKey: walletApiKey, timeout: 30.0)
        let kit = TonWalletKit(
            configuration: configuration,
            storage: self.tonConnectStorage,
            clients: [.mainnet: client],
            streamingAPIKey: walletApiKey
        )
        let events = await kit.eventStream()
        guard self.canUseNetworkRuntime, self.lifecycleGeneration == generation else {
            throw WalletError.unavailable
        }
        self.kit = kit
        self.toncenterClient = client
        self.tonConnectEventsTask?.cancel()
        self.tonConnectEventsTask = Task { @MainActor [weak self] in
            for await event in events {
                guard let self else { return }
                self.handleTonConnectEvent(event)
            }
        }
        return kit
    }

    private func initializedWallet() async throws -> Wallet {
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
        let task: Task<Wallet, Error> = Task { @MainActor [weak self] in
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

    private func restoreWallet(generation: Int) async throws -> Wallet {
        guard self.canUseNetworkRuntime, self.lifecycleGeneration == generation else {
            throw WalletError.unavailable
        }
        guard let secret = self.secretRecord, let metadata = self.metadataRecord else {
            throw WalletError.noWallet
        }
        guard secret.schemaVersion == 1, metadata.schemaVersion == 1 else {
            throw WalletError.storage(.unsupportedVersion)
        }
        guard secret.network == Network.mainnet.chainId else {
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
        let signer = try InMemorySigner(mnemonic: words)
        let wallet: Wallet
        let workchain: Int8
        if let value = secret.workchain {
            guard let converted = Int8(exactly: value) else {
                throw WalletError.storage(.corrupted)
            }
            workchain = converted
        } else {
            workchain = 0
        }
        let walletID: UInt32?
        if let value = secret.walletId {
            guard let converted = UInt32(exactly: value) else {
                throw WalletError.storage(.corrupted)
            }
            walletID = converted
        } else {
            walletID = nil
        }
        switch secret.walletVersion {
        case .v4R2:
            if let walletID {
                wallet = try Wallet(
                    v4r2: signer,
                    network: .mainnet,
                    walletID: walletID,
                    workchain: workchain
                )
            } else {
                wallet = try Wallet(v4r2: signer, network: .mainnet, workchain: workchain)
            }
        case .v5R1:
            if let walletID {
                wallet = try Wallet(
                    v5r1: signer,
                    network: .mainnet,
                    walletID: walletID,
                    workchain: workchain
                )
            } else {
                wallet = try Wallet(v5r1: signer, network: .mainnet, workchain: workchain)
            }
        }
        guard self.canUseNetworkRuntime,
              self.lifecycleGeneration == generation,
              self.secretRecord?.address == secret.address else {
            throw WalletError.unavailable
        }
        guard wallet.address.toString(bounceable: false) == secret.address,
              wallet.publicKey.hexString == secret.publicKey else {
            throw WalletError.storage(.identityMismatch)
        }
        await kit.register(wallet: wallet)
        guard self.canUseNetworkRuntime,
              self.lifecycleGeneration == generation,
              self.secretRecord?.address == secret.address,
              let currentMetadata = self.metadataRecord else {
            await kit.forget(walletID: wallet.id)
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
        wallet: Wallet,
        kit: TonWalletKit
    ) async throws -> ImportCandidate {
        let address = wallet.address.toString(bounceable: false)
        try Task.checkCancellation()
        guard self.canUseNetworkRuntime else {
            throw WalletError.unavailable
        }
        await kit.register(wallet: wallet)
        var balance: Int64?
        var isActive: Bool?
        do {
            guard let client = self.toncenterClient else {
                throw WalletError.unavailable
            }
            let accountState = try await client.getAccountState(address: address)
            balance = Int64(String(accountState.nanoton))
            isActive = accountState.status != .nonExisting || (balance ?? 0) != 0
        } catch {
            balance = nil
            isActive = nil
        }
        do {
            try Task.checkCancellation()
        } catch {
            await kit.forget(walletID: wallet.id)
            throw error
        }
        guard self.canUseNetworkRuntime else {
            await kit.forget(walletID: wallet.id)
            throw WalletError.unavailable
        }
        await kit.forget(walletID: wallet.id)
        return ImportCandidate(version: version, address: address, balance: balance, isActive: isActive)
    }

    private func resolvedWalletCollectibles(
        from nfts: [NFTItem],
        previousItems: [Collectible]
    ) async throws -> [Collectible] {
        var result: [Collectible] = []
        var indexByAddress: [String: Int] = [:]
        var receivedAtByAddress: [String: Int32] = [:]
        result.reserveCapacity(nfts.count)

        for collectible in previousItems {
            guard let receivedAt = collectible.receivedAt,
                  receivedAt > 0 else {
                continue
            }
            let address = (try? Address.parse(collectible.address).rawString) ?? collectible.address
            receivedAtByAddress[address] = receivedAt
        }
        for transaction in self.currentState.transactions.items
        where transaction.direction == .incoming {
            guard let collectible = transaction.collectible else { continue }
            let address = (try? Address.parse(collectible.address).rawString) ?? collectible.address
            receivedAtByAddress[address] = max(receivedAtByAddress[address] ?? 0, transaction.timestamp)
        }

        for nft in nfts {
            try Task.checkCancellation()

            let address = nft.address
            let rawAddress = (try? Address.parse(address).rawString) ?? address
            var metadata = walletCollectibleMetadata(from: nft)
            if let cachedMetadata = self.collectibleMetadataCache[rawAddress] {
                metadata.merge(cachedMetadata)
            }
            if walletCollectibleNeedsRemoteMetadata(from: nft, metadata: metadata),
               let metadataUrl = walletCollectibleMetadataUrl(from: nft) {
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
            if metadata.name != nil
                || metadata.description != nil
                || metadata.imageUrl != nil
                || metadata.lottieUrl != nil
                || metadata.collectionName != nil
                || metadata.collectionUrl != nil
                || !metadata.attributes.isEmpty {
                self.collectibleMetadataCache[rawAddress] = metadata
            }

            let collectible = walletCollectible(
                from: nft,
                metadata: metadata,
                receivedAt: receivedAtByAddress[rawAddress]
            )
            if let existingIndex = indexByAddress[rawAddress] {
                result[existingIndex] = collectible
            } else {
                indexByAddress[rawAddress] = result.count
                result.append(collectible)
            }
        }
        return result
    }

    private func resolvedWalletActionCollectibles(
        addresses: [String],
        client: ToncenterClient
    ) async throws -> [String: Transaction.CollectibleTransfer] {
        guard !addresses.isEmpty else { return [:] }
        let nfts = (try await client.getNFTs(addresses: addresses)).nfts
        var result: [String: Transaction.CollectibleTransfer] = [:]
        for nft in nfts {
            try Task.checkCancellation()
            let rawAddress = (try? Address.parse(nft.address).rawString.lowercased()) ?? nft.address.lowercased()
            var metadata = walletCollectibleMetadata(from: nft)
            if let cached = self.collectibleMetadataCache[rawAddress] {
                metadata.merge(cached)
            }
            if walletCollectibleNeedsRemoteMetadata(from: nft, metadata: metadata),
               let url = walletCollectibleMetadataUrl(from: nft),
               let remote = try? await walletCollectibleMetadata(from: url) {
                metadata.merge(remote)
            }
            self.collectibleMetadataCache[rawAddress] = metadata
            let collectible = walletCollectible(from: nft, metadata: metadata)
            let kind: Transaction.CollectibleTransfer.Kind
            switch collectible.kind {
            case .gift: kind = .gift
            case .username: kind = .username
            case .anonymousNumber: kind = .anonymousNumber
            case .other: kind = .other
            }
            result[rawAddress] = Transaction.CollectibleTransfer(
                address: collectible.address,
                name: collectible.name,
                imageUrl: collectible.imageUrl,
                lottieUrl: collectible.lottieUrl,
                collectionName: collectible.collectionName,
                collectionUrl: collectible.collectionUrl,
                kind: kind
            )
        }
        return result
    }

    private func resolvedCounterpartyNames(
        in transactions: [Transaction],
        client: ToncenterClient
    ) async -> [Transaction] {
        var names: [String: String] = [:]
        let unresolved = transactions.compactMap { transaction in
            transaction.counterpartyName == nil ? transaction.counterparty : nil
        }
        for address in Set(unresolved) {
            if let name = try? await client.reverseResolveDNS(address: address), !name.isEmpty {
                names[address] = name
            }
        }
        guard !names.isEmpty else { return transactions }
        return transactions.map { transaction in
            Transaction(
                id: transaction.id,
                transactionHash: transaction.transactionHash,
                externalMessageHash: transaction.externalMessageHash,
                logicalTime: transaction.logicalTime,
                timestamp: transaction.timestamp,
                direction: transaction.direction,
                amount: transaction.amount,
                fee: transaction.fee,
                counterparty: transaction.counterparty,
                counterpartyName: transaction.counterpartyName
                    ?? transaction.counterparty.flatMap { names[$0] },
                comment: transaction.comment,
                currency: transaction.currency,
                collectible: transaction.collectible,
                status: transaction.status
            )
        }
    }

    private func resolveUsdtJettonWalletAddressIfNeeded(wallet: Wallet) async {
        guard self.usdtJettonWalletRawAddress == nil else {
            return
        }
        let generation = self.lifecycleGeneration
        do {
            guard let kit = self.kit else { return }
            let address = try await kit.jettonWalletAddress(
                walletID: wallet.id,
                jettonMaster: walletUsdtJettonMasterAddress
            )
            try Task.checkCancellation()
            guard self.canUseNetworkRuntime,
                  self.lifecycleGeneration == generation,
                  self.wallet?.address == wallet.address else {
                return
            }
            self.usdtJettonWalletRawAddress = address.rawString
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
              self.hasWalletDataRuntimeDemand,
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
                guard let kit = self.kit else {
                    throw WalletError.unavailable
                }
                let balance = try await kit.balance(of: wallet.id)
                try Task.checkCancellation()
                guard self.lifecycleGeneration == lifecycleGeneration,
                      self.secretRecord != nil,
                      self.wallet?.address == wallet.address else {
                    return
                }
                guard let value = Int64(String(balance)) else {
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
                      self.wallet?.address == wallet.address else {
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
                guard let client = self.toncenterClient else {
                    throw WalletError.unavailable
                }
                let response = try await client.getTracesPage(
                    account: wallet.address.toString(),
                    limit: walletTransactionFetchLimit,
                    offset: 0
                )
                try Task.checkCancellation()
                guard self.lifecycleGeneration == lifecycleGeneration,
                      self.secretRecord != nil,
                      self.wallet?.address == wallet.address else {
                    return
                }
                await self.resolveUsdtJettonWalletAddressIfNeeded(wallet: wallet)
                try Task.checkCancellation()
                guard self.lifecycleGeneration == lifecycleGeneration,
                      self.secretRecord != nil,
                      self.wallet?.address == wallet.address else {
                    return
                }
                let activities = try WalletActivityExtractor.activities(
                    from: response,
                    walletAddress: wallet.address
                )
                let collectibleMetadata = try await self.resolvedWalletActionCollectibles(
                    addresses: collectibleAddresses(in: activities),
                    client: client
                )
                let decodedTransactions = try walletTransactions(
                    from: activities,
                    usdtJettonWalletAddress: self.usdtJettonWalletRawAddress,
                    collectibles: collectibleMetadata
                )
                let transactions = await self.resolvedCounterpartyNames(
                    in: decodedTransactions,
                    client: client
                )
                let authoritativeExisting = self.transactionsByReconcilingStreamOverlays(
                    in: self.currentState.transactions.items,
                    traceIDs: Set(response.traces.flatMap { trace in
                        [trace.traceID, trace.externalHash].compactMap { $0 }.map(transactionTraceKey)
                    })
                )
                let merged = mergeTransactions(existing: authoritativeExisting, new: transactions)
                let state = TransactionsState(
                    items: merged,
                    offset: max(self.currentState.transactions.offset, response.traces.count),
                    canLoadMore: response.traces.count == walletTransactionFetchLimit || self.currentState.transactions.canLoadMore,
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
                      self.wallet?.address == wallet.address else {
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
                guard let kit = self.kit else {
                    throw WalletError.unavailable
                }
                let nfts = try await kit.nfts(of: wallet.id, limit: refreshLimit, offset: 0)
                try Task.checkCancellation()
                guard self.lifecycleGeneration == lifecycleGeneration,
                      self.secretRecord != nil,
                      self.wallet?.address == wallet.address else {
                    return
                }
                let items = try await self.resolvedWalletCollectibles(
                    from: nfts,
                    previousItems: self.currentState.collectibles.items
                )
                try Task.checkCancellation()
                guard self.lifecycleGeneration == lifecycleGeneration,
                      self.secretRecord != nil,
                      self.wallet?.address == wallet.address else {
                    return
                }
                let state = CollectiblesState(
                    items: items,
                    offset: nfts.count,
                    canLoadMore: nfts.count == refreshLimit,
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
                      self.wallet?.address == wallet.address else {
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
              self.canUseNetworkRuntime else {
            return
        }
        self.pendingPollTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            while true {
                let now = Int64(currentTimestamp())
                guard self.canUseNetworkRuntime,
                      !self.currentState.pendingTransfers.isEmpty else {
                    break
                }

                if self.synchronizationTask == nil,
                   !self.synchronizationRequested,
                   self.currentState.pendingTransfers.contains(where: {
                       Int64($0.createdAt) + walletPendingTransferLifetime <= now
                   }) {
                    let pendingTransfers = self.expirePendingTransfers(at: now)
                    self.replaceState(
                        phase: self.currentState.phase,
                        balance: self.currentState.balance,
                        transactions: self.currentState.transactions,
                        pendingTransfers: pendingTransfers,
                        activeOperation: self.currentState.activeOperation
                    )
                    if pendingTransfers.isEmpty {
                        break
                    }
                }

                self.synchronizationRequested = true
                self.requestSynchronization()

                let delay: UInt64 = self.currentState.pendingTransfers.contains(where: {
                    now - Int64($0.createdAt) < 60
                }) ? 5 : 15
                do {
                    try await Task.sleep(nanoseconds: delay * 1_000_000_000)
                } catch {
                    return
                }
                guard self.canUseNetworkRuntime,
                      !self.currentState.pendingTransfers.isEmpty else {
                    break
                }
            }
            self.pendingPollTask = nil
            self.releaseRuntimeIfPossible()
        }
    }

    private func startStreamingIfNeeded() {
        guard self.streamingTask == nil,
              self.streamRetryTask == nil,
              self.canUseNetworkRuntime,
              self.hasWalletDataRuntimeDemand,
              let kit = self.kit,
              let wallet = self.wallet else {
            return
        }
        let generation = self.lifecycleGeneration
        self.streamingTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                let updates = try await kit.updates(for: wallet.id)
                for await event in updates {
                    guard self.lifecycleGeneration == generation,
                          self.canUseNetworkRuntime,
                          self.hasWalletDataRuntimeDemand,
                          self.wallet?.address == wallet.address else {
                        break
                    }
                    switch event {
                    case let .balance(update):
                        guard update.address == wallet.address,
                              let balance = Int64(String(update.balance)) else { continue }
                        let updatedAt = currentTimestamp()
                        self.balanceLastSuccessfulAt = updatedAt
                        self.replaceState(
                            phase: self.currentState.phase,
                            balance: .value(balance, updatedAt: updatedAt),
                            transactions: self.currentState.transactions,
                            pendingTransfers: self.currentState.pendingTransfers,
                            activeOperation: self.currentState.activeOperation
                        )
                    case let .transactions(update):
                        guard update.address == wallet.address else { continue }
                        let traceKey = transactionTraceKey(update.traceHash)
                        if let current = self.streamTransactionOverlaysByTrace[traceKey],
                           update.finality < current.status {
                            continue
                        }
                        if update.isInvalidated {
                            if self.currentState.pendingTransfers.contains(where: {
                                normalizedMessageHashesEqual($0.normalizedHash, update.traceHash)
                                    || ($0.status == .broadcasting && $0.normalizedHash == nil)
                            }) {
                                self.invalidatedStreamTraceHashes.insert(update.traceHash.lowercased())
                            }
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
                                pendingTransfers: self.invalidatePendingTransfer(
                                    normalizedHash: update.traceHash
                                ),
                                activeOperation: self.currentState.activeOperation
                            )
                            self.scheduleCoalescedStreamSnapshot()
                            continue
                        }
                        do {
                            let activities = try WalletActivityExtractor.activities(
                                from: update.transactions,
                                traceID: update.traceHash,
                                externalMessageHash: update.traceHash,
                                walletAddress: wallet.address,
                                status: update.finality == .pending ? .pending : .completed
                            )
                            let transactions = try walletTransactions(
                                from: activities,
                                usdtJettonWalletAddress: self.usdtJettonWalletRawAddress,
                                collectibles: [:]
                            )
                            let keys = Set(transactions.map(transactionBlockchainKey))
                            let existingItems = self.transactionsByRemovingStreamOverlay(
                                for: traceKey,
                                from: self.currentState.transactions.items
                            )
                            self.streamTransactionOverlaysByTrace[traceKey] = StreamTransactionOverlay(
                                status: update.finality,
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
                                pendingTransfers: update.finality == .pending
                                    ? self.currentState.pendingTransfers
                                    : self.confirmPendingTransfers(with: transactions),
                                activeOperation: self.currentState.activeOperation
                            )
                            self.scheduleCoalescedStreamSnapshot()
                        } catch {
                            self.logSynchronizationFailure(scope: "transactions_stream_decode", error: error)
                            self.scheduleCoalescedStreamSnapshot()
                        }
                    case .jettons:
                        self.scheduleCoalescedStreamSnapshot()
                    case let .connectionChanged(isConnected):
                        self.isStreamingConnected = isConnected
                        if isConnected {
                            self.streamRetryAttempt = 0
                            self.streamRetryTask?.cancel()
                            self.streamRetryTask = nil
                            self.startPendingPollingIfNeeded()
                            self.scheduleCoalescedStreamSnapshot()
                        } else {
                            self.startPendingPollingIfNeeded()
                        }
                    }
                }
            } catch {
                guard self.lifecycleGeneration == generation else {
                    return
                }
                self.logSynchronizationFailure(scope: "stream_start", error: error)
            }
            guard self.lifecycleGeneration == generation else { return }
            self.streamingTask = nil
            self.streamingDidDisconnect()
        }
    }

    private func transactionsByRemovingStreamOverlay(
        for traceKey: String,
        from transactions: [Transaction]
    ) -> [Transaction] {
        guard let overlay = self.streamTransactionOverlaysByTrace.removeValue(forKey: traceKey) else {
            return transactions
        }
        return transactions.filter { !overlay.transactionKeys.contains(transactionBlockchainKey($0)) }
    }

    private func transactionsByReconcilingStreamOverlays(
        in existing: [Transaction],
        traceIDs: Set<String>
    ) -> [Transaction] {
        var removableKeys = Set<String>()
        for traceKey in traceIDs {
            guard let overlay = self.streamTransactionOverlaysByTrace.removeValue(forKey: traceKey) else { continue }
            removableKeys.formUnion(overlay.transactionKeys)
        }
        guard !removableKeys.isEmpty else {
            return existing
        }
        return existing.filter { !removableKeys.contains(transactionBlockchainKey($0)) }
    }

    private func streamingDidDisconnect() {
        self.isStreamingConnected = false
        self.synchronizationRequested = true
        self.requestSynchronization()
        self.scheduleStreamRetry()
        self.startPendingPollingIfNeeded()
    }

    private func stopStreaming() {
        self.isStreamingConnected = false
        self.streamRetryTask?.cancel()
        self.streamRetryTask = nil
        self.streamingTask?.cancel()
        self.streamingTask = nil
        if let kit = self.kit {
            Task { await kit.stopStreaming() }
        }
        self.streamSnapshotTask?.cancel()
        self.streamSnapshotTask = nil
    }

    private func scheduleStreamRetry() {
        guard self.streamRetryTask == nil,
              self.canUseNetworkRuntime,
              self.hasWalletDataRuntimeDemand else {
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
        var confirmedCollectible = false
        metadata.pendingTransfers.removeAll { pending in
            let matches = transactions.contains { transaction in
                self.transaction(transaction, confirms: pending)
            }
            if matches, pending.collectibleAddress != nil {
                confirmedCollectible = true
            }
            return matches
        }
        if metadata.pendingTransfers != original {
            self.metadataRecord = metadata
            try? self.vault.writeMetadata(metadata)
            if confirmedCollectible {
                self.synchronizationRequested = true
            }
        }
        return metadata.pendingTransfers
    }

    private func transaction(_ transaction: Transaction, confirms pending: PendingTransfer) -> Bool {
        guard transaction.status == .completed,
              transaction.direction == .outgoing,
              walletAddressesEqual(transaction.counterparty, pending.recipient) else {
            return false
        }

        if let normalizedHash = pending.normalizedHash {
            guard normalizedMessageHashesEqual(transaction.externalMessageHash, normalizedHash) else {
                return false
            }
        } else {
            guard abs(Int64(transaction.timestamp) - Int64(pending.createdAt)) <= walletPendingTransferLifetime,
                  transaction.comment == pending.comment else {
                return false
            }
        }

        if let collectibleAddress = pending.collectibleAddress {
            return walletAddressesEqual(transaction.collectible?.address, collectibleAddress)
        } else {
            return transaction.collectible == nil && transaction.amount == pending.amount
        }
    }

    private func invalidatePendingTransfer(normalizedHash: String) -> [PendingTransfer] {
        guard var metadata = self.metadataRecord else {
            return self.currentState.pendingTransfers
        }
        let original = metadata.pendingTransfers
        metadata.pendingTransfers.removeAll {
            normalizedMessageHashesEqual($0.normalizedHash, normalizedHash)
        }
        if metadata.pendingTransfers != original {
            self.metadataRecord = metadata
            try? self.vault.writeMetadata(metadata)
            self.synchronizationRequested = true
        }
        return metadata.pendingTransfers
    }

    private func expirePendingTransfers(at timestamp: Int64) -> [PendingTransfer] {
        guard var metadata = self.metadataRecord else {
            return self.currentState.pendingTransfers
        }
        let original = metadata.pendingTransfers
        metadata.pendingTransfers.removeAll {
            Int64($0.createdAt) + walletPendingTransferLifetime <= timestamp
        }
        if metadata.pendingTransfers != original {
            self.metadataRecord = metadata
            try? self.vault.writeMetadata(metadata)
            self.log("event=pending_transfer_expired count=\(original.count - metadata.pendingTransfers.count)")
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
            self.updateCachedMetadata(from: state)
            self.statePromise.set(state)
        }
    }

    private func updateCachedMetadata(from state: State) {
        guard var metadata = self.metadataRecord, metadata.schemaVersion == 1 else {
            return
        }
        metadata.balance = state.balance.currentValue
        metadata.balanceUpdatedAt = state.balance.lastSuccessfulAt ?? self.balanceLastSuccessfulAt
        metadata.fiatRates = state.fiat.rates.currentValue
        metadata.fiatRatesUpdatedAt = state.fiat.rates.lastSuccessfulAt ?? self.fiatRatesLastSuccessfulAt
        metadata.selectedFiatCurrency = state.fiat.selectedCurrency
        metadata.transactions = Array(state.transactions.items.prefix(walletMetadataCachedItemLimit))
        metadata.collectibles = Array(state.collectibles.items.prefix(walletMetadataCachedItemLimit))
        guard metadata != self.metadataRecord else {
            return
        }
        do {
            try self.vault.writeMetadata(metadata)
            self.metadataRecord = metadata
        } catch {
            self.log("event=metadata_cache_write_failed errorType=\(String(reflecting: type(of: error)))")
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

private func walletAddressesEqual(_ lhs: String?, _ rhs: String?) -> Bool {
    guard let lhs, let rhs else {
        return false
    }
    if let lhs = try? Address.parse(lhs), let rhs = try? Address.parse(rhs) {
        return lhs == rhs
    }
    return lhs == rhs
}

private func normalizedMessageHashesEqual(_ lhs: String?, _ rhs: String?) -> Bool {
    guard let lhs, let rhs else {
        return false
    }
    return lhs.lowercased() == rhs.lowercased()
}

private func synchronizationError(_ error: Error) -> WalletContext.SynchronizationError {
    if error is WalletDataError || error is WalletActivityError {
        return .invalidData
    }
    if let error = error as? WalletContext.WalletError {
        switch error {
        case .unavailable:
            return .unavailable
        case .network:
            return .network
        case .sdk:
            return .sdk
        default:
            return .sdk
        }
    }
    if let error = error as? ToncenterError {
        switch error {
        case let .clientError(status, _), let .serverError(status, _):
            return .http(statusCode: status)
        case .rateLimited:
            return .http(statusCode: 429)
        case .decodingFailed, .unexpectedResponse, .addressNormalizationFailed, .invalidURL:
            return .invalidData
        case .nonHTTPResponse, .retriesExhausted:
            return .network
        }
    }
    if let error = error as? WalletKitError {
        switch error {
        case let .chainFailure(underlying), let .bridgeFailure(underlying),
             let .manifestFetchFailed(_, underlying?):
            return synchronizationError(underlying)
        case .manifestFetchFailed:
            return .network
        case .validationFailed, .tooManyMessages, .contractFailure, .cryptoFailure:
            return .invalidData
        case .storageFailure, .notInitialized, .noNetworkConfigured, .walletNotFound,
             .walletAlreadyExists, .noWalletSelected, .walletNetworkMismatch,
             .requestNotFound, .requestExpired, .requestAlreadyHandled, .unsupportedMethod,
             .sessionNotFound, .manifestInvalid, .userRejected:
            return .sdk
        }
    }
    if let error = error as? URLError {
        if error.code == .timedOut {
            return .timeout
        }
        return .network
    }
    return .sdk
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

    if let error = error as? ToncenterError {
        switch error {
        case .clientError: return "toncenter_client_error"
        case .serverError: return "toncenter_server_error"
        case .rateLimited: return "toncenter_rate_limited"
        case .decodingFailed: return "toncenter_decoding_failed"
        case .invalidURL: return "toncenter_invalid_url"
        case .nonHTTPResponse: return "toncenter_non_http_response"
        case .retriesExhausted: return "toncenter_retries_exhausted"
        case .unexpectedResponse: return "toncenter_unexpected_response"
        case .addressNormalizationFailed: return "toncenter_invalid_address"
        }
    }
    return nil
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
