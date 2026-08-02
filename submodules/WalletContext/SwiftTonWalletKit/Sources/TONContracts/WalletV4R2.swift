import Foundation
import TONCore
import TONCrypto

/// WalletV4R2, the previous generation and still widely deployed.
///
/// Simpler than V5R1: no action lists and no extensions dictionary, just a sequence of
/// message refs in the body.
public struct WalletV4R2: Sendable {
    /// Default subwallet id for V4R2.
    public static let defaultWalletID: UInt32 = 698_983_191

    /// Body opcode for an ordinary transfer. V4R2 also defines plugin operations, which
    /// this port does not implement.
    static let simpleTransferOp: UInt64 = 0

    public struct Config: Sendable {
        public var seqno: UInt32
        public var walletID: UInt32
        public var publicKey: Data

        public init(
            publicKey: Data,
            walletID: UInt32 = WalletV4R2.defaultWalletID,
            seqno: UInt32 = 0
        ) {
            precondition(publicKey.count == 32, "Public key must be 32 bytes")
            self.publicKey = publicKey
            self.walletID = walletID
            self.seqno = seqno
        }
    }

    public let config: Config
    public let workchain: Int8

    public init(config: Config, workchain: Int8 = 0) {
        self.config = config
        self.workchain = workchain
    }

    public init(
        publicKey: Data,
        walletID: UInt32 = WalletV4R2.defaultWalletID,
        workchain: Int8 = 0
    ) {
        self.init(config: Config(publicKey: publicKey, walletID: walletID), workchain: workchain)
    }

    // MARK: - State

    /// `seqno:uint32 subwalletId:uint32 publicKey:uint256 plugins:HashmapE`
    ///
    /// Note the field order differs from V5R1, and the plugins dictionary is always
    /// written empty.
    public func dataCell() throws -> Cell {
        let builder = beginCell()
        try builder.storeUInt(UInt64(config.seqno), bits: 32)
        try builder.storeUInt(UInt64(config.walletID), bits: 32)
        try builder.storeBigUInt(BigUInt(config.publicKey), bits: 256)
        try builder.storeBit(false) // empty plugins dictionary
        return try builder.endCell()
    }

    public func stateInit() throws -> StateInit {
        StateInit(code: WalletCode.v4r2, data: try dataCell())
    }

    public func address() throws -> Address {
        try contractAddress(workchain: workchain, init: try stateInit())
    }

    // MARK: - Transfers

    /// Builds the unsigned transfer body.
    ///
    /// `subwalletId | validUntil | seqno | op | sendMode | messages…`
    ///
    /// Every message is a ref, so at most 4 fit per body — unlike V5R1's ref-chained
    /// action list, which reaches 255.
    public func unsignedTransfer(
        seqno: UInt32,
        validUntil: UInt32,
        sendMode: SendMode,
        messages: [MessageRelaxed]
    ) throws -> Cell {
        guard messages.count <= Cell.maxRefs else {
            throw TransferError.tooManyMessages(messages.count)
        }

        let builder = beginCell()
        try builder.storeUInt(UInt64(config.walletID), bits: 32)
        try builder.storeUInt(UInt64(validUntil), bits: 32)
        try builder.storeUInt(UInt64(seqno), bits: 32)
        try builder.storeUInt(Self.simpleTransferOp, bits: 8)
        try builder.storeUInt(UInt64(sendMode.rawValue), bits: 8)

        for message in messages {
            try builder.storeRef(try message.toCell())
        }

        return try builder.endCell()
    }

    /// Signs a transfer body. V4R2 puts the signature *first*, unlike V5R1.
    public func createSignedTransfer(
        seqno: UInt32,
        validUntil: UInt32,
        sendMode: SendMode = .walletDefault,
        messages: [MessageRelaxed],
        secretKey: Data
    ) throws -> Cell {
        let payload = try unsignedTransfer(
            seqno: seqno,
            validUntil: validUntil,
            sendMode: sendMode,
            messages: messages
        )
        let signature = try Ed25519.sign(payload.hash(), secretKey: secretKey)

        let builder = beginCell()
        try builder.storeBytes(signature)
        try builder.storeCellInline(payload)
        return try builder.endCell()
    }

    public func externalMessage(body: Cell, includeStateInit: Bool) throws -> Message {
        Message.makeExternalIn(
            to: try address(),
            stateInit: includeStateInit ? try stateInit() : nil,
            body: body
        )
    }

    public enum TransferError: Error, CustomStringConvertible {
        case tooManyMessages(Int)

        public var description: String {
            switch self {
            case .tooManyMessages(let n):
                return "V4R2 carries at most 4 messages per transfer, got \(n)"
            }
        }
    }
}
