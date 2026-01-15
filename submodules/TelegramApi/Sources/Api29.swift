public extension Api {
    indirect enum WebPageAttribute: TypeConstructorDescription {
        case webPageAttributeStarGiftAuction(gift: Api.StarGift, endDate: Int32)
        case webPageAttributeStarGiftCollection(icons: [Api.Document])
        case webPageAttributeStickerSet(flags: Int32, stickers: [Api.Document])
        case webPageAttributeStory(flags: Int32, peer: Api.Peer, id: Int32, story: Api.StoryItem?)
        case webPageAttributeTheme(flags: Int32, documents: [Api.Document]?, settings: Api.ThemeSettings?)
        case webPageAttributeUniqueStarGift(gift: Api.StarGift)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_webPageAttributeStarGiftAuction(_ reader: BufferReader) -> WebPageAttribute? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_webPageAttributeStarGiftCollection(_ reader: BufferReader) -> WebPageAttribute? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_webPageAttributeStickerSet(_ reader: BufferReader) -> WebPageAttribute? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_webPageAttributeStory(_ reader: BufferReader) -> WebPageAttribute? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_webPageAttributeTheme(_ reader: BufferReader) -> WebPageAttribute? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_webPageAttributeUniqueStarGift(_ reader: BufferReader) -> WebPageAttribute? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum WebViewMessageSent: TypeConstructorDescription {
        case webViewMessageSent(flags: Int32, msgId: Api.InputBotInlineMessageID?)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_webViewMessageSent(_ reader: BufferReader) -> WebViewMessageSent? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum WebViewResult: TypeConstructorDescription {
        case webViewResultUrl(flags: Int32, queryId: Int64?, url: String)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_webViewResultUrl(_ reader: BufferReader) -> WebViewResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum AuthorizationForm: TypeConstructorDescription {
        case authorizationForm(flags: Int32, requiredTypes: [Api.SecureRequiredType], values: [Api.SecureValue], errors: [Api.SecureValueError], users: [Api.User], privacyPolicyUrl: String?)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_authorizationForm(_ reader: BufferReader) -> AuthorizationForm? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum Authorizations: TypeConstructorDescription {
        case authorizations(authorizationTtlDays: Int32, authorizations: [Api.Authorization])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_authorizations(_ reader: BufferReader) -> Authorizations? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum AutoDownloadSettings: TypeConstructorDescription {
        case autoDownloadSettings(low: Api.AutoDownloadSettings, medium: Api.AutoDownloadSettings, high: Api.AutoDownloadSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_autoDownloadSettings(_ reader: BufferReader) -> AutoDownloadSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum AutoSaveSettings: TypeConstructorDescription {
        case autoSaveSettings(usersSettings: Api.AutoSaveSettings, chatsSettings: Api.AutoSaveSettings, broadcastsSettings: Api.AutoSaveSettings, exceptions: [Api.AutoSaveException], chats: [Api.Chat], users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_autoSaveSettings(_ reader: BufferReader) -> AutoSaveSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum BusinessChatLinks: TypeConstructorDescription {
        case businessChatLinks(links: [Api.BusinessChatLink], chats: [Api.Chat], users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_businessChatLinks(_ reader: BufferReader) -> BusinessChatLinks? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum ChatThemes: TypeConstructorDescription {
        case chatThemes(flags: Int32, hash: Int64, themes: [Api.ChatTheme], chats: [Api.Chat], users: [Api.User], nextOffset: String?)
        case chatThemesNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_chatThemes(_ reader: BufferReader) -> ChatThemes? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_chatThemesNotModified(_ reader: BufferReader) -> ChatThemes? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum ConnectedBots: TypeConstructorDescription {
        case connectedBots(connectedBots: [Api.ConnectedBot], users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_connectedBots(_ reader: BufferReader) -> ConnectedBots? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum ContentSettings: TypeConstructorDescription {
        case contentSettings(flags: Int32)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_contentSettings(_ reader: BufferReader) -> ContentSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum EmailVerified: TypeConstructorDescription {
        case emailVerified(email: String)
        case emailVerifiedLogin(email: String, sentCode: Api.auth.SentCode)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_emailVerified(_ reader: BufferReader) -> EmailVerified? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_emailVerifiedLogin(_ reader: BufferReader) -> EmailVerified? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum EmojiStatuses: TypeConstructorDescription {
        case emojiStatuses(hash: Int64, statuses: [Api.EmojiStatus])
        case emojiStatusesNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_emojiStatuses(_ reader: BufferReader) -> EmojiStatuses? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_emojiStatusesNotModified(_ reader: BufferReader) -> EmojiStatuses? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum PaidMessagesRevenue: TypeConstructorDescription {
        case paidMessagesRevenue(starsAmount: Int64)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_paidMessagesRevenue(_ reader: BufferReader) -> PaidMessagesRevenue? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum PasskeyRegistrationOptions: TypeConstructorDescription {
        case passkeyRegistrationOptions(options: Api.DataJSON)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_passkeyRegistrationOptions(_ reader: BufferReader) -> PasskeyRegistrationOptions? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum Passkeys: TypeConstructorDescription {
        case passkeys(passkeys: [Api.Passkey])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_passkeys(_ reader: BufferReader) -> Passkeys? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum Password: TypeConstructorDescription {
        case password(flags: Int32, currentAlgo: Api.PasswordKdfAlgo?, srpB: Buffer?, srpId: Int64?, hint: String?, emailUnconfirmedPattern: String?, newAlgo: Api.PasswordKdfAlgo, newSecureAlgo: Api.SecurePasswordKdfAlgo, secureRandom: Buffer, pendingResetDate: Int32?, loginEmailPattern: String?)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_password(_ reader: BufferReader) -> Password? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum PasswordInputSettings: TypeConstructorDescription {
        case passwordInputSettings(flags: Int32, newAlgo: Api.PasswordKdfAlgo?, newPasswordHash: Buffer?, hint: String?, email: String?, newSecureSettings: Api.SecureSecretSettings?)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_passwordInputSettings(_ reader: BufferReader) -> PasswordInputSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum PasswordSettings: TypeConstructorDescription {
        case passwordSettings(flags: Int32, email: String?, secureSettings: Api.SecureSecretSettings?)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_passwordSettings(_ reader: BufferReader) -> PasswordSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum PrivacyRules: TypeConstructorDescription {
        case privacyRules(rules: [Api.PrivacyRule], chats: [Api.Chat], users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_privacyRules(_ reader: BufferReader) -> PrivacyRules? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum ResetPasswordResult: TypeConstructorDescription {
        case resetPasswordFailedWait(retryDate: Int32)
        case resetPasswordOk
        case resetPasswordRequestedWait(untilDate: Int32)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_resetPasswordFailedWait(_ reader: BufferReader) -> ResetPasswordResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_resetPasswordOk(_ reader: BufferReader) -> ResetPasswordResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_resetPasswordRequestedWait(_ reader: BufferReader) -> ResetPasswordResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum ResolvedBusinessChatLinks: TypeConstructorDescription {
        case resolvedBusinessChatLinks(flags: Int32, peer: Api.Peer, message: String, entities: [Api.MessageEntity]?, chats: [Api.Chat], users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_resolvedBusinessChatLinks(_ reader: BufferReader) -> ResolvedBusinessChatLinks? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
