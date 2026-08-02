import Foundation
import TONCore
import TONCrypto
import TONConnect
import TONToncenter

/// What a dApp is asking for on connect.
public enum RequestedItem: Sendable, Equatable {
    case address
    case proof(payload: String)
    /// A future item type. Kept rather than dropped so the confirmation sheet can tell the
    /// user something unrecognised was requested.
    case unknown(name: String)
}

/// Everything the confirmation sheet needs about who is asking.
///
/// Deliberately separate from ``DAppManifest``: a manifest may fail to fetch and the user
/// must still be shown something, with the failure visible rather than silently rendered as
/// a trustworthy-looking blank.
public struct DAppPreview: Sendable, Equatable {
    public let manifestURL: String
    public let manifest: DAppManifest?
    public let manifestFailure: ManifestFailure?

    public var name: String? { manifest?.name }
    public var iconURL: String? { manifest?.iconUrl }
    /// The host a signature binds to. Nil when the manifest is unusable — and in that case
    /// nothing that needs a domain may be signed.
    public var domain: String? { manifest?.host }

    public var isVerified: Bool { manifest != nil && manifestFailure == nil }

    public init(manifestURL: String, manifest: DAppManifest?, manifestFailure: ManifestFailure?) {
        self.manifestURL = manifestURL
        self.manifest = manifest
        self.manifestFailure = manifestFailure
    }

    var info: DAppInfo {
        DAppInfo(manifestURL: manifestURL, name: name, iconURL: iconURL, domain: domain)
    }
}

/// A dApp asking to connect.
///
/// Arrives from a universal link rather than the bridge, because no session exists yet to
/// decrypt anything.
public struct ConnectionRequest: Sendable, Identifiable {
    /// Kit-local id, used to correlate approval with the durable event.
    public let id: String
    /// The dApp's session public key, hex. Becomes the session id.
    public let clientID: String
    public let bridgeURL: String
    public let requestedItems: [RequestedItem]
    public let dApp: DAppPreview
    /// Where to send the user after approval, if the dApp asked.
    public let returnStrategy: String?

    public var requestsProof: Bool {
        requestedItems.contains { if case .proof = $0 { return true } else { return false } }
    }

    public var proofPayload: String? {
        for item in requestedItems {
            if case .proof(let payload) = item { return payload }
        }
        return nil
    }
}

/// A dApp asking the wallet to sign and broadcast a transfer.
public struct SendTransactionRequest: Sendable, Identifiable {
    /// The dApp's RPC id, echoed in the reply. Getting this wrong leaves the dApp waiting.
    public let id: String
    public let sessionID: String
    public let walletID: WalletID
    public let dApp: DAppInfo
    public let messages: [TransferMessage]
    /// Unix seconds. Past its deadline the request must be refused, not signed.
    public let validUntil: UInt64?
    /// The dApp's expected network. When it disagrees with the wallet's, refuse.
    public let network: String?
    /// The address the dApp expects to send from, if it named one.
    public let from: String?
    /// Emulated outcome, when emulation succeeded. Nil is not a reason to block the request —
    /// it means the user is deciding without a preview, which the sheet should say.
    public var preview: EmulationPreview?

    public init(
        id: String,
        sessionID: String,
        walletID: WalletID,
        dApp: DAppInfo,
        messages: [TransferMessage],
        validUntil: UInt64?,
        network: String?,
        from: String?,
        preview: EmulationPreview? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.walletID = walletID
        self.dApp = dApp
        self.messages = messages
        self.validUntil = validUntil
        self.network = network
        self.from = from
        self.preview = preview
    }
}

/// A dApp asking for a signature over a message it will broadcast itself.
///
/// Same payload shape as ``SendTransactionRequest``; the difference is that the wallet
/// returns the signed body and does **not** send it. A separate type because approving one
/// must never be mistaken for approving the other.
public struct SignMessageRequest: Sendable, Identifiable {
    public let id: String
    public let sessionID: String
    public let walletID: WalletID
    public let dApp: DAppInfo
    public let messages: [TransferMessage]
    public let validUntil: UInt64?
    public let network: String?
    public let from: String?
    public var preview: EmulationPreview?
}

/// A dApp asking for a signature over arbitrary data.
public struct SignDataRequest: Sendable, Identifiable {
    public let id: String
    public let sessionID: String
    public let walletID: WalletID
    public let dApp: DAppInfo
    public let payload: SignData.Payload
    /// The domain the signature binds to, taken from the **manifest** rather than from
    /// anything the dApp sends at request time. A dApp that could choose this could obtain a
    /// signature that verifies against a domain it does not own.
    public let domain: String
    public let network: String?
    public let from: String?
}

/// A dApp ending the connection.
public struct DisconnectRequest: Sendable, Identifiable {
    public let id: String
    public let sessionID: String
    public let walletID: WalletID
    public let dApp: DAppInfo
}

/// A request that arrived but could not be turned into anything actionable.
///
/// Surfaced rather than swallowed: a dApp integration that sends malformed requests is
/// invisible to its author unless the wallet says so, and a user seeing repeated failures
/// from one dApp is information too.
public struct MalformedRequest: Sendable, Identifiable {
    public let id: String
    public let sessionID: String
    public let reason: String
}

