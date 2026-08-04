import Foundation
import TONCore

/// Toncenter v3 response shapes, kept separate from the domain models so wire churn
/// stays contained.
///
/// Optionality here is deliberate and load-bearing: fields Toncenter has stopped
/// returning must decode to nil rather than fail. The reference dereferences
/// `trace_external_hash` unguarded and, since v3 no longer returns it, throws for every
/// account with any history — see `WireTransaction.traceExternalHash`.
enum Wire {
    // MARK: - Masterchain

    struct MasterchainInfoResponse: Decodable {
        let last: Block
        let first: Block?

        struct Block: Decodable {
            let workchain: Int
            let shard: String
            let seqno: Int
            let rootHash: String
            let fileHash: String

            enum CodingKeys: String, CodingKey {
                case workchain, shard, seqno
                case rootHash = "root_hash"
                case fileHash = "file_hash"
            }
        }
    }

    // MARK: - Account state

    /// `/api/v3/addressInformation`
    struct AddressInformation: Decodable {
        let balance: String
        let code: String?
        let data: String?
        let lastTransactionLt: String?
        let lastTransactionHash: String?
        let frozenHash: String?
        let status: String?
        let extraCurrencies: [String: String]?

        enum CodingKeys: String, CodingKey {
            case balance, code, data, status
            case lastTransactionLt = "last_transaction_lt"
            case lastTransactionHash = "last_transaction_hash"
            case frozenHash = "frozen_hash"
            case extraCurrencies = "extra_currencies"
        }
    }

    /// `/api/v3/accountStates`
    struct AccountStatesResponse: Decodable {
        let accounts: [Entry]
        let addressBook: [String: AddressBookEntry]?

        enum CodingKeys: String, CodingKey {
            case accounts
            case addressBook = "address_book"
        }

        struct Entry: Decodable {
            /// Raw form, uppercase hex.
            let address: String
            let balance: String
            let status: String?
            let code: String?
            let data: String?
            let codeHash: String?
            let dataHash: String?
            let lastTransactionLt: String?
            let lastTransactionHash: String?
            let frozenHash: String?
            let extraCurrencies: [String: String]?

            enum CodingKeys: String, CodingKey {
                case address, balance, status, code, data
                case codeHash = "code_hash"
                case dataHash = "data_hash"
                case lastTransactionLt = "last_transaction_lt"
                case lastTransactionHash = "last_transaction_hash"
                case frozenHash = "frozen_hash"
                case extraCurrencies = "extra_currencies"
            }
        }
    }

    struct AddressBookEntry: Decodable {
        let userFriendly: String?
        /// Reverse DNS name supplied inline by Toncenter, when one exists.
        let domain: String?

        enum CodingKeys: String, CodingKey {
            case userFriendly = "user_friendly"
            case domain
        }
    }

    // MARK: - Get-method

    /// `/api/v3/runGetMethod`
    struct RunGetMethodResponse: Decodable {
        let gasUsed: Int
        let exitCode: Int
        let stack: [RawStackItem]

        enum CodingKeys: String, CodingKey {
            case gasUsed = "gas_used"
            case exitCode = "exit_code"
            case stack
        }
    }

    // MARK: - Message send

    /// `/api/v3/message`
    struct SendMessageResponse: Decodable {
        let messageHash: String?

        enum CodingKeys: String, CodingKey {
            case messageHash = "message_hash"
        }
    }

    // MARK: - Transactions

    /// `/api/v3/transactions`
    struct TransactionsResponse: Decodable {
        let transactions: [WireTransaction]
        let addressBook: [String: AddressBookEntry]?

        enum CodingKeys: String, CodingKey {
            case transactions
            case addressBook = "address_book"
        }
    }

    struct WireTransaction: Decodable {
        let account: String
        let hash: String
        let lt: String
        let now: Int
        let mcBlockSeqno: Int?
        let traceId: String?
        let prevTransHash: String?
        let prevTransLt: String?
        let origStatus: String?
        let endStatus: String?
        let totalFees: String?
        let description: TransactionDescription?
        let inMsg: WireMessage?
        let outMsgs: [WireMessage]?

        /// **Optional on purpose.** Toncenter v3 no longer returns this field — zero
        /// occurrences across every transaction recorded on mainnet and testnet. The
        /// reference calls `Base64ToHex(tx.trace_external_hash)` unguarded and therefore
        /// throws `Invalid hash: data is required` as soon as a response carries any
        /// transaction at all, which breaks history listing for every account. One
        /// ordinary transaction is enough; it is not confined to exotic shapes.
        let traceExternalHash: String?

        enum CodingKeys: String, CodingKey {
            case account, hash, lt, now, description
            case mcBlockSeqno = "mc_block_seqno"
            case traceId = "trace_id"
            case prevTransHash = "prev_trans_hash"
            case prevTransLt = "prev_trans_lt"
            case origStatus = "orig_status"
            case endStatus = "end_status"
            case totalFees = "total_fees"
            case inMsg = "in_msg"
            case outMsgs = "out_msgs"
            case traceExternalHash = "trace_external_hash"
        }
    }

    struct TransactionDescription: Decodable {
        let type: String?
        let aborted: Bool?
        let destroyed: Bool?
        let computePhase: ComputePhase?
        let actionPhase: ActionPhase?

        enum CodingKeys: String, CodingKey {
            case type, aborted, destroyed
            case computePhase = "compute_ph"
            case actionPhase = "action"
        }

        struct ComputePhase: Decodable {
            let success: Bool?
            let exitCode: Int?
            let gasUsed: String?
            let skipped: Bool?
            /// Why the compute phase did not run: `no_state`, `bad_state`, `no_gas`.
            ///
            /// Load-bearing rather than informational. A skipped phase sets `aborted`, so
            /// without the reason every transfer to an address with no code looks failed.
            let reason: String?

            enum CodingKeys: String, CodingKey {
                case success, skipped, reason
                case exitCode = "exit_code"
                case gasUsed = "gas_used"
            }
        }

        struct ActionPhase: Decodable {
            let success: Bool?
            let resultCode: Int?

            enum CodingKeys: String, CodingKey {
                case success
                case resultCode = "result_code"
            }
        }
    }

    /// A message on a transaction.
    ///
    /// **Every field is optional.** `tick_tock` transactions — which masterchain system
    /// accounts receive — carry an `in_msg` that is an *empty object*, so a non-optional
    /// `hash` would fail to decode. The reference throws on exactly this shape.
    struct WireMessage: Decodable {
        let hash: String?
        let hashNorm: String?
        let source: String?
        let destination: String?
        let value: String?
        let fwdFee: String?
        let ihrFee: String?
        let createdLt: String?
        let createdAt: String?
        let opcode: String?
        let bounce: Bool?
        let bounced: Bool?
        let importFee: String?
        let messageContent: MessageContent?
        let initState: MessageContent?

        enum CodingKeys: String, CodingKey {
            case hash, source, destination, value, opcode, bounce, bounced
            case hashNorm = "hash_norm"
            case fwdFee = "fwd_fee"
            case ihrFee = "ihr_fee"
            case createdLt = "created_lt"
            case createdAt = "created_at"
            case importFee = "import_fee"
            case messageContent = "message_content"
            case initState = "init_state"
        }

        /// True when the object carries no fields at all — the `tick_tock` shape.
        var isEmpty: Bool {
            hash == nil && source == nil && destination == nil && value == nil
        }

        struct MessageContent: Decodable {
            let hash: String?
            let body: String?
            let decoded: Decoded?

            struct Decoded: Decodable {
                let type: String?
                let comment: String?
            }
        }
    }
}
