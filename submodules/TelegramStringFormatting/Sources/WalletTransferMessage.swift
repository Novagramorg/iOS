import Foundation

public struct WalletTransferMessageData: Equatable {
    public enum Direction: Equatable {
        case incoming
        case outgoing
    }

    public let direction: Direction
    public let amount: Int64
    public let caption: String

    public init(direction: Direction, amount: Int64, caption: String) {
        self.direction = direction
        self.amount = amount
        self.caption = caption
    }
}

public func parseWalletTransferMessageText(_ text: String) -> WalletTransferMessageData? {
    let prefix = "_<transfer:"
    guard text.hasPrefix(prefix) else {
        return nil
    }

    let payloadStartIndex = text.index(text.startIndex, offsetBy: prefix.count)
    guard let payloadEndIndex = text[payloadStartIndex...].firstIndex(of: ">") else {
        return nil
    }

    let payload = text[payloadStartIndex..<payloadEndIndex]
    let components = payload.split(separator: ",", omittingEmptySubsequences: false)
    guard components.count == 2 else {
        return nil
    }

    let direction: WalletTransferMessageData.Direction
    switch components[0] {
    case "in":
        direction = .incoming
    case "out":
        direction = .outgoing
    default:
        return nil
    }

    let amountText = components[1]
    guard !amountText.isEmpty, amountText.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }), let amount = Int64(String(amountText)) else {
        return nil
    }

    let captionStartIndex = text.index(after: payloadEndIndex)
    return WalletTransferMessageData(
        direction: direction,
        amount: amount,
        caption: String(text[captionStartIndex...])
    )
}