/// One message in a transfer, resolved to kit types.
///
/// Amounts and addresses are parsed here rather than at signing time so a malformed
/// request is rejected before the user is shown a sheet for it.
public struct TransferMessage: Sendable, Equatable {
    public let address: Address
    /// Nanoton.
    public let amount: BigUInt
    public let payload: Cell?
    public let stateInit: StateInit?
    /// Extra-currency amounts by currency id.
    public let extraCurrency: [UInt32: BigUInt]
    /// Whether value returns if the destination rejects it.
    ///
    /// Carried per message rather than decided at signing time, because the *sender* chooses
    /// it by the address form they use: a non-bounceable friendly address is how you fund an
    /// address with no contract yet. A bounceable message to an undeployed account bounces
    /// back and the transfer fails — so forcing bounce on would break exactly the case
    /// non-bounceable exists for.
    public let bounce: Bool
    /// Mainnet wallets must refuse a friendly address carrying TON's test-only flag.
    public let isTestOnly: Bool

    public init(
        address: Address,
        amount: BigUInt,
        payload: Cell? = nil,
        stateInit: StateInit? = nil,
        extraCurrency: [UInt32: BigUInt] = [:],
        bounce: Bool = true,
        isTestOnly: Bool = false
    ) {
        self.address = address
        self.amount = amount
        self.payload = payload
        self.stateInit = stateInit
        self.extraCurrency = extraCurrency
        self.bounce = bounce
        self.isTestOnly = isTestOnly
    }

    /// Builds a transfer from an address string, honouring its bounceable flag.
    ///
    /// Defaults to bounceable for the raw form, which carries no flag: value sent to a typo'd
    /// address should come back rather than vanish.
    public init(
        addressString: String,
        amount: BigUInt,
        payload: Cell? = nil,
        stateInit: StateInit? = nil,
        extraCurrency: [UInt32: BigUInt] = [:]
    ) throws {
        let parsed = try Address.parse(addressString)
        // Only the friendly form carries the flag; a parse failure here means it was raw.
        let friendly = try? Address.parseFriendly(addressString)
        let bounceable = friendly?.isBounceable ?? true
        self.init(
            address: parsed,
            amount: amount,
            payload: payload,
            stateInit: stateInit,
            extraCurrency: extraCurrency,
            bounce: bounceable,
            isTestOnly: friendly?.isTestOnly ?? false
        )
    }

    /// Converts to the TL-B message the contract signs over.
    public func toMessageRelaxed() -> MessageRelaxed {
        MessageRelaxed(
            info: .internalMessage(
                CommonMessageInfoRelaxed.InternalInfo(
                    bounce: bounce,
                    dest: address,
                    value: CurrencyCollection(coins: amount, other: extraCurrency)
                )
            ),
            stateInit: stateInit,
            body: payload ?? Cell.empty
        )
    }
}

/// What the user is told will happen if they approve.
///
/// Built from an ``EmulationResult`` rather than from the request, because the requested
/// amount excludes fees and forwarded value — showing it as the cost understates what
/// leaves the wallet.
public struct EmulationPreview: Sendable {
    /// Fees the wallet pays, nanoton.
    public let fees: BigUInt
    /// Net balance change magnitude, nanoton.
    public let netMagnitude: BigUInt
    /// Whether the net change leaves the wallet.
    public let isOutgoing: Bool
    /// How many transactions the transfer would cause.
    public let transactionCount: Int
    /// True when emulation reported a failure. The sheet must warn rather than present a
    /// normal confirmation.
    public let willFail: Bool
    /// True when the emulator could not follow the whole tree. The preview is partial and
    /// must not be shown as authoritative.
    public let isIncomplete: Bool

    public init(
        fees: BigUInt,
        netMagnitude: BigUInt,
        isOutgoing: Bool,
        transactionCount: Int,
        willFail: Bool,
        isIncomplete: Bool
    ) {
        self.fees = fees
        self.netMagnitude = netMagnitude
        self.isOutgoing = isOutgoing
        self.transactionCount = transactionCount
        self.willFail = willFail
        self.isIncomplete = isIncomplete
    }

    /// Derives a preview for one wallet from an emulation.
    public init(emulation: EmulationResult, walletAddress: String) {
        let flow = emulation.moneyFlow(for: walletAddress)
        self.fees = flow.fees
        self.netMagnitude = flow.netMagnitude
        self.isOutgoing = flow.isOutgoing
        self.transactionCount = emulation.transactions.count
        self.willFail = emulation.transactions.contains { transaction in
            guard transaction.isFailed else {
                return false
            }

            // NFT ownership changes before the item contract forwards `ownership_assigned`
            // to the new owner. The ecosystem convention is to forward one nanoton so the
            // notification exists for indexers, but a deployed recipient cannot run its
            // compute phase on that value and reports `no_gas`. The asset has already moved,
            // so this terminal child is not a transfer failure. Keep the exception scoped to
            // a notification emitted by the same item contract whose `nft_transfer`
            // transaction succeeded; every other `no_gas` remains a real failure.
            guard transaction.computeSkipReason == .noGas,
                  transaction.outMessages.isEmpty,
                  let notification = transaction.inMessage,
                  notification.kind == .nftOwnershipAssigned,
                  let itemAddress = notification.source,
                  let parsedItemAddress = try? Address.parse(itemAddress) else {
                return true
            }
            let hasSuccessfulItemTransfer = emulation.transactions.contains { candidate in
                guard !candidate.isFailed,
                      let transfer = candidate.inMessage,
                      transfer.kind == .nftTransfer,
                      let parsedCandidateAddress = try? Address.parse(candidate.account) else {
                    return false
                }
                return parsedCandidateAddress == parsedItemAddress
            }
            return !hasSuccessfulItemTransfer
        }
        self.isIncomplete = emulation.isIncomplete
    }
}
