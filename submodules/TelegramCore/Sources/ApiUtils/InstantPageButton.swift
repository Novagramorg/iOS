import Foundation
import Postbox
import TelegramApi

public extension ReplyMarkupButton.Style.Color {
    /// `richButtonStyle flags:# bg_primary:flags.0?true bg_danger:flags.1?true bg_success:flags.2?true`
    /// maps onto the reply-markup colour palette, which already has exactly these three values.
    init?(apiRichStyle: Api.RichButtonStyle) {
        switch apiRichStyle {
        case let .richButtonStyle(data):
            if data.flags & (1 << 0) != 0 {
                self = .primary
            } else if data.flags & (1 << 1) != 0 {
                self = .danger
            } else if data.flags & (1 << 2) != 0 {
                self = .success
            } else {
                return nil
            }
        }
    }

    var apiRichStyleFlags: Int32 {
        switch self {
        case .primary:
            return 1 << 0
        case .danger:
            return 1 << 1
        case .success:
            return 1 << 2
        }
    }
}

extension ReplyMarkupButtonAction {
    /// Outgoing direction for page buttons. Only the inline-reachable cases are representable; the
    /// five keyboard-only cases collapse onto `inlineButtonTypeDisabled`, mirroring the FlatBuffers
    /// codec in SyncCore_InstantPageButton.swift.
    func apiInlineButtonType() -> Api.InlineButtonType {
        switch self {
        case let .url(url):
            return .inlineButtonTypeUrl(Api.InlineButtonType.Cons_inlineButtonTypeUrl(url: url))
        case let .urlAuth(url, buttonId):
            return .inlineButtonTypeUrlAuth(Api.InlineButtonType.Cons_inlineButtonTypeUrlAuth(flags: 0, fwdText: nil, url: url, buttonId: buttonId))
        case let .openWebView(url, _):
            return .inlineButtonTypeWebView(Api.InlineButtonType.Cons_inlineButtonTypeWebView(url: url))
        case let .callback(requiresPassword, data):
            return .inlineButtonTypeCallback(Api.InlineButtonType.Cons_inlineButtonTypeCallback(
                flags: requiresPassword ? (1 << 0) : 0,
                data: Buffer(data: data.makeData())
            ))
        case .openWebApp:
            return .inlineButtonTypeGame
        case .payment:
            return .inlineButtonTypeBuy
        case let .switchInline(samePeer, query, _):
            return .inlineButtonTypeSwitchInline(Api.InlineButtonType.Cons_inlineButtonTypeSwitchInline(
                flags: samePeer ? (1 << 0) : 0,
                query: query,
                peerTypes: nil
            ))
        case let .openUserProfile(peerId):
            return .inlineButtonTypeUserProfile(Api.InlineButtonType.Cons_inlineButtonTypeUserProfile(userId: peerId.id._internalGetInt64Value()))
        case let .copyText(payload):
            return .inlineButtonTypeCopy(Api.InlineButtonType.Cons_inlineButtonTypeCopy(copyText: payload))
        case .disabled, .text, .requestPhone, .requestMap, .setupPoll, .requestPeer:
            return .inlineButtonTypeDisabled
        }
    }
}

extension InstantPageButton {
    init(apiButton: Api.PageButton) {
        switch apiButton {
        case let .pageButton(data):
            self.init(
                text: RichText(apiText: data.text),
                action: ReplyMarkupButtonAction.from(apiType: data.type).action,
                color: data.style.flatMap(ReplyMarkupButton.Style.Color.init(apiRichStyle:))
            )
        }
    }

    /// `textButton` and `pageButton` carry identical fields, so the flags/style computation is
    /// shared and each caller wraps it in its own constructor.
    func apiFlagsAndStyle() -> (flags: Int32, style: Api.RichButtonStyle?) {
        guard let color = self.color else {
            return (0, nil)
        }
        return (1 << 0, .richButtonStyle(Api.RichButtonStyle.Cons_richButtonStyle(flags: color.apiRichStyleFlags)))
    }

    func apiPageButton() -> Api.PageButton {
        let (flags, style) = self.apiFlagsAndStyle()
        return .pageButton(Api.PageButton.Cons_pageButton(
            flags: flags,
            text: self.text.apiRichText(),
            type: self.action.apiInlineButtonType(),
            style: style
        ))
    }
}
