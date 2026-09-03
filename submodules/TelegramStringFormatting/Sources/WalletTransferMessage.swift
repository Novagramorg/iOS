import Foundation
import TelegramCore

public struct WalletTransferMessageData: Equatable {
    public enum Direction: Equatable {
        case incoming
        case outgoing
    }

    public let direction: Direction
    public let amount: Int64
    public let transactionId: String
    public let caption: String

    public init(direction: Direction, amount: Int64, transactionId: String, caption: String) {
        self.direction = direction
        self.amount = amount
        self.transactionId = transactionId
        self.caption = caption
    }
}

public func walletTransferMessageData(message: EngineMessage, accountPeerId: EnginePeer.Id) -> WalletTransferMessageData? {
    for media in message.media {
        guard let action = media as? TelegramMediaAction,
              case let .gramTransfer(amount, transactionId, comment) = action.action else {
            continue
        }
        return WalletTransferMessageData(
            direction: message.effectivelyIncoming(accountPeerId) ? .incoming : .outgoing,
            amount: amount,
            transactionId: transactionId,
            caption: comment ?? ""
        )
    }
    return nil
}
