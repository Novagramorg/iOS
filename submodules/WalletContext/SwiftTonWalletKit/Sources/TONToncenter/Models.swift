import Foundation
import TONCore

/// Which chain a client talks to.
public struct Network: Hashable, Sendable {
    /// TON's `global_id`, as a string to match the reference's `chainId`.
    public let chainId: String

    public init(chainId: String) {
        self.chainId = chainId
    }

    public static let mainnet = Network(chainId: "-239")
    public static let testnet = Network(chainId: "-3")

    public var isTestnet: Bool { self != .mainnet }

    /// Default Toncenter endpoint for this network.
    public var defaultEndpoint: URL {
        self == .mainnet
            ? URL(string: "https://toncenter.com")!
            : URL(string: "https://testnet.toncenter.com")!
    }
}

/// On-chain lifecycle state of an account.
public enum AccountStatus: String, Sendable, Codable {
    case active
    /// Has a balance but no code yet.
    ///
    /// Also what `addressInformation` reports for an address the chain has never seen —
    /// the endpoint does not distinguish "never existed" from "exists without code".
    case uninitialized = "uninit"
    /// No record on chain at all.
    ///
    /// The batched `accountStates` endpoint omits such addresses from its response
    /// rather than labelling them, so this value is synthesized by the mapper to keep the
    /// "an entry for every requested address" guarantee.
    case nonExisting = "non-existing"
    case frozen

    /// Toncenter spells the uninitialized state several ways across endpoints.
    init(wire: String) {
        switch wire.lowercased() {
        case "active": self = .active
        case "uninit", "uninitialized": self = .uninitialized
        case "frozen": self = .frozen
        case "nonexist", "non-existing", "non_exist", "": self = .nonExisting
        default: self = .nonExisting
        }
    }
}

/// A pointer to the last transaction that touched an account.
public struct TransactionID: Hashable, Sendable {
    /// Logical time, as a string because it exceeds 2^53 and JSON numbers would lose it.
    public let logicalTime: String
    /// `0x`-prefixed hex.
    public let hash: String

    public init(logicalTime: String, hash: String) {
        self.logicalTime = logicalTime
        self.hash = hash
    }
}

/// Everything the chain knows about an account.
public struct AccountState: Sendable {
    /// Friendly, bounceable, URL-safe form — the canonical key everywhere in this layer.
    public let address: String
    public let status: AccountStatus
    /// Nanoton, as a decimal string.
    public let rawBalance: String
    /// TON, as a decimal string.
    public let balance: String
    public let extraCurrencies: [String: String]
    /// Base64 BoC, absent for accounts that hold no code.
    public let code: String?
    public let data: String?
    public let lastTransaction: TransactionID?

    public init(
        address: String,
        status: AccountStatus,
        rawBalance: String,
        balance: String,
        extraCurrencies: [String: String] = [:],
        code: String? = nil,
        data: String? = nil,
        lastTransaction: TransactionID? = nil
    ) {
        self.address = address
        self.status = status
        self.rawBalance = rawBalance
        self.balance = balance
        self.extraCurrencies = extraCurrencies
        self.code = code
        self.data = data
        self.lastTransaction = lastTransaction
    }

    /// An account with no on-chain record.
    ///
    /// Returned rather than throwing, so batch queries can guarantee a value for every
    /// requested address.
    public static func nonExisting(address: String) -> AccountState {
        AccountState(
            address: address,
            status: .nonExisting,
            rawBalance: "0",
            balance: "0",
            extraCurrencies: [:]
        )
    }

    /// Whether the account holds code, and can therefore be sent to without a state init.
    public var isDeployed: Bool { status == .active }

    /// Balance in nanoton.
    public var nanoton: BigUInt {
        BigUInt(rawBalance) ?? 0
    }
}

/// Latest masterchain block, used as a liveness and sync check.
public struct MasterchainInfo: Sendable {
    public let workchain: Int
    public let seqno: Int
    public let shard: String
    /// `0x`-prefixed hex.
    public let rootHash: String
    public let fileHash: String

    public init(workchain: Int, seqno: Int, shard: String, rootHash: String, fileHash: String) {
        self.workchain = workchain
        self.seqno = seqno
        self.shard = shard
        self.rootHash = rootHash
        self.fileHash = fileHash
    }
}

/// Result of running a get-method.
public struct GetMethodResult: Sendable {
    public let exitCode: Int
    public let gasUsed: Int
    public let stack: [RawStackItem]

    public init(exitCode: Int, gasUsed: Int, stack: [RawStackItem]) {
        self.exitCode = exitCode
        self.gasUsed = gasUsed
        self.stack = stack
    }

    /// TVM signals success with 0, and by convention also 1.
    public var isSuccess: Bool { exitCode == 0 || exitCode == 1 }

    /// Reads the stack, throwing if the method did not succeed.
    ///
    /// Callers routinely forget to check `exitCode` and then misread a garbage stack;
    /// this makes the check unavoidable.
    public func reader() throws -> TupleReader {
        guard isSuccess else {
            throw ToncenterError.unexpectedResponse("get-method failed with exit code \(exitCode)")
        }
        return TupleReader(try parseStack(stack))
    }
}

/// Result of broadcasting a BoC.
public struct SendResult: Sendable {
    /// `0x`-prefixed hex of the message hash Toncenter reports.
    public let messageHash: String

    public init(messageHash: String) {
        self.messageHash = messageHash
    }
}
