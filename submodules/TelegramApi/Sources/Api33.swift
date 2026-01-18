public extension Api.help {
    enum AppUpdate: TypeConstructorDescription {
        public class Cons_appUpdate {
            public var flags: Int32
            public var id: Int32
            public var version: String
            public var text: String
            public var entities: [Api.MessageEntity]
            public var document: Api.Document?
            public var url: String?
            public var sticker: Api.Document?
            public init(flags: Int32, id: Int32, version: String, text: String, entities: [Api.MessageEntity], document: Api.Document?, url: String?, sticker: Api.Document?) {
                self.flags = flags
                self.id = id
                self.version = version
                self.text = text
                self.entities = entities
                self.document = document
                self.url = url
                self.sticker = sticker
            }
        }
        case appUpdate(Cons_appUpdate)
        case noAppUpdate

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

        public static func parse_appUpdate(_ reader: BufferReader) -> AppUpdate? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_noAppUpdate(_ reader: BufferReader) -> AppUpdate? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum CountriesList: TypeConstructorDescription {
        public class Cons_countriesList {
            public var countries: [Api.help.Country]
            public var hash: Int32
            public init(countries: [Api.help.Country], hash: Int32) {
                self.countries = countries
                self.hash = hash
            }
        }
        case countriesList(Cons_countriesList)
        case countriesListNotModified

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

        public static func parse_countriesList(_ reader: BufferReader) -> CountriesList? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_countriesListNotModified(_ reader: BufferReader) -> CountriesList? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum Country: TypeConstructorDescription {
        public class Cons_country {
            public var flags: Int32
            public var iso2: String
            public var defaultName: String
            public var name: String?
            public var countryCodes: [Api.help.CountryCode]
            public init(flags: Int32, iso2: String, defaultName: String, name: String?, countryCodes: [Api.help.CountryCode]) {
                self.flags = flags
                self.iso2 = iso2
                self.defaultName = defaultName
                self.name = name
                self.countryCodes = countryCodes
            }
        }
        case country(Cons_country)

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

        public static func parse_country(_ reader: BufferReader) -> Country? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum CountryCode: TypeConstructorDescription {
        public class Cons_countryCode {
            public var flags: Int32
            public var countryCode: String
            public var prefixes: [String]?
            public var patterns: [String]?
            public init(flags: Int32, countryCode: String, prefixes: [String]?, patterns: [String]?) {
                self.flags = flags
                self.countryCode = countryCode
                self.prefixes = prefixes
                self.patterns = patterns
            }
        }
        case countryCode(Cons_countryCode)

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

        public static func parse_countryCode(_ reader: BufferReader) -> CountryCode? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum DeepLinkInfo: TypeConstructorDescription {
        public class Cons_deepLinkInfo {
            public var flags: Int32
            public var message: String
            public var entities: [Api.MessageEntity]?
            public init(flags: Int32, message: String, entities: [Api.MessageEntity]?) {
                self.flags = flags
                self.message = message
                self.entities = entities
            }
        }
        case deepLinkInfo(Cons_deepLinkInfo)
        case deepLinkInfoEmpty

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

        public static func parse_deepLinkInfo(_ reader: BufferReader) -> DeepLinkInfo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_deepLinkInfoEmpty(_ reader: BufferReader) -> DeepLinkInfo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum InviteText: TypeConstructorDescription {
        public class Cons_inviteText {
            public var message: String
            public init(message: String) {
                self.message = message
            }
        }
        case inviteText(Cons_inviteText)

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

        public static func parse_inviteText(_ reader: BufferReader) -> InviteText? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum PassportConfig: TypeConstructorDescription {
        public class Cons_passportConfig {
            public var hash: Int32
            public var countriesLangs: Api.DataJSON
            public init(hash: Int32, countriesLangs: Api.DataJSON) {
                self.hash = hash
                self.countriesLangs = countriesLangs
            }
        }
        case passportConfig(Cons_passportConfig)
        case passportConfigNotModified

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

        public static func parse_passportConfig(_ reader: BufferReader) -> PassportConfig? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_passportConfigNotModified(_ reader: BufferReader) -> PassportConfig? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum PeerColorOption: TypeConstructorDescription {
        public class Cons_peerColorOption {
            public var flags: Int32
            public var colorId: Int32
            public var colors: Api.help.PeerColorSet?
            public var darkColors: Api.help.PeerColorSet?
            public var channelMinLevel: Int32?
            public var groupMinLevel: Int32?
            public init(flags: Int32, colorId: Int32, colors: Api.help.PeerColorSet?, darkColors: Api.help.PeerColorSet?, channelMinLevel: Int32?, groupMinLevel: Int32?) {
                self.flags = flags
                self.colorId = colorId
                self.colors = colors
                self.darkColors = darkColors
                self.channelMinLevel = channelMinLevel
                self.groupMinLevel = groupMinLevel
            }
        }
        case peerColorOption(Cons_peerColorOption)

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

        public static func parse_peerColorOption(_ reader: BufferReader) -> PeerColorOption? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum PeerColorSet: TypeConstructorDescription {
        public class Cons_peerColorProfileSet {
            public var paletteColors: [Int32]
            public var bgColors: [Int32]
            public var storyColors: [Int32]
            public init(paletteColors: [Int32], bgColors: [Int32], storyColors: [Int32]) {
                self.paletteColors = paletteColors
                self.bgColors = bgColors
                self.storyColors = storyColors
            }
        }
        public class Cons_peerColorSet {
            public var colors: [Int32]
            public init(colors: [Int32]) {
                self.colors = colors
            }
        }
        case peerColorProfileSet(Cons_peerColorProfileSet)
        case peerColorSet(Cons_peerColorSet)

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

        public static func parse_peerColorProfileSet(_ reader: BufferReader) -> PeerColorSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_peerColorSet(_ reader: BufferReader) -> PeerColorSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum PeerColors: TypeConstructorDescription {
        public class Cons_peerColors {
            public var hash: Int32
            public var colors: [Api.help.PeerColorOption]
            public init(hash: Int32, colors: [Api.help.PeerColorOption]) {
                self.hash = hash
                self.colors = colors
            }
        }
        case peerColors(Cons_peerColors)
        case peerColorsNotModified

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

        public static func parse_peerColors(_ reader: BufferReader) -> PeerColors? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_peerColorsNotModified(_ reader: BufferReader) -> PeerColors? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum PremiumPromo: TypeConstructorDescription {
        public class Cons_premiumPromo {
            public var statusText: String
            public var statusEntities: [Api.MessageEntity]
            public var videoSections: [String]
            public var videos: [Api.Document]
            public var periodOptions: [Api.PremiumSubscriptionOption]
            public var users: [Api.User]
            public init(statusText: String, statusEntities: [Api.MessageEntity], videoSections: [String], videos: [Api.Document], periodOptions: [Api.PremiumSubscriptionOption], users: [Api.User]) {
                self.statusText = statusText
                self.statusEntities = statusEntities
                self.videoSections = videoSections
                self.videos = videos
                self.periodOptions = periodOptions
                self.users = users
            }
        }
        case premiumPromo(Cons_premiumPromo)

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

        public static func parse_premiumPromo(_ reader: BufferReader) -> PremiumPromo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum PromoData: TypeConstructorDescription {
        public class Cons_promoData {
            public var flags: Int32
            public var expires: Int32
            public var peer: Api.Peer?
            public var psaType: String?
            public var psaMessage: String?
            public var pendingSuggestions: [String]
            public var dismissedSuggestions: [String]
            public var customPendingSuggestion: Api.PendingSuggestion?
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, expires: Int32, peer: Api.Peer?, psaType: String?, psaMessage: String?, pendingSuggestions: [String], dismissedSuggestions: [String], customPendingSuggestion: Api.PendingSuggestion?, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.expires = expires
                self.peer = peer
                self.psaType = psaType
                self.psaMessage = psaMessage
                self.pendingSuggestions = pendingSuggestions
                self.dismissedSuggestions = dismissedSuggestions
                self.customPendingSuggestion = customPendingSuggestion
                self.chats = chats
                self.users = users
            }
        }
        public class Cons_promoDataEmpty {
            public var expires: Int32
            public init(expires: Int32) {
                self.expires = expires
            }
        }
        case promoData(Cons_promoData)
        case promoDataEmpty(Cons_promoDataEmpty)

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

        public static func parse_promoData(_ reader: BufferReader) -> PromoData? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_promoDataEmpty(_ reader: BufferReader) -> PromoData? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum RecentMeUrls: TypeConstructorDescription {
        public class Cons_recentMeUrls {
            public var urls: [Api.RecentMeUrl]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(urls: [Api.RecentMeUrl], chats: [Api.Chat], users: [Api.User]) {
                self.urls = urls
                self.chats = chats
                self.users = users
            }
        }
        case recentMeUrls(Cons_recentMeUrls)

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

        public static func parse_recentMeUrls(_ reader: BufferReader) -> RecentMeUrls? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum Support: TypeConstructorDescription {
        public class Cons_support {
            public var phoneNumber: String
            public var user: Api.User
            public init(phoneNumber: String, user: Api.User) {
                self.phoneNumber = phoneNumber
                self.user = user
            }
        }
        case support(Cons_support)

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

        public static func parse_support(_ reader: BufferReader) -> Support? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum SupportName: TypeConstructorDescription {
        public class Cons_supportName {
            public var name: String
            public init(name: String) {
                self.name = name
            }
        }
        case supportName(Cons_supportName)

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

        public static func parse_supportName(_ reader: BufferReader) -> SupportName? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum TermsOfService: TypeConstructorDescription {
        public class Cons_termsOfService {
            public var flags: Int32
            public var id: Api.DataJSON
            public var text: String
            public var entities: [Api.MessageEntity]
            public var minAgeConfirm: Int32?
            public init(flags: Int32, id: Api.DataJSON, text: String, entities: [Api.MessageEntity], minAgeConfirm: Int32?) {
                self.flags = flags
                self.id = id
                self.text = text
                self.entities = entities
                self.minAgeConfirm = minAgeConfirm
            }
        }
        case termsOfService(Cons_termsOfService)

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

        public static func parse_termsOfService(_ reader: BufferReader) -> TermsOfService? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum TermsOfServiceUpdate: TypeConstructorDescription {
        public class Cons_termsOfServiceUpdate {
            public var expires: Int32
            public var termsOfService: Api.help.TermsOfService
            public init(expires: Int32, termsOfService: Api.help.TermsOfService) {
                self.expires = expires
                self.termsOfService = termsOfService
            }
        }
        public class Cons_termsOfServiceUpdateEmpty {
            public var expires: Int32
            public init(expires: Int32) {
                self.expires = expires
            }
        }
        case termsOfServiceUpdate(Cons_termsOfServiceUpdate)
        case termsOfServiceUpdateEmpty(Cons_termsOfServiceUpdateEmpty)

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

        public static func parse_termsOfServiceUpdate(_ reader: BufferReader) -> TermsOfServiceUpdate? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_termsOfServiceUpdateEmpty(_ reader: BufferReader) -> TermsOfServiceUpdate? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum TimezonesList: TypeConstructorDescription {
        public class Cons_timezonesList {
            public var timezones: [Api.Timezone]
            public var hash: Int32
            public init(timezones: [Api.Timezone], hash: Int32) {
                self.timezones = timezones
                self.hash = hash
            }
        }
        case timezonesList(Cons_timezonesList)
        case timezonesListNotModified

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

        public static func parse_timezonesList(_ reader: BufferReader) -> TimezonesList? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_timezonesListNotModified(_ reader: BufferReader) -> TimezonesList? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum UserInfo: TypeConstructorDescription {
        public class Cons_userInfo {
            public var message: String
            public var entities: [Api.MessageEntity]
            public var author: String
            public var date: Int32
            public init(message: String, entities: [Api.MessageEntity], author: String, date: Int32) {
                self.message = message
                self.entities = entities
                self.author = author
                self.date = date
            }
        }
        case userInfo(Cons_userInfo)
        case userInfoEmpty

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

        public static func parse_userInfo(_ reader: BufferReader) -> UserInfo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_userInfoEmpty(_ reader: BufferReader) -> UserInfo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum AffectedFoundMessages: TypeConstructorDescription {
        public class Cons_affectedFoundMessages {
            public var pts: Int32
            public var ptsCount: Int32
            public var offset: Int32
            public var messages: [Int32]
            public init(pts: Int32, ptsCount: Int32, offset: Int32, messages: [Int32]) {
                self.pts = pts
                self.ptsCount = ptsCount
                self.offset = offset
                self.messages = messages
            }
        }
        case affectedFoundMessages(Cons_affectedFoundMessages)

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

        public static func parse_affectedFoundMessages(_ reader: BufferReader) -> AffectedFoundMessages? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum AffectedHistory: TypeConstructorDescription {
        public class Cons_affectedHistory {
            public var pts: Int32
            public var ptsCount: Int32
            public var offset: Int32
            public init(pts: Int32, ptsCount: Int32, offset: Int32) {
                self.pts = pts
                self.ptsCount = ptsCount
                self.offset = offset
            }
        }
        case affectedHistory(Cons_affectedHistory)

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

        public static func parse_affectedHistory(_ reader: BufferReader) -> AffectedHistory? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum AffectedMessages: TypeConstructorDescription {
        public class Cons_affectedMessages {
            public var pts: Int32
            public var ptsCount: Int32
            public init(pts: Int32, ptsCount: Int32) {
                self.pts = pts
                self.ptsCount = ptsCount
            }
        }
        case affectedMessages(Cons_affectedMessages)

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

        public static func parse_affectedMessages(_ reader: BufferReader) -> AffectedMessages? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
