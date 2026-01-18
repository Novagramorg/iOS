public extension Api {
    indirect enum WebPageAttribute: TypeConstructorDescription {
        public class Cons_webPageAttributeStarGiftAuction {
            public var gift: Api.StarGift
            public var endDate: Int32
            public init(gift: Api.StarGift, endDate: Int32) {
                self.gift = gift
                self.endDate = endDate
            }
        }
        public class Cons_webPageAttributeStarGiftCollection {
            public var icons: [Api.Document]
            public init(icons: [Api.Document]) {
                self.icons = icons
            }
        }
        public class Cons_webPageAttributeStickerSet {
            public var flags: Int32
            public var stickers: [Api.Document]
            public init(flags: Int32, stickers: [Api.Document]) {
                self.flags = flags
                self.stickers = stickers
            }
        }
        public class Cons_webPageAttributeStory {
            public var flags: Int32
            public var peer: Api.Peer
            public var id: Int32
            public var story: Api.StoryItem?
            public init(flags: Int32, peer: Api.Peer, id: Int32, story: Api.StoryItem?) {
                self.flags = flags
                self.peer = peer
                self.id = id
                self.story = story
            }
        }
        public class Cons_webPageAttributeTheme {
            public var flags: Int32
            public var documents: [Api.Document]?
            public var settings: Api.ThemeSettings?
            public init(flags: Int32, documents: [Api.Document]?, settings: Api.ThemeSettings?) {
                self.flags = flags
                self.documents = documents
                self.settings = settings
            }
        }
        public class Cons_webPageAttributeUniqueStarGift {
            public var gift: Api.StarGift
            public init(gift: Api.StarGift) {
                self.gift = gift
            }
        }
        case webPageAttributeStarGiftAuction(Cons_webPageAttributeStarGiftAuction)
        case webPageAttributeStarGiftCollection(Cons_webPageAttributeStarGiftCollection)
        case webPageAttributeStickerSet(Cons_webPageAttributeStickerSet)
        case webPageAttributeStory(Cons_webPageAttributeStory)
        case webPageAttributeTheme(Cons_webPageAttributeTheme)
        case webPageAttributeUniqueStarGift(Cons_webPageAttributeUniqueStarGift)

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
        public class Cons_webViewMessageSent {
            public var flags: Int32
            public var msgId: Api.InputBotInlineMessageID?
            public init(flags: Int32, msgId: Api.InputBotInlineMessageID?) {
                self.flags = flags
                self.msgId = msgId
            }
        }
        case webViewMessageSent(Cons_webViewMessageSent)

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
        public class Cons_webViewResultUrl {
            public var flags: Int32
            public var queryId: Int64?
            public var url: String
            public init(flags: Int32, queryId: Int64?, url: String) {
                self.flags = flags
                self.queryId = queryId
                self.url = url
            }
        }
        case webViewResultUrl(Cons_webViewResultUrl)

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
        public class Cons_authorizationForm {
            public var flags: Int32
            public var requiredTypes: [Api.SecureRequiredType]
            public var values: [Api.SecureValue]
            public var errors: [Api.SecureValueError]
            public var users: [Api.User]
            public var privacyPolicyUrl: String?
            public init(flags: Int32, requiredTypes: [Api.SecureRequiredType], values: [Api.SecureValue], errors: [Api.SecureValueError], users: [Api.User], privacyPolicyUrl: String?) {
                self.flags = flags
                self.requiredTypes = requiredTypes
                self.values = values
                self.errors = errors
                self.users = users
                self.privacyPolicyUrl = privacyPolicyUrl
            }
        }
        case authorizationForm(Cons_authorizationForm)

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
        public class Cons_authorizations {
            public var authorizationTtlDays: Int32
            public var authorizations: [Api.Authorization]
            public init(authorizationTtlDays: Int32, authorizations: [Api.Authorization]) {
                self.authorizationTtlDays = authorizationTtlDays
                self.authorizations = authorizations
            }
        }
        case authorizations(Cons_authorizations)

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
        public class Cons_autoDownloadSettings {
            public var low: Api.AutoDownloadSettings
            public var medium: Api.AutoDownloadSettings
            public var high: Api.AutoDownloadSettings
            public init(low: Api.AutoDownloadSettings, medium: Api.AutoDownloadSettings, high: Api.AutoDownloadSettings) {
                self.low = low
                self.medium = medium
                self.high = high
            }
        }
        case autoDownloadSettings(Cons_autoDownloadSettings)

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
        public class Cons_autoSaveSettings {
            public var usersSettings: Api.AutoSaveSettings
            public var chatsSettings: Api.AutoSaveSettings
            public var broadcastsSettings: Api.AutoSaveSettings
            public var exceptions: [Api.AutoSaveException]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(usersSettings: Api.AutoSaveSettings, chatsSettings: Api.AutoSaveSettings, broadcastsSettings: Api.AutoSaveSettings, exceptions: [Api.AutoSaveException], chats: [Api.Chat], users: [Api.User]) {
                self.usersSettings = usersSettings
                self.chatsSettings = chatsSettings
                self.broadcastsSettings = broadcastsSettings
                self.exceptions = exceptions
                self.chats = chats
                self.users = users
            }
        }
        case autoSaveSettings(Cons_autoSaveSettings)

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
        public class Cons_businessChatLinks {
            public var links: [Api.BusinessChatLink]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(links: [Api.BusinessChatLink], chats: [Api.Chat], users: [Api.User]) {
                self.links = links
                self.chats = chats
                self.users = users
            }
        }
        case businessChatLinks(Cons_businessChatLinks)

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
        public class Cons_chatThemes {
            public var flags: Int32
            public var hash: Int64
            public var themes: [Api.ChatTheme]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var nextOffset: String?
            public init(flags: Int32, hash: Int64, themes: [Api.ChatTheme], chats: [Api.Chat], users: [Api.User], nextOffset: String?) {
                self.flags = flags
                self.hash = hash
                self.themes = themes
                self.chats = chats
                self.users = users
                self.nextOffset = nextOffset
            }
        }
        case chatThemes(Cons_chatThemes)
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
        public class Cons_connectedBots {
            public var connectedBots: [Api.ConnectedBot]
            public var users: [Api.User]
            public init(connectedBots: [Api.ConnectedBot], users: [Api.User]) {
                self.connectedBots = connectedBots
                self.users = users
            }
        }
        case connectedBots(Cons_connectedBots)

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
        public class Cons_contentSettings {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        case contentSettings(Cons_contentSettings)

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
        public class Cons_emailVerified {
            public var email: String
            public init(email: String) {
                self.email = email
            }
        }
        public class Cons_emailVerifiedLogin {
            public var email: String
            public var sentCode: Api.auth.SentCode
            public init(email: String, sentCode: Api.auth.SentCode) {
                self.email = email
                self.sentCode = sentCode
            }
        }
        case emailVerified(Cons_emailVerified)
        case emailVerifiedLogin(Cons_emailVerifiedLogin)

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
        public class Cons_emojiStatuses {
            public var hash: Int64
            public var statuses: [Api.EmojiStatus]
            public init(hash: Int64, statuses: [Api.EmojiStatus]) {
                self.hash = hash
                self.statuses = statuses
            }
        }
        case emojiStatuses(Cons_emojiStatuses)
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
        public class Cons_paidMessagesRevenue {
            public var starsAmount: Int64
            public init(starsAmount: Int64) {
                self.starsAmount = starsAmount
            }
        }
        case paidMessagesRevenue(Cons_paidMessagesRevenue)

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
        public class Cons_passkeyRegistrationOptions {
            public var options: Api.DataJSON
            public init(options: Api.DataJSON) {
                self.options = options
            }
        }
        case passkeyRegistrationOptions(Cons_passkeyRegistrationOptions)

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
        public class Cons_passkeys {
            public var passkeys: [Api.Passkey]
            public init(passkeys: [Api.Passkey]) {
                self.passkeys = passkeys
            }
        }
        case passkeys(Cons_passkeys)

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
        public class Cons_password {
            public var flags: Int32
            public var currentAlgo: Api.PasswordKdfAlgo?
            public var srpB: Buffer?
            public var srpId: Int64?
            public var hint: String?
            public var emailUnconfirmedPattern: String?
            public var newAlgo: Api.PasswordKdfAlgo
            public var newSecureAlgo: Api.SecurePasswordKdfAlgo
            public var secureRandom: Buffer
            public var pendingResetDate: Int32?
            public var loginEmailPattern: String?
            public init(flags: Int32, currentAlgo: Api.PasswordKdfAlgo?, srpB: Buffer?, srpId: Int64?, hint: String?, emailUnconfirmedPattern: String?, newAlgo: Api.PasswordKdfAlgo, newSecureAlgo: Api.SecurePasswordKdfAlgo, secureRandom: Buffer, pendingResetDate: Int32?, loginEmailPattern: String?) {
                self.flags = flags
                self.currentAlgo = currentAlgo
                self.srpB = srpB
                self.srpId = srpId
                self.hint = hint
                self.emailUnconfirmedPattern = emailUnconfirmedPattern
                self.newAlgo = newAlgo
                self.newSecureAlgo = newSecureAlgo
                self.secureRandom = secureRandom
                self.pendingResetDate = pendingResetDate
                self.loginEmailPattern = loginEmailPattern
            }
        }
        case password(Cons_password)

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
        public class Cons_passwordInputSettings {
            public var flags: Int32
            public var newAlgo: Api.PasswordKdfAlgo?
            public var newPasswordHash: Buffer?
            public var hint: String?
            public var email: String?
            public var newSecureSettings: Api.SecureSecretSettings?
            public init(flags: Int32, newAlgo: Api.PasswordKdfAlgo?, newPasswordHash: Buffer?, hint: String?, email: String?, newSecureSettings: Api.SecureSecretSettings?) {
                self.flags = flags
                self.newAlgo = newAlgo
                self.newPasswordHash = newPasswordHash
                self.hint = hint
                self.email = email
                self.newSecureSettings = newSecureSettings
            }
        }
        case passwordInputSettings(Cons_passwordInputSettings)

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
        public class Cons_passwordSettings {
            public var flags: Int32
            public var email: String?
            public var secureSettings: Api.SecureSecretSettings?
            public init(flags: Int32, email: String?, secureSettings: Api.SecureSecretSettings?) {
                self.flags = flags
                self.email = email
                self.secureSettings = secureSettings
            }
        }
        case passwordSettings(Cons_passwordSettings)

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
        public class Cons_privacyRules {
            public var rules: [Api.PrivacyRule]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(rules: [Api.PrivacyRule], chats: [Api.Chat], users: [Api.User]) {
                self.rules = rules
                self.chats = chats
                self.users = users
            }
        }
        case privacyRules(Cons_privacyRules)

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
        public class Cons_resetPasswordFailedWait {
            public var retryDate: Int32
            public init(retryDate: Int32) {
                self.retryDate = retryDate
            }
        }
        public class Cons_resetPasswordRequestedWait {
            public var untilDate: Int32
            public init(untilDate: Int32) {
                self.untilDate = untilDate
            }
        }
        case resetPasswordFailedWait(Cons_resetPasswordFailedWait)
        case resetPasswordOk
        case resetPasswordRequestedWait(Cons_resetPasswordRequestedWait)

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
        public class Cons_resolvedBusinessChatLinks {
            public var flags: Int32
            public var peer: Api.Peer
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, peer: Api.Peer, message: String, entities: [Api.MessageEntity]?, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.peer = peer
                self.message = message
                self.entities = entities
                self.chats = chats
                self.users = users
            }
        }
        case resolvedBusinessChatLinks(Cons_resolvedBusinessChatLinks)

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
