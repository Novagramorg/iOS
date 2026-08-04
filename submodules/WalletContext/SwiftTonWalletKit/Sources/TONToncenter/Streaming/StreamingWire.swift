import Foundation
import TONCore

/// Wire shapes for the Toncenter v2 streaming API.
///
/// Modelled from messages captured off the live testnet endpoint rather than from the schema,
/// so the optionality reflects what the server actually omits. Every field outside the
/// discriminator is optional: a notification shape that gains a field must not stop the whole
/// stream from decoding.
enum StreamWire {
    /// Reply to `subscribe`/`ping`, which carry `status` instead of `type`.
    struct Ack: Decodable {
        let id: String?
        let status: String
    }

    struct Envelope: Decodable {
        let type: String?
        let status: String?
        let finality: String?
    }

    struct AccountStateNotification: Decodable {
        struct State: Decodable {
            let hash: String?
            let balance: String?
            let accountStatus: String?

            enum CodingKeys: String, CodingKey {
                case hash, balance
                case accountStatus = "account_status"
            }
        }

        let account: String
        let state: State
        let finality: String?
    }

    struct TransactionsNotification: Decodable {
        let traceExternalHashNorm: String
        let transactions: [Wire.WireTransaction]
        let finality: String?

        enum CodingKeys: String, CodingKey {
            case transactions, finality
            case traceExternalHashNorm = "trace_external_hash_norm"
        }
    }

    struct TraceInvalidatedNotification: Decodable {
        let traceExternalHashNorm: String

        enum CodingKeys: String, CodingKey {
            case traceExternalHashNorm = "trace_external_hash_norm"
        }
    }

    struct JettonsNotification: Decodable {
        struct Jetton: Decodable {
            let address: String
            let owner: String
            let balance: String?
            let jettonWallet: String?

            enum CodingKeys: String, CodingKey {
                case address, owner, balance
                case jettonWallet = "jetton_wallet"
            }
        }

        let jetton: Jetton
        let finality: String?
    }

    /// A subscription request. One monolithic subscribe replaces the previous one, which is
    /// why the client always sends the full watched set rather than deltas.
    struct SubscribeRequest: Encodable {
        let operation = "subscribe"
        let id: String
        let types: [String]
        let addresses: [String]
        let minFinality: String
        let includeMetadata: Bool

        enum CodingKeys: String, CodingKey {
            case operation, id, types, addresses
            case minFinality = "min_finality"
            case includeMetadata = "include_metadata"
        }
    }

    struct UnsubscribeRequest: Encodable {
        let operation = "unsubscribe"
        let id: String
        let addresses: [String]
    }

    struct PingRequest: Encodable {
        let operation = "ping"
        let id: String
    }
}

// MARK: - Mapping

enum StreamMappers {
    /// Parses one raw frame into an event, or nil when it is an acknowledgement or a shape we
    /// do not model.
    ///
    /// Unknown frames are skipped rather than thrown on: the server may add notification types,
    /// and a wallet that dropped its connection over an unrecognised frame would stop receiving
    /// the ones it does understand.
    static func event(from text: String) -> StreamEvent? {
        guard let data = text.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()

        guard let envelope = try? decoder.decode(StreamWire.Envelope.self, from: data) else {
            return nil
        }
        // `subscribed` / `pong` carry no payload.
        if envelope.type == nil, envelope.status != nil { return nil }

        let finality = envelope.finality.flatMap(StreamFinality.init(rawValue:)) ?? .pending

        switch envelope.type {
        case StreamEventType.accountState.rawValue:
            guard let wire = try? decoder.decode(StreamWire.AccountStateNotification.self, from: data),
                  let address = try? Address.parse(wire.account),
                  let raw = wire.state.balance,
                  let balance = BigUInt(raw)
            else { return nil }
            return .balance(
                BalanceUpdate(
                    address: address,
                    balance: balance,
                    status: wire.state.accountStatus.flatMap(AccountStatus.init(rawValue:)) ?? .active,
                    finality: finality,
                    stateHash: wire.state.hash
                )
            )

        case StreamEventType.jettons.rawValue:
            guard let wire = try? decoder.decode(StreamWire.JettonsNotification.self, from: data),
                  let owner = try? Address.parse(wire.jetton.owner),
                  let master = try? Address.parse(wire.jetton.address)
            else { return nil }
            return .jettons(
                JettonUpdate(
                    owner: owner,
                    master: master,
                    jettonWallet: wire.jetton.jettonWallet.flatMap { try? Address.parse($0) },
                    balance: wire.jetton.balance.flatMap { BigUInt($0) } ?? 0,
                    finality: finality
                )
            )

        case "trace_invalidated":
            guard let wire = try? decoder.decode(StreamWire.TraceInvalidatedNotification.self, from: data),
                  let hash = Mappers.hexHash(fromBase64: wire.traceExternalHashNorm)
            else { return nil }
            // No address: the client resolves which watchers cared from its own trace record,
            // because the invalidation frame does not say whose trace it was.
            return .transactions(
                TransactionUpdate(
                    address: Address(workchain: 0, hash: Data(repeating: 0, count: 32)),
                    transactions: [],
                    finality: finality,
                    traceHash: hash,
                    isInvalidated: true
                )
            )

        default:
            return nil
        }
    }

    /// Transaction notifications need the watched set to split a trace per account, so they are
    /// mapped separately from ``event(from:)``.
    static func transactionUpdates(
        from text: String,
        watching: (Address) -> Bool
    ) -> [TransactionUpdate] {
        guard let data = text.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(StreamWire.Envelope.self, from: data),
              envelope.type == StreamEventType.transactions.rawValue,
              let wire = try? JSONDecoder().decode(StreamWire.TransactionsNotification.self, from: data),
              let traceHash = Mappers.hexHash(fromBase64: wire.traceExternalHashNorm)
        else { return [] }

        let finality = envelope.finality.flatMap(StreamFinality.init(rawValue:)) ?? .pending
        let mapped = wire.transactions.map(Mappers.transaction)

        // One update per watched account, carrying only that account's transactions. A trace
        // for a jetton send touches four contracts; reporting all of them to the wallet would
        // turn one transfer into four unrelated-looking events.
        var byAccount: [String: [ChainTransaction]] = [:]
        for transaction in mapped {
            byAccount[transaction.account, default: []].append(transaction)
        }

        return byAccount.compactMap { account, transactions in
            guard let address = try? Address.parse(account), watching(address) else { return nil }
            return TransactionUpdate(
                address: address,
                transactions: transactions,
                finality: finality,
                traceHash: traceHash
            )
        }
        .sorted { $0.address.rawString < $1.address.rawString }
    }

    /// Accounts named by a transactions frame, used to remember who cared about a trace so an
    /// invalidation can later be routed to them.
    static func accounts(inTransactionFrame text: String) -> [Address] {
        guard let data = text.data(using: .utf8),
              let wire = try? JSONDecoder().decode(StreamWire.TransactionsNotification.self, from: data)
        else { return [] }
        return wire.transactions.compactMap { try? Address.parse($0.account) }
    }

    static func traceHash(inFrame text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let wire = try? JSONDecoder().decode(StreamWire.TraceInvalidatedNotification.self, from: data)
        else { return nil }
        return Mappers.hexHash(fromBase64: wire.traceExternalHashNorm)
    }
}
