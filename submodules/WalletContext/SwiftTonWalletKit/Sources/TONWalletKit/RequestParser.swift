import Foundation
import TONCore
import TONCrypto
import TONConnect

/// Turns a decrypted bridge payload into a typed request.
///
/// Replaces the reference's handler chain — five `EventHandler` classes each with
/// `canHandle`/`handle`/`notify` — with a single `switch` on the method. The indirection
/// existed there to let handlers be registered dynamically for the JS bridge; with only the
/// HTTP bridge in scope there is nothing to register.
///
/// Every failure here is a *refusal*, never a fallback: a request that cannot be parsed
/// into something the user could meaningfully approve must be rejected back to the dApp.
public enum RequestParser {
    /// Why one outgoing message could not be parsed. A plain wrapper so the failure can
    /// travel in a `Result` and be folded into the dApp-facing rejection message.
    struct MessageParseError: Error {
        let reason: String
        init(_ reason: String) { self.reason = reason }
    }

    /// A parsed request, or a description of why parsing failed.
    public enum Parsed: Sendable {
        case sendTransaction(SendTransactionRequest)
        case signMessage(SignMessageRequest)
        case signData(SignDataRequest)
        case disconnect(DisconnectRequest)
        /// The dApp used a method this wallet does not implement. Distinct from malformed:
        /// the reply carries `METHOD_NOT_SUPPORTED` rather than `BAD_REQUEST`.
        case unsupported(id: String, method: String)
        case malformed(MalformedRequest)
    }

    /// Parses a decrypted payload for a known session.
    public static func parse(
        payload: Data,
        session: TONConnectSession,
        walletNetwork: String
    ) -> Parsed {
        let request: AppRequest
        do {
            request = try JSONDecoder().decode(AppRequest.self, from: payload)
        } catch {
            return .malformed(
                MalformedRequest(
                    id: "",
                    sessionID: session.id,
                    reason: "Bridge payload is not a TON Connect request: \(error)"
                )
            )
        }

        switch request.knownMethod {
        case .sendTransaction:
            return parseTransaction(request, session: session, walletNetwork: walletNetwork, signOnly: false)
        case .signMessage:
            return parseTransaction(request, session: session, walletNetwork: walletNetwork, signOnly: true)
        case .signData:
            return parseSignData(request, session: session)
        case .disconnect:
            return .disconnect(
                DisconnectRequest(id: request.id, sessionID: session.id, walletID: session.walletID, dApp: session.dApp)
            )
        case .none:
            return .unsupported(id: request.id, method: request.method)
        }
    }

    // MARK: - sendTransaction / signMessage

    private static func parseTransaction(
        _ request: AppRequest,
        session: TONConnectSession,
        walletNetwork: String,
        signOnly: Bool
    ) -> Parsed {
        func fail(_ reason: String) -> Parsed {
            .malformed(MalformedRequest(id: request.id, sessionID: session.id, reason: reason))
        }

        let params: SendTransactionParams
        do {
            params = try request.decodeFirstParam(as: SendTransactionParams.self)
        } catch {
            return fail("\(request.method) params did not decode: \(error)")
        }

        guard !params.messages.isEmpty else {
            return fail("\(request.method) carried no messages")
        }
        // A dApp naming a different chain must be refused, not silently signed on ours: the
        // same address exists on both networks and a mainnet transfer approved as testnet
        // spends real funds.
        if let network = params.network, network != walletNetwork {
            return fail("Request targets network \(network) but the wallet is on \(walletNetwork)")
        }

        var messages: [TransferMessage] = []
        for (index, message) in params.messages.enumerated() {
            switch parseMessage(message) {
            case .success(let parsed): messages.append(parsed)
            case .failure(let error): return fail("Message \(index): \(error.reason)")
            }
        }

        if signOnly {
            return .signMessage(
                SignMessageRequest(
                    id: request.id,
                    sessionID: session.id,
                    walletID: session.walletID,
                    dApp: session.dApp,
                    messages: messages,
                    validUntil: params.validUntil,
                    network: params.network,
                    from: params.from,
                    preview: nil
                )
            )
        }
        return .sendTransaction(
            SendTransactionRequest(
                id: request.id,
                sessionID: session.id,
                walletID: session.walletID,
                dApp: session.dApp,
                messages: messages,
                validUntil: params.validUntil,
                network: params.network,
                from: params.from
            )
        )
    }

