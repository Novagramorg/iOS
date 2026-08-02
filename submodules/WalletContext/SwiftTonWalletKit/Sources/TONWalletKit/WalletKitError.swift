import Foundation

/// Everything the kit can fail with.
///
/// Typed rather than stringly, which is the point of the redesign: the reference collapses
/// every failure into a `WalletKitError` carrying a numeric code and a message, so callers
/// end up matching on strings to decide whether to retry, re-prompt, or give up. Here the
/// distinctions a caller acts on are in the type.
public enum WalletKitError: Error, CustomStringConvertible {
    // MARK: Setup

    case notInitialized
    case noNetworkConfigured(chainID: String)

    // MARK: Wallets

    case walletNotFound(WalletID)
    case walletAlreadyExists(WalletID)
    case noWalletSelected
    /// The wallet cannot service the request — for instance a request for a network it is
    /// not on.
    case walletNetworkMismatch(walletChainID: String, requestChainID: String)

    // MARK: Requests

    case requestNotFound(String)
    case requestExpired(validUntil: UInt64, now: UInt64)
    case requestAlreadyHandled(String)
    /// The dApp asked for something this wallet does not do.
    case unsupportedMethod(String)
    case tooManyMessages(count: Int, maximum: Int)
    case validationFailed(reason: String)

    // MARK: Sessions

    case sessionNotFound(String)
    case manifestFetchFailed(url: String, underlying: Error?)
    case manifestInvalid(reason: String)

    // MARK: Underlying layers

    case storageFailure(underlying: Error)
    case bridgeFailure(underlying: Error)
    case chainFailure(underlying: Error)
    case cryptoFailure(underlying: Error)
    case contractFailure(underlying: Error)

    /// The user declined. Not really an error, but it travels the same path as one and
    /// callers must distinguish it from a failure to avoid showing an error UI.
    case userRejected

    public var description: String {
        switch self {
        case .notInitialized:
            return "The kit has not finished initializing"
        case .noNetworkConfigured(let chainID):
            return "No API client is configured for network \(chainID)"
        case .walletNotFound(let id):
            return "No wallet with id \(id.value)"
        case .walletAlreadyExists(let id):
            return "A wallet with id \(id.value) is already present"
        case .noWalletSelected:
            return "The request needs a wallet, but none was supplied"
        case .walletNetworkMismatch(let wallet, let request):
            return "Wallet is on network \(wallet) but the request targets \(request)"
        case .requestNotFound(let id):
            return "No pending request with id \(id)"
        case .requestExpired(let validUntil, let now):
            return "Request expired at \(validUntil), now \(now)"
        case .requestAlreadyHandled(let id):
            return "Request \(id) has already been answered"
        case .unsupportedMethod(let method):
            return "This wallet does not support \(method)"
        case .tooManyMessages(let count, let maximum):
            return "Request carries \(count) messages, this wallet allows \(maximum)"
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        case .sessionNotFound(let id):
            return "No session with id \(id)"
        case .manifestFetchFailed(let url, let underlying):
            let detail = underlying.map { ": \($0)" } ?? ""
            return "Could not fetch the dApp manifest at \(url)\(detail)"
        case .manifestInvalid(let reason):
            return "The dApp manifest is invalid: \(reason)"
        case .storageFailure(let underlying):
            return "Storage failure: \(underlying)"
        case .bridgeFailure(let underlying):
            return "Bridge failure: \(underlying)"
        case .chainFailure(let underlying):
            return "Chain request failed: \(underlying)"
        case .cryptoFailure(let underlying):
            return "Cryptographic operation failed: \(underlying)"
        case .contractFailure(let underlying):
            return "Contract operation failed: \(underlying)"
        case .userRejected:
            return "The user declined the request"
        }
    }

    /// Whether retrying the same operation could plausibly succeed.
    ///
    /// Distinguishing this in the type means a caller does not have to guess from a message
    /// string whether to offer a retry.
    public var isRetryable: Bool {
        switch self {
        case .storageFailure, .bridgeFailure, .chainFailure, .manifestFetchFailed:
            return true
        case .notInitialized, .noNetworkConfigured, .walletNotFound, .walletAlreadyExists,
             .noWalletSelected, .walletNetworkMismatch, .requestNotFound, .requestExpired,
             .requestAlreadyHandled, .unsupportedMethod, .tooManyMessages, .validationFailed,
             .sessionNotFound, .manifestInvalid, .cryptoFailure, .contractFailure,
             .userRejected:
            return false
        }
    }

    /// Whether this represents a deliberate user choice rather than a fault, so the UI
    /// shows a dismissal instead of an error.
    public var isUserDecision: Bool {
        if case .userRejected = self { return true }
        return false
    }

    /// The TON Connect error code to report to the dApp.
    ///
    /// A dApp switches on these numerically, so mapping matters: telling it
    /// `UNKNOWN_ERROR` when the user simply declined leads to the wrong prompt.
    public var connectErrorCode: Int {
        switch self {
        case .userRejected: return 300
        case .unsupportedMethod: return 400
        case .validationFailed, .requestExpired, .tooManyMessages: return 1
        case .sessionNotFound, .walletNotFound, .noWalletSelected: return 100
        case .manifestFetchFailed: return 2
        case .manifestInvalid: return 3
        default: return 0
        }
    }
}

/// A stable per-network wallet identifier.
///
/// A wrapper rather than a bare `String` so a wallet id cannot be passed where an address
/// is expected — they are both strings and confusing them is a silent bug.
public struct WalletID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public var description: String { value }
}
