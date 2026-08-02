import Foundation
import TONCore

public struct JettonTransferPayload: Sendable {
    public let amount: BigUInt
    public let destination: Address
    public let comment: String?
}

public struct JettonNotificationPayload: Sendable {
    public let amount: BigUInt
    public let sender: Address
    public let comment: String?
}

public struct NFTTransferPayload: Sendable {
    public let newOwner: Address
    public let comment: String?
}

public struct NFTOwnershipAssignedPayload: Sendable {
    public let previousOwner: Address
    public let comment: String?
}

/// Read-side decoders for the token standards used by transaction history.
public enum TransferPayloadDecoder {
    public static func jettonTransfer(from message: ChainMessage) -> JettonTransferPayload? {
        guard var slice = body(of: message),
              (try? slice.loadUInt(32)) == UInt64(OpCode.jettonTransfer.rawValue) else {
            return nil
        }
        do {
            _ = try slice.loadUInt(64)
            let amount = try slice.loadCoins()
            let destination = try slice.loadAddress()
            _ = try slice.loadMaybeAddress()
            _ = try slice.loadMaybeRef()
            _ = try slice.loadCoins()
            return JettonTransferPayload(
                amount: amount,
                destination: destination,
                comment: try forwardComment(from: &slice)
            )
        } catch {
            return nil
        }
    }

    public static func jettonNotification(from message: ChainMessage) -> JettonNotificationPayload? {
        guard var slice = body(of: message),
              (try? slice.loadUInt(32)) == UInt64(OpCode.jettonNotify.rawValue) else {
            return nil
        }
        do {
            _ = try slice.loadUInt(64)
            let amount = try slice.loadCoins()
            let sender = try slice.loadAddress()
            return JettonNotificationPayload(
                amount: amount,
                sender: sender,
                comment: try forwardComment(from: &slice)
            )
        } catch {
            return nil
        }
    }

    public static func nftTransfer(from message: ChainMessage) -> NFTTransferPayload? {
        guard var slice = body(of: message),
              (try? slice.loadUInt(32)) == UInt64(OpCode.nftTransfer.rawValue) else {
            return nil
        }
        do {
            _ = try slice.loadUInt(64)
            let newOwner = try slice.loadAddress()
            _ = try slice.loadMaybeAddress()
            _ = try slice.loadMaybeRef()
            _ = try slice.loadCoins()
            return NFTTransferPayload(
                newOwner: newOwner,
                comment: try forwardComment(from: &slice)
            )
        } catch {
            return nil
        }
    }

    public static func nftOwnershipAssigned(from message: ChainMessage) -> NFTOwnershipAssignedPayload? {
        guard var slice = body(of: message),
              (try? slice.loadUInt(32)) == UInt64(OpCode.nftOwnershipAssigned.rawValue) else {
            return nil
        }
        do {
            _ = try slice.loadUInt(64)
            let previousOwner = try slice.loadAddress()
            return NFTOwnershipAssignedPayload(
                previousOwner: previousOwner,
                comment: try forwardComment(from: &slice)
            )
        } catch {
            return nil
        }
    }

    private static func body(of message: ChainMessage) -> Slice? {
        guard let body = message.bodyBoc, let cell = try? Cell.fromBase64(body) else { return nil }
        return cell.beginParse()
    }

    private static func forwardComment(from slice: inout Slice) throws -> String? {
        let payload: Cell
        if try slice.loadBit() {
            payload = try slice.loadRef()
        } else {
            payload = try slice.asCell()
        }
        var payloadSlice = payload.beginParse()
        guard payloadSlice.remainingBits >= 32,
              try payloadSlice.loadUInt(32) == 0 else {
            return nil
        }
        let value = try payloadSlice.loadStringTail()
        return value.isEmpty ? nil : value
    }
}
