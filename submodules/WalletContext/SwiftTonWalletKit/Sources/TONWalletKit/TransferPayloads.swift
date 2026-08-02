import Foundation
import TONCore

/// Message bodies for the transfers a wallet initiates.
///
/// Pure builders, separate from the sending code, because these are the part that must be
/// exactly right: a body with the fields in the wrong order is still a valid cell, still signs,
/// still broadcasts, and simply does the wrong thing — or nothing — when the receiving contract
/// parses it. Being pure makes them checkable byte-for-byte against golden vectors and against
/// what the live contracts actually accepted.
public enum TransferPayloads {
    /// TEP-74 jetton `transfer`.
    public static let jettonTransferOp: UInt64 = 0x0f8a_7ea5
    /// TEP-62 NFT `transfer`.
    public static let nftTransferOp: UInt64 = 0x5fcc_3d14

    /// Nanoton forwarded to the recipient with a jetton or NFT transfer.
    ///
    /// One nanoton is the ecosystem convention, and it is a deliberate compromise rather than a
    /// real gas budget: TEP-74 only sends a `transfer_notification` when this is non-zero, so a
    /// single nanoton makes the notification *exist* on chain — which is what indexers and the
    /// recipient's UI watch for — while costing the sender nothing.
    ///
    /// The recipient pays gas out of it, so the notification's own transaction usually skips its
    /// compute phase for `no_gas`. That is expected and harmless: the asset has already moved by
    /// then. It does mean emulation reports a failing transaction in the trace — see
    /// ``EmulationPreview`` for how a preview must read that.
    public static let defaultForwardAmount = BigUInt(1)

    /// TON attached to a jetton transfer to cover both jetton wallets' gas. 0.05 TON.
    public static let defaultJettonGas = BigUInt(50_000_000)
    /// TON attached to an NFT transfer. 0.1 TON — an NFT item does more work than a jetton
    /// wallet, and the unspent remainder returns via `response_destination`.
    public static let defaultNFTGas = BigUInt(100_000_000)

    /// A text comment: op 0 followed by the UTF-8 text.
    ///
    /// The text spills into reference cells when it exceeds one cell, which
    /// ``Builder/storeStringTail(_:)`` handles — a comment long enough to overflow is otherwise
    /// a build-time crash on an input the user typed.
    public static func comment(_ text: String) throws -> Cell {
        try beginCell()
            .storeUInt(0, bits: 32)
            .storeStringTail(text)
            .endCell()
    }

    /// TEP-74 jetton transfer body, sent to the **sender's own jetton wallet**.
    ///
    /// The destination here is the recipient's *owner* address, not their jetton wallet: the
    /// sending jetton wallet derives its counterpart itself. Addressing this at the recipient's
    /// jetton wallet — an easy mistake, since that is what a balance listing shows — produces a
    /// message that contract will reject.
    public static func jettonTransfer(
        amount: BigUInt,
        destination: Address,
        responseDestination: Address?,
        comment commentText: String? = nil,
        queryID: UInt64 = 0,
        customPayload: Cell? = nil,
        forwardAmount: BigUInt = defaultForwardAmount,
        forwardPayload: Cell? = nil
    ) throws -> Cell {
        // A comment travels as the forward payload, so it reaches the recipient rather than
        // sitting on the jetton wallet's own message.
        let payload = try forwardPayload ?? commentText.map { try comment($0) }

        return try beginCell()
            .storeUInt(jettonTransferOp, bits: 32)
            .storeUInt(queryID, bits: 64)
            .storeCoins(amount)
            .storeAddress(destination)
            // nil serialises as addr_none, which forfeits the unspent remainder. Callers should
            // pass the sender.
            .storeAddress(responseDestination)
            .storeMaybeRef(customPayload)
            .storeCoins(forwardAmount)
            // `Either Cell ^Cell` and `Maybe ^Cell` coincide on the wire: bit 0 then nothing is
            // an empty inline payload, bit 1 then a ref is the referenced one.
            .storeMaybeRef(payload)
            .endCell()
    }

    /// TEP-62 NFT transfer body, sent to the **item contract**.
    public static func nftTransfer(
        newOwner: Address,
        responseDestination: Address?,
        comment commentText: String? = nil,
        queryID: UInt64 = 0,
        customPayload: Cell? = nil,
        forwardAmount: BigUInt = defaultForwardAmount,
        forwardPayload: Cell? = nil
    ) throws -> Cell {
        let payload = try forwardPayload ?? commentText.map { try comment($0) }

        return try beginCell()
            .storeUInt(nftTransferOp, bits: 32)
            .storeUInt(queryID, bits: 64)
            .storeAddress(newOwner)
            .storeAddress(responseDestination)
            .storeMaybeRef(customPayload)
            .storeCoins(forwardAmount)
            .storeMaybeRef(payload)
            .endCell()
    }
}
