import Foundation
import TONCore

extension Wire {
    // MARK: - Jettons

    /// `/api/v3/jetton/wallets`
    struct JettonWalletsResponse: Decodable {
        let jettonWallets: [JettonWallet]
        let addressBook: [String: AddressBookEntry]?
        let metadata: [String: AddressMetadata]?

        enum CodingKeys: String, CodingKey {
            case jettonWallets = "jetton_wallets"
            case addressBook = "address_book"
            case metadata
        }
    }

    struct JettonWallet: Decodable {
        /// The owner's jetton wallet contract.
        let address: String
        let balance: String
        let owner: String?
        /// The jetton master.
        let jetton: String?
        let lastTransactionLt: String?
        let codeHash: String?
        let dataHash: String?

        enum CodingKeys: String, CodingKey {
            case address, balance, owner, jetton
            case lastTransactionLt = "last_transaction_lt"
            case codeHash = "code_hash"
            case dataHash = "data_hash"
        }
    }

    /// `/api/v3/jetton/masters`
    struct JettonMastersResponse: Decodable {
        let jettonMasters: [JettonMaster]
        let addressBook: [String: AddressBookEntry]?
        let metadata: [String: AddressMetadata]?

        enum CodingKeys: String, CodingKey {
            case jettonMasters = "jetton_masters"
            case addressBook = "address_book"
            case metadata
        }
    }

    struct JettonMaster: Decodable {
        let address: String
        let totalSupply: String?
        let mintable: Bool?
        let adminAddress: String?
        let jettonContent: [String: AnyCodableString]?

        enum CodingKeys: String, CodingKey {
            case address, mintable
            case totalSupply = "total_supply"
            case adminAddress = "admin_address"
            case jettonContent = "jetton_content"
        }
    }

    // MARK: - NFTs

    /// `/api/v3/nft/items`
    struct NFTItemsResponse: Decodable {
        let nftItems: [NFTItemWire]
        let addressBook: [String: AddressBookEntry]?
        let metadata: [String: AddressMetadata]?

        enum CodingKeys: String, CodingKey {
            case nftItems = "nft_items"
            case addressBook = "address_book"
            case metadata
        }
    }

    struct NFTItemWire: Decodable {
        let address: String
        let index: String?
        let `init`: Bool?
        let collectionAddress: String?
        let ownerAddress: String?
        /// Present when the item is held by a sale contract.
        let realOwner: String?
        let onSale: Bool?
        let content: [String: AnyCodableString]?
        let codeHash: String?
        let dataHash: String?

        enum CodingKeys: String, CodingKey {
            case address, index, content
            case `init`
            case collectionAddress = "collection_address"
            case ownerAddress = "owner_address"
            case realOwner = "real_owner"
            case onSale = "on_sale"
            case codeHash = "code_hash"
            case dataHash = "data_hash"
        }
    }

    // MARK: - Address metadata

    /// Toncenter's indexer annotations, keyed by raw address.
    struct AddressMetadata: Decodable {
        let isIndexed: Bool?
        let tokenInfo: [TokenInfo]?

        enum CodingKeys: String, CodingKey {
            case isIndexed = "is_indexed"
            case tokenInfo = "token_info"
        }

        struct TokenInfo: Decodable {
            let valid: Bool?
            /// `jetton_masters`, `jetton_wallets`, `nft_items`, `nft_collections`.
            let type: String?
            let name: String?
            let symbol: String?
            let description: String?
            let image: String?
            let isNSFW: Bool?
            let isScam: Bool?
            /// Free-form; carries `decimals` and `uri` for jettons.
            let extra: [String: AnyCodableString]?

            enum CodingKeys: String, CodingKey {
                case valid, type, name, symbol, description, image, extra
                case isNSFW = "is_nsfw"
                case isScam = "is_scam"
            }
        }
    }

    // MARK: - DNS

    /// `/api/v3/dns/records`
    struct DNSRecordsResponse: Decodable {
        let records: [DNSRecord]?
        let addressBook: [String: AddressBookEntry]?

        enum CodingKeys: String, CodingKey {
            case records
            case addressBook = "address_book"
        }
    }

