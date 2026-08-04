import Foundation
import TONCore

/// Standard message opcodes, from the TEP token standards.
///
/// A message's first 32 bits identify its operation. Classifying by opcode is what turns
/// "an internal message with a body" into "a jetton transfer" — which is what a wallet
/// must show the user.
public enum OpCode: UInt32, Sendable, CaseIterable {
    // Jettons (TEP-74)
    case jettonTransfer = 0x0f8a_7ea5
    case jettonInternalTransfer = 0x178d_4519
    case jettonNotify = 0x7362_d09c
    case jettonBurn = 0x595f_07bc
    case jettonMint = 0x15

    // NFTs (TEP-62)
    case nftTransfer = 0x5fcc_3d14
    case nftOwnershipAssigned = 0x0513_8d91
    case nftOwnerChanged = 0x7bdd_97de
    case nftGetStaticData = 0x2fcb_26a2
    case nftReportStaticData = 0x8b77_1735

    /// Refund of unused forward value, sent by most standard contracts.
    case excess = 0xd532_76db

    // DNS
    case dnsChangeRecord = 0x4eb1_f0f9

    /// Parses the `0x…` form Toncenter reports.
    public init?(hexString: String) {
        let stripped = hexString.hasPrefix("0x") || hexString.hasPrefix("0X")
            ? String(hexString.dropFirst(2))
            : hexString
        guard let raw = UInt32(stripped, radix: 16), let code = OpCode(rawValue: raw) else {
            return nil
        }
        self = code
    }
}

/// What a message does, in terms a wallet can display.
public enum MessageKind: String, Sendable {
    case tonTransfer = "ton_transfer"
    case jettonTransfer = "jetton_transfer"
    case jettonInternalTransfer = "jetton_internal_transfer"
    case jettonNotify = "jetton_notify"
    case jettonBurn = "jetton_burn"
    case jettonMint = "jetton_mint"
    case nftTransfer = "nft_transfer"
    case nftOwnershipAssigned = "nft_ownership_assigned"
    case nftOwnerChanged = "nft_owner_changed"
    /// Refund of unused forward value.
    case excess
    /// Deploys a contract: carries a state init.
    case contractDeploy = "contract_deploy"
    /// Calls a contract with an opcode we do not recognise.
    case contractExec = "contract_exec"
    case unknown

    init(opCode: OpCode) {
        switch opCode {
        case .jettonTransfer: self = .jettonTransfer
        case .jettonInternalTransfer: self = .jettonInternalTransfer
        case .jettonNotify: self = .jettonNotify
        case .jettonBurn: self = .jettonBurn
        case .jettonMint: self = .jettonMint
        case .nftTransfer: self = .nftTransfer
        case .nftOwnershipAssigned: self = .nftOwnershipAssigned
        case .nftOwnerChanged: self = .nftOwnerChanged
        case .excess: self = .excess
        case .nftGetStaticData, .nftReportStaticData, .dnsChangeRecord: self = .contractExec
        }
    }

    /// Whether this represents value the user actually moved, as opposed to protocol
    /// plumbing.
    ///
    /// Notifications and excess refunds are consequences of a transfer, not transfers
    /// themselves; counting them would double-count the amount shown to the user.
    public var isUserFacingTransfer: Bool {
        switch self {
        case .tonTransfer, .jettonTransfer, .jettonBurn, .jettonMint,
             .nftTransfer, .nftOwnershipAssigned:
            return true
        case .jettonInternalTransfer, .jettonNotify, .nftOwnerChanged, .excess,
             .contractDeploy, .contractExec, .unknown:
            return false
        }
    }
}

/// Classifies a message.
public enum MessageClassifier {
    /// Determines what a message does.
    ///
    /// Order matters. An opcode wins over everything, because a bodied message with a
    /// recognised opcode is that operation regardless of what else it carries. Only then
    /// does a state init mean "deploy", and only then does an empty body mean "plain
    /// transfer".
    public static func classify(_ message: ChainMessage, hasStateInit: Bool = false) -> MessageKind {
        if let opcodeHex = message.opcode, let code = OpCode(hexString: opcodeHex) {
            return MessageKind(opCode: code)
        }

        // Opcode 0 with a body is the "comment" convention: a plain transfer carrying
        // text, not a contract call.
        if let opcodeHex = message.opcode,
           let raw = UInt32(opcodeHex.hasPrefix("0x") ? String(opcodeHex.dropFirst(2)) : opcodeHex, radix: 16),
           raw == 0 {
            return .tonTransfer
        }

        if hasStateInit { return .contractDeploy }

        // No opcode at all: an empty body, which is a bare value transfer.
        if message.opcode == nil { return .tonTransfer }

        // An unrecognised opcode is a contract call we cannot name.
        return .contractExec
    }

    /// Extracts a text comment from a transfer body, if it carries one.
    ///
    /// Toncenter usually decodes this for us; this handles the case where it has not.
    /// The convention is a 32-bit zero opcode followed by UTF-8 text.
    public static func comment(from message: ChainMessage) -> String? {
        if let decoded = message.comment, !decoded.isEmpty { return decoded }

        guard let bodyBoc = message.bodyBoc,
              let cell = try? Cell.fromBase64(bodyBoc)
        else { return nil }

        var slice = cell.asSlice()
        guard slice.remainingBits >= 32,
              let opcode = try? slice.loadUInt(32),
              opcode == 0
        else { return nil }

        guard let text = try? slice.loadStringTail(), !text.isEmpty else { return nil }
        return text
    }
}

extension ChainMessage {
    /// What this message does.
    public var kind: MessageKind {
        MessageClassifier.classify(self)
    }

    /// A text comment, decoded from the body when Toncenter has not decoded it.
    public var textComment: String? {
        MessageClassifier.comment(from: self)
    }
}
