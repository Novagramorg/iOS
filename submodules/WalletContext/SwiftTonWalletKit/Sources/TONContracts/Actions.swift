import Foundation
import TONCore

/// An entry in a WalletV5R1 action list.
///
/// V5R1 splits actions into two kinds with different placement rules: ordinary
/// out-actions (sending messages) and "extended" actions that reconfigure the wallet.
public enum WalletV5Action: Sendable {
    /// `action_send_msg`, tag `0x0ec3c86d`.
    case sendMessage(mode: SendMode, message: MessageRelaxed)
    /// `action_extended_add_extension`, tag `0x02`.
    case addExtension(Address)
    /// `action_extended_remove_extension`, tag `0x03`.
    case removeExtension(Address)
    /// `action_extended_set_signature_auth_allowed`, tag `0x04`.
    case setSignatureAuthAllowed(Bool)

    /// Extended actions are collected separately from out-actions during packing.
    public var isExtended: Bool {
        switch self {
        case .sendMessage: return false
        case .addExtension, .removeExtension, .setSignatureAuthAllowed: return true
        }
    }

    static let sendMessageTag: UInt64 = 0x0ec3_c86d
    static let addExtensionTag: UInt64 = 0x02
    static let removeExtensionTag: UInt64 = 0x03
    static let setSignatureAuthAllowedTag: UInt64 = 0x04

    /// Serializes this action to its own cell.
    public func serialize() throws -> Cell {
        let builder = beginCell()
        switch self {
        case .sendMessage(let mode, let message):
            try builder.storeUInt(Self.sendMessageTag, bits: 32)
            // IGNORE_ERRORS is forced on, matching the reference: a failed action must
            // not roll back the rest of the list.
            let effectiveMode = mode.union(.ignoreErrors)
            try builder.storeUInt(UInt64(effectiveMode.rawValue), bits: 8)
            try builder.storeRef(try message.toCell())
        case .addExtension(let address):
            try builder.storeUInt(Self.addExtensionTag, bits: 8)
            try builder.storeAddress(address)
        case .removeExtension(let address):
            try builder.storeUInt(Self.removeExtensionTag, bits: 8)
            try builder.storeAddress(address)
        case .setSignatureAuthAllowed(let allowed):
            try builder.storeUInt(Self.setSignatureAuthAllowedTag, bits: 8)
            try builder.storeUInt(allowed ? 1 : 0, bits: 1)
        }
        return try builder.endCell()
    }
}

/// Packs a WalletV5R1 action list.
public enum ActionList {
    public enum ActionListError: Error, CustomStringConvertible {
        case extendedActionInOutList
        case tooManyActions(Int)

        public var description: String {
            switch self {
            case .extendedActionInOutList:
                return "Actions must be ordered: all extended actions, then all out actions"
            case .tooManyActions(let n):
                return "Action list holds \(n) actions, maximum is 255"
            }
        }
    }

    /// Protocol maximum for a single action list.
    public static let maxActions = 255

    /// Packs actions into the cell the wallet contract expects.
    ///
    /// Layout: a `Maybe ^OutActions` followed by a `Maybe` inline extended-action chain.
    /// Out-actions are **reversed** before packing, because each cell references the
    /// remainder — so the last action supplied ends up outermost. Getting the order
    /// wrong yields a valid-looking cell that executes the transfers in reverse.
    public static func pack(_ actions: [WalletV5Action]) throws -> Cell {
        guard actions.count <= maxActions else { throw ActionListError.tooManyActions(actions.count) }

        let extended = actions.filter(\.isExtended)
        let out = actions.filter { !$0.isExtended }

        let builder = beginCell()

        if out.isEmpty {
            try builder.storeUInt(0, bits: 1)
        } else {
            try builder.storeMaybeRef(try packOutActions(Array(out.reversed())))
        }

        if extended.isEmpty {
            try builder.storeUInt(0, bits: 1)
        } else {
            try builder.storeUInt(1, bits: 1)
            // The first extended action sits inline; the rest hang off a ref.
            try builder.storeCellInline(try extended[0].serialize())
            let rest = Array(extended.dropFirst())
            if !rest.isEmpty {
                try builder.storeRef(try packExtendedActions(rest))
            }
        }

        return try builder.endCell()
    }

    /// Recursive ref-chain: each cell holds the remainder in a ref, then its own action
    /// inline.
    private static func packOutActions(_ actions: [WalletV5Action]) throws -> Cell {
        guard let action = actions.first else {
            return try beginCell().endCell()
        }
        guard !action.isExtended else { throw ActionListError.extendedActionInOutList }

        let builder = beginCell()
        try builder.storeRef(try packOutActions(Array(actions.dropFirst())))
        try builder.storeCellInline(try action.serialize())
        return try builder.endCell()
    }

    /// Extended actions chain the other way round: own action inline first, then the
    /// remainder in a ref.
    private static func packExtendedActions(_ actions: [WalletV5Action]) throws -> Cell {
        guard let first = actions.first else {
            return try beginCell().endCell()
        }
        let builder = beginCell()
        try builder.storeCellInline(try first.serialize())
        let rest = Array(actions.dropFirst())
        if !rest.isEmpty {
            try builder.storeRef(try packExtendedActions(rest))
        }
        return try builder.endCell()
    }
}