    struct DNSRecord: Decodable {
        let nftItemAddress: String?
        let nftItemOwner: String?
        let domain: String?
        let dnsWallet: String?
        let dnsWalletAddress: String?
        let dnsNextResolver: String?
        let dnsSiteAdnl: String?

        enum CodingKeys: String, CodingKey {
            case domain
            case nftItemAddress = "nft_item_address"
            case nftItemOwner = "nft_item_owner"
            case dnsWallet = "dns_wallet"
            case dnsWalletAddress = "dns_wallet_address"
            case dnsNextResolver = "dns_next_resolver"
            case dnsSiteAdnl = "dns_site_adnl"
        }
    }
}

/// Decodes a JSON value that may be a string, number or bool into a string.
///
/// Toncenter's `extra` and `content` blocks are genuinely heterogeneous — `decimals`
/// arrives as the string `"6"` for one token and as the number `6` for another — so a
/// strict `[String: String]` would fail to decode real responses.
struct AnyCodableString: Decodable {
    let value: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = String(int)
        } else if let double = try? container.decode(Double.self) {
            value = String(double)
        } else if let bool = try? container.decode(Bool.self) {
            value = String(bool)
        } else {
            // Nested objects and arrays are not flattened; they are simply not
            // representable as a scalar and are dropped rather than failing the parse.
            value = nil
        }
    }
}

extension Dictionary where Key == String, Value == AnyCodableString {
    /// Flattens to plain strings, dropping non-scalar entries.
    var flattened: [String: String] {
        compactMapValues(\.value)
    }
}

extension Wire {
    // MARK: - Emulation

    /// `/api/emulate/v1/emulateTrace`
    ///
    /// Note the response keys transactions by hash rather than listing them, and — unlike
    /// `/api/v3/transactions` — it *does* include `trace_external_hash`.
    struct EmulateTraceResponse: Decodable {
        let mcBlockSeqno: Int?
        let trace: TraceNode?
        let transactions: [String: WireTransaction]?
        let isIncomplete: Bool?

        enum CodingKeys: String, CodingKey {
            case trace, transactions
            case mcBlockSeqno = "mc_block_seqno"
            case isIncomplete = "is_incomplete"
        }

        struct TraceNode: Decodable {
            let txHash: String?
            let children: [TraceNode]?

            enum CodingKeys: String, CodingKey {
                case txHash = "tx_hash"
                case children
            }
        }
    }
}

extension Wire {
    // MARK: - Traces

    /// `/api/v3/traces`
    struct TracesResponse: Decodable {
        let traces: [TraceWire]?
        let addressBook: [String: AddressBookEntry]?

        enum CodingKeys: String, CodingKey {
            case traces
            case addressBook = "address_book"
        }
    }

    struct TraceWire: Decodable {
        let traceId: String?
        let externalHash: String?
        let startLt: String?
        let endLt: String?
        let startUtime: Int?
        let endUtime: Int?
        let isIncomplete: Bool?
        let traceInfo: TraceInfoWire?
        let trace: TraceNodeWire?
        /// Hashes in the indexer's order. Not relied upon for ordering — the tree is.
        let transactionsOrder: [String]?
        let transactions: [String: WireTransaction]?

        enum CodingKeys: String, CodingKey {
            case trace, transactions
            case traceId = "trace_id"
            case externalHash = "external_hash"
            case startLt = "start_lt"
            case endLt = "end_lt"
            case startUtime = "start_utime"
            case endUtime = "end_utime"
            case isIncomplete = "is_incomplete"
            case traceInfo = "trace_info"
            case transactionsOrder = "transactions_order"
        }
    }

    struct TraceInfoWire: Decodable {
        let traceState: String?
        let messages: Int?
        let transactions: Int?
        let pendingMessages: Int?
        let classificationState: String?

        enum CodingKeys: String, CodingKey {
            case messages, transactions
            case traceState = "trace_state"
            case pendingMessages = "pending_messages"
            case classificationState = "classification_state"
        }
    }

    struct TraceNodeWire: Decodable {
        let txHash: String?
        let inMsgHash: String?
        let children: [TraceNodeWire]?

        enum CodingKeys: String, CodingKey {
            case children
            case txHash = "tx_hash"
            case inMsgHash = "in_msg_hash"
        }
    }
}