    /// Parses one outgoing message.
    ///
    /// The amount is decimal-string nanoton on the wire. Rejecting a non-numeric or negative
    /// amount here — rather than coercing to zero — keeps a malformed request from becoming a
    /// silent zero-value transfer the user approves without understanding.
    static func parseMessage(
        _ message: SendTransactionParams.OutgoingMessage
    ) -> Result<TransferMessage, MessageParseError> {
        let address: Address
        do {
            address = try Address.parse(message.address)
        } catch {
            return .failure(MessageParseError("address \(message.address) is not a TON address"))
        }

        // A non-bounceable friendly address means the dApp is deliberately sending somewhere
        // that may have no contract — funding a not-yet-deployed account is the usual reason.
        // Overriding that with bounce-on makes the message bounce and the transfer fail. The
        // raw form carries no flag, so it defaults to bounceable.
        let friendly = try? Address.parseFriendly(message.address)
        let bounce = friendly?.isBounceable ?? true

        guard let amount = BigUInt(message.amount), !message.amount.hasPrefix("-") else {
            return .failure(MessageParseError("amount \(message.amount) is not a non-negative integer"))
        }

        var payload: Cell?
        if let encoded = message.payload, !encoded.isEmpty {
            do {
                payload = try Cell.fromBase64(encoded)
            } catch {
                return .failure(MessageParseError("payload is not a valid BoC: \(error)"))
            }
        }

        var stateInit: StateInit?
        if let encoded = message.stateInit, !encoded.isEmpty {
            do {
                let cell = try Cell.fromBase64(encoded)
                var slice = cell.beginParse()
                stateInit = try StateInit.load(from: &slice)
            } catch {
                return .failure(MessageParseError("stateInit is not a valid StateInit BoC: \(error)"))
            }
        }

        var extra: [UInt32: BigUInt] = [:]
        for (key, value) in message.extraCurrency ?? [:] {
            guard let id = UInt32(key) else {
                return .failure(MessageParseError("extra-currency id \(key) is not a number"))
            }
            guard let amount = BigUInt(value) else {
                return .failure(MessageParseError("extra-currency \(key) amount \(value) is not a number"))
            }
            extra[id] = amount
        }

        return .success(
            TransferMessage(
                address: address,
                amount: amount,
                payload: payload,
                stateInit: stateInit,
                extraCurrency: extra,
                bounce: bounce,
                isTestOnly: friendly?.isTestOnly ?? false
            )
        )
    }

    // MARK: - signData

    /// The wire shape of a `signData` payload.
    struct SignDataParams: Codable {
        let type: String
        let text: String?
        let bytes: String?
        let cell: String?
        let schema: String?
        let network: String?
        let from: String?
    }

    private static func parseSignData(_ request: AppRequest, session: TONConnectSession) -> Parsed {
        func fail(_ reason: String) -> Parsed {
            .malformed(MalformedRequest(id: request.id, sessionID: session.id, reason: reason))
        }

        // The domain comes from the manifest, never from the request. A dApp that could
        // choose it would get a signature verifying against a domain it does not own.
        guard let domain = session.dApp.domain, !domain.isEmpty else {
            return fail("signData needs a manifest domain, and this session has none")
        }

        let params: SignDataParams
        do {
            params = try request.decodeFirstParam(as: SignDataParams.self)
        } catch {
            return fail("signData params did not decode: \(error)")
        }

        let payload: SignData.Payload
        switch params.type {
        case "text":
            guard let text = params.text else { return fail("signData text payload has no text") }
            payload = .text(text)
        case "binary":
            guard let encoded = params.bytes, let bytes = Data(base64Encoded: encoded) else {
                return fail("signData binary payload is not base64")
            }
            payload = .binary(bytes)
        case "cell":
            guard let encoded = params.cell else { return fail("signData cell payload has no cell") }
            guard let schema = params.schema else { return fail("signData cell payload has no schema") }
            do {
                payload = .cell(schema: schema, cell: try Cell.fromBase64(encoded))
            } catch {
                return fail("signData cell is not a valid BoC: \(error)")
            }
        default:
            return fail("signData type \(params.type) is not text, binary, or cell")
        }

        return .signData(
            SignDataRequest(
                id: request.id,
                sessionID: session.id,
                walletID: session.walletID,
                dApp: session.dApp,
                payload: payload,
                domain: domain,
                network: params.network,
                from: params.from
            )
        )
    }
}
