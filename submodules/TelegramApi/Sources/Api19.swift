public extension Api {
    indirect enum PageCaption: TypeConstructorDescription {
        public class Cons_pageCaption {
            public var text: Api.RichText
            public var credit: Api.RichText
            public init(text: Api.RichText, credit: Api.RichText) {
                self.text = text
                self.credit = credit
            }
        }
        case pageCaption(Cons_pageCaption)

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

        public static func parse_pageCaption(_ reader: BufferReader) -> PageCaption? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum PageListItem: TypeConstructorDescription {
        public class Cons_pageListItemBlocks {
            public var blocks: [Api.PageBlock]
            public init(blocks: [Api.PageBlock]) {
                self.blocks = blocks
            }
        }
        public class Cons_pageListItemText {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        case pageListItemBlocks(Cons_pageListItemBlocks)
        case pageListItemText(Cons_pageListItemText)

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

        public static func parse_pageListItemBlocks(_ reader: BufferReader) -> PageListItem? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageListItemText(_ reader: BufferReader) -> PageListItem? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum PageListOrderedItem: TypeConstructorDescription {
        public class Cons_pageListOrderedItemBlocks {
            public var num: String
            public var blocks: [Api.PageBlock]
            public init(num: String, blocks: [Api.PageBlock]) {
                self.num = num
                self.blocks = blocks
            }
        }
        public class Cons_pageListOrderedItemText {
            public var num: String
            public var text: Api.RichText
            public init(num: String, text: Api.RichText) {
                self.num = num
                self.text = text
            }
        }
        case pageListOrderedItemBlocks(Cons_pageListOrderedItemBlocks)
        case pageListOrderedItemText(Cons_pageListOrderedItemText)

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

        public static func parse_pageListOrderedItemBlocks(_ reader: BufferReader) -> PageListOrderedItem? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageListOrderedItemText(_ reader: BufferReader) -> PageListOrderedItem? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PageRelatedArticle: TypeConstructorDescription {
        public class Cons_pageRelatedArticle {
            public var flags: Int32
            public var url: String
            public var webpageId: Int64
            public var title: String?
            public var description: String?
            public var photoId: Int64?
            public var author: String?
            public var publishedDate: Int32?
            public init(flags: Int32, url: String, webpageId: Int64, title: String?, description: String?, photoId: Int64?, author: String?, publishedDate: Int32?) {
                self.flags = flags
                self.url = url
                self.webpageId = webpageId
                self.title = title
                self.description = description
                self.photoId = photoId
                self.author = author
                self.publishedDate = publishedDate
            }
        }
        case pageRelatedArticle(Cons_pageRelatedArticle)

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

        public static func parse_pageRelatedArticle(_ reader: BufferReader) -> PageRelatedArticle? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum PageTableCell: TypeConstructorDescription {
        public class Cons_pageTableCell {
            public var flags: Int32
            public var text: Api.RichText?
            public var colspan: Int32?
            public var rowspan: Int32?
            public init(flags: Int32, text: Api.RichText?, colspan: Int32?, rowspan: Int32?) {
                self.flags = flags
                self.text = text
                self.colspan = colspan
                self.rowspan = rowspan
            }
        }
        case pageTableCell(Cons_pageTableCell)

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

        public static func parse_pageTableCell(_ reader: BufferReader) -> PageTableCell? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PageTableRow: TypeConstructorDescription {
        public class Cons_pageTableRow {
            public var cells: [Api.PageTableCell]
            public init(cells: [Api.PageTableCell]) {
                self.cells = cells
            }
        }
        case pageTableRow(Cons_pageTableRow)

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

        public static func parse_pageTableRow(_ reader: BufferReader) -> PageTableRow? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum PaidReactionPrivacy: TypeConstructorDescription {
        public class Cons_paidReactionPrivacyPeer {
            public var peer: Api.InputPeer
            public init(peer: Api.InputPeer) {
                self.peer = peer
            }
        }
        case paidReactionPrivacyAnonymous
        case paidReactionPrivacyDefault
        case paidReactionPrivacyPeer(Cons_paidReactionPrivacyPeer)

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

        public static func parse_paidReactionPrivacyAnonymous(_ reader: BufferReader) -> PaidReactionPrivacy? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_paidReactionPrivacyDefault(_ reader: BufferReader) -> PaidReactionPrivacy? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_paidReactionPrivacyPeer(_ reader: BufferReader) -> PaidReactionPrivacy? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Passkey: TypeConstructorDescription {
        public class Cons_passkey {
            public var flags: Int32
            public var id: String
            public var name: String
            public var date: Int32
            public var softwareEmojiId: Int64?
            public var lastUsageDate: Int32?
            public init(flags: Int32, id: String, name: String, date: Int32, softwareEmojiId: Int64?, lastUsageDate: Int32?) {
                self.flags = flags
                self.id = id
                self.name = name
                self.date = date
                self.softwareEmojiId = softwareEmojiId
                self.lastUsageDate = lastUsageDate
            }
        }
        case passkey(Cons_passkey)

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

        public static func parse_passkey(_ reader: BufferReader) -> Passkey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PasswordKdfAlgo: TypeConstructorDescription {
        public class Cons_passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow {
            public var salt1: Buffer
            public var salt2: Buffer
            public var g: Int32
            public var p: Buffer
            public init(salt1: Buffer, salt2: Buffer, g: Int32, p: Buffer) {
                self.salt1 = salt1
                self.salt2 = salt2
                self.g = g
                self.p = p
            }
        }
        case passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(Cons_passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow)
        case passwordKdfAlgoUnknown

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

        public static func parse_passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(_ reader: BufferReader) -> PasswordKdfAlgo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_passwordKdfAlgoUnknown(_ reader: BufferReader) -> PasswordKdfAlgo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PaymentCharge: TypeConstructorDescription {
        public class Cons_paymentCharge {
            public var id: String
            public var providerChargeId: String
            public init(id: String, providerChargeId: String) {
                self.id = id
                self.providerChargeId = providerChargeId
            }
        }
        case paymentCharge(Cons_paymentCharge)

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

        public static func parse_paymentCharge(_ reader: BufferReader) -> PaymentCharge? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PaymentFormMethod: TypeConstructorDescription {
        public class Cons_paymentFormMethod {
            public var url: String
            public var title: String
            public init(url: String, title: String) {
                self.url = url
                self.title = title
            }
        }
        case paymentFormMethod(Cons_paymentFormMethod)

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

        public static func parse_paymentFormMethod(_ reader: BufferReader) -> PaymentFormMethod? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PaymentRequestedInfo: TypeConstructorDescription {
        public class Cons_paymentRequestedInfo {
            public var flags: Int32
            public var name: String?
            public var phone: String?
            public var email: String?
            public var shippingAddress: Api.PostAddress?
            public init(flags: Int32, name: String?, phone: String?, email: String?, shippingAddress: Api.PostAddress?) {
                self.flags = flags
                self.name = name
                self.phone = phone
                self.email = email
                self.shippingAddress = shippingAddress
            }
        }
        case paymentRequestedInfo(Cons_paymentRequestedInfo)

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

        public static func parse_paymentRequestedInfo(_ reader: BufferReader) -> PaymentRequestedInfo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PaymentSavedCredentials: TypeConstructorDescription {
        public class Cons_paymentSavedCredentialsCard {
            public var id: String
            public var title: String
            public init(id: String, title: String) {
                self.id = id
                self.title = title
            }
        }
        case paymentSavedCredentialsCard(Cons_paymentSavedCredentialsCard)

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

        public static func parse_paymentSavedCredentialsCard(_ reader: BufferReader) -> PaymentSavedCredentials? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Peer: TypeConstructorDescription {
        public class Cons_peerChannel {
            public var channelId: Int64
            public init(channelId: Int64) {
                self.channelId = channelId
            }
        }
        public class Cons_peerChat {
            public var chatId: Int64
            public init(chatId: Int64) {
                self.chatId = chatId
            }
        }
        public class Cons_peerUser {
            public var userId: Int64
            public init(userId: Int64) {
                self.userId = userId
            }
        }
        case peerChannel(Cons_peerChannel)
        case peerChat(Cons_peerChat)
        case peerUser(Cons_peerUser)

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

        public static func parse_peerChannel(_ reader: BufferReader) -> Peer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_peerChat(_ reader: BufferReader) -> Peer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_peerUser(_ reader: BufferReader) -> Peer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PeerBlocked: TypeConstructorDescription {
        public class Cons_peerBlocked {
            public var peerId: Api.Peer
            public var date: Int32
            public init(peerId: Api.Peer, date: Int32) {
                self.peerId = peerId
                self.date = date
            }
        }
        case peerBlocked(Cons_peerBlocked)

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

        public static func parse_peerBlocked(_ reader: BufferReader) -> PeerBlocked? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PeerColor: TypeConstructorDescription {
        public class Cons_inputPeerColorCollectible {
            public var collectibleId: Int64
            public init(collectibleId: Int64) {
                self.collectibleId = collectibleId
            }
        }
        public class Cons_peerColor {
            public var flags: Int32
            public var color: Int32?
            public var backgroundEmojiId: Int64?
            public init(flags: Int32, color: Int32?, backgroundEmojiId: Int64?) {
                self.flags = flags
                self.color = color
                self.backgroundEmojiId = backgroundEmojiId
            }
        }
        public class Cons_peerColorCollectible {
            public var flags: Int32
            public var collectibleId: Int64
            public var giftEmojiId: Int64
            public var backgroundEmojiId: Int64
            public var accentColor: Int32
            public var colors: [Int32]
            public var darkAccentColor: Int32?
            public var darkColors: [Int32]?
            public init(flags: Int32, collectibleId: Int64, giftEmojiId: Int64, backgroundEmojiId: Int64, accentColor: Int32, colors: [Int32], darkAccentColor: Int32?, darkColors: [Int32]?) {
                self.flags = flags
                self.collectibleId = collectibleId
                self.giftEmojiId = giftEmojiId
                self.backgroundEmojiId = backgroundEmojiId
                self.accentColor = accentColor
                self.colors = colors
                self.darkAccentColor = darkAccentColor
                self.darkColors = darkColors
            }
        }
        case inputPeerColorCollectible(Cons_inputPeerColorCollectible)
        case peerColor(Cons_peerColor)
        case peerColorCollectible(Cons_peerColorCollectible)

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

        public static func parse_inputPeerColorCollectible(_ reader: BufferReader) -> PeerColor? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_peerColor(_ reader: BufferReader) -> PeerColor? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_peerColorCollectible(_ reader: BufferReader) -> PeerColor? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PeerLocated: TypeConstructorDescription {
        public class Cons_peerLocated {
            public var peer: Api.Peer
            public var expires: Int32
            public var distance: Int32
            public init(peer: Api.Peer, expires: Int32, distance: Int32) {
                self.peer = peer
                self.expires = expires
                self.distance = distance
            }
        }
        public class Cons_peerSelfLocated {
            public var expires: Int32
            public init(expires: Int32) {
                self.expires = expires
            }
        }
        case peerLocated(Cons_peerLocated)
        case peerSelfLocated(Cons_peerSelfLocated)

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

        public static func parse_peerLocated(_ reader: BufferReader) -> PeerLocated? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_peerSelfLocated(_ reader: BufferReader) -> PeerLocated? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PeerNotifySettings: TypeConstructorDescription {
        public class Cons_peerNotifySettings {
            public var flags: Int32
            public var showPreviews: Api.Bool?
            public var silent: Api.Bool?
            public var muteUntil: Int32?
            public var iosSound: Api.NotificationSound?
            public var androidSound: Api.NotificationSound?
            public var otherSound: Api.NotificationSound?
            public var storiesMuted: Api.Bool?
            public var storiesHideSender: Api.Bool?
            public var storiesIosSound: Api.NotificationSound?
            public var storiesAndroidSound: Api.NotificationSound?
            public var storiesOtherSound: Api.NotificationSound?
            public init(flags: Int32, showPreviews: Api.Bool?, silent: Api.Bool?, muteUntil: Int32?, iosSound: Api.NotificationSound?, androidSound: Api.NotificationSound?, otherSound: Api.NotificationSound?, storiesMuted: Api.Bool?, storiesHideSender: Api.Bool?, storiesIosSound: Api.NotificationSound?, storiesAndroidSound: Api.NotificationSound?, storiesOtherSound: Api.NotificationSound?) {
                self.flags = flags
                self.showPreviews = showPreviews
                self.silent = silent
                self.muteUntil = muteUntil
                self.iosSound = iosSound
                self.androidSound = androidSound
                self.otherSound = otherSound
                self.storiesMuted = storiesMuted
                self.storiesHideSender = storiesHideSender
                self.storiesIosSound = storiesIosSound
                self.storiesAndroidSound = storiesAndroidSound
                self.storiesOtherSound = storiesOtherSound
            }
        }
        case peerNotifySettings(Cons_peerNotifySettings)

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

        public static func parse_peerNotifySettings(_ reader: BufferReader) -> PeerNotifySettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PeerSettings: TypeConstructorDescription {
        public class Cons_peerSettings {
            public var flags: Int32
            public var geoDistance: Int32?
            public var requestChatTitle: String?
            public var requestChatDate: Int32?
            public var businessBotId: Int64?
            public var businessBotManageUrl: String?
            public var chargePaidMessageStars: Int64?
            public var registrationMonth: String?
            public var phoneCountry: String?
            public var nameChangeDate: Int32?
            public var photoChangeDate: Int32?
            public init(flags: Int32, geoDistance: Int32?, requestChatTitle: String?, requestChatDate: Int32?, businessBotId: Int64?, businessBotManageUrl: String?, chargePaidMessageStars: Int64?, registrationMonth: String?, phoneCountry: String?, nameChangeDate: Int32?, photoChangeDate: Int32?) {
                self.flags = flags
                self.geoDistance = geoDistance
                self.requestChatTitle = requestChatTitle
                self.requestChatDate = requestChatDate
                self.businessBotId = businessBotId
                self.businessBotManageUrl = businessBotManageUrl
                self.chargePaidMessageStars = chargePaidMessageStars
                self.registrationMonth = registrationMonth
                self.phoneCountry = phoneCountry
                self.nameChangeDate = nameChangeDate
                self.photoChangeDate = photoChangeDate
            }
        }
        case peerSettings(Cons_peerSettings)

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

        public static func parse_peerSettings(_ reader: BufferReader) -> PeerSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PeerStories: TypeConstructorDescription {
        public class Cons_peerStories {
            public var flags: Int32
            public var peer: Api.Peer
            public var maxReadId: Int32?
            public var stories: [Api.StoryItem]
            public init(flags: Int32, peer: Api.Peer, maxReadId: Int32?, stories: [Api.StoryItem]) {
                self.flags = flags
                self.peer = peer
                self.maxReadId = maxReadId
                self.stories = stories
            }
        }
        case peerStories(Cons_peerStories)

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

        public static func parse_peerStories(_ reader: BufferReader) -> PeerStories? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PendingSuggestion: TypeConstructorDescription {
        public class Cons_pendingSuggestion {
            public var suggestion: String
            public var title: Api.TextWithEntities
            public var description: Api.TextWithEntities
            public var url: String
            public init(suggestion: String, title: Api.TextWithEntities, description: Api.TextWithEntities, url: String) {
                self.suggestion = suggestion
                self.title = title
                self.description = description
                self.url = url
            }
        }
        case pendingSuggestion(Cons_pendingSuggestion)

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

        public static func parse_pendingSuggestion(_ reader: BufferReader) -> PendingSuggestion? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PhoneCall: TypeConstructorDescription {
        public class Cons_phoneCall {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var date: Int32
            public var adminId: Int64
            public var participantId: Int64
            public var gAOrB: Buffer
            public var keyFingerprint: Int64
            public var `protocol`: Api.PhoneCallProtocol
            public var connections: [Api.PhoneConnection]
            public var startDate: Int32
            public var customParameters: Api.DataJSON?
            public init(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gAOrB: Buffer, keyFingerprint: Int64, `protocol`: Api.PhoneCallProtocol, connections: [Api.PhoneConnection], startDate: Int32, customParameters: Api.DataJSON?) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.date = date
                self.adminId = adminId
                self.participantId = participantId
                self.gAOrB = gAOrB
                self.keyFingerprint = keyFingerprint
                self.`protocol` = `protocol`
                self.connections = connections
                self.startDate = startDate
                self.customParameters = customParameters
            }
        }
        public class Cons_phoneCallAccepted {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var date: Int32
            public var adminId: Int64
            public var participantId: Int64
            public var gB: Buffer
            public var `protocol`: Api.PhoneCallProtocol
            public init(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gB: Buffer, `protocol`: Api.PhoneCallProtocol) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.date = date
                self.adminId = adminId
                self.participantId = participantId
                self.gB = gB
                self.`protocol` = `protocol`
            }
        }
        public class Cons_phoneCallDiscarded {
            public var flags: Int32
            public var id: Int64
            public var reason: Api.PhoneCallDiscardReason?
            public var duration: Int32?
            public init(flags: Int32, id: Int64, reason: Api.PhoneCallDiscardReason?, duration: Int32?) {
                self.flags = flags
                self.id = id
                self.reason = reason
                self.duration = duration
            }
        }
        public class Cons_phoneCallEmpty {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
        }
        public class Cons_phoneCallRequested {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var date: Int32
            public var adminId: Int64
            public var participantId: Int64
            public var gAHash: Buffer
            public var `protocol`: Api.PhoneCallProtocol
            public init(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gAHash: Buffer, `protocol`: Api.PhoneCallProtocol) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.date = date
                self.adminId = adminId
                self.participantId = participantId
                self.gAHash = gAHash
                self.`protocol` = `protocol`
            }
        }
        public class Cons_phoneCallWaiting {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var date: Int32
            public var adminId: Int64
            public var participantId: Int64
            public var `protocol`: Api.PhoneCallProtocol
            public var receiveDate: Int32?
            public init(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, `protocol`: Api.PhoneCallProtocol, receiveDate: Int32?) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.date = date
                self.adminId = adminId
                self.participantId = participantId
                self.`protocol` = `protocol`
                self.receiveDate = receiveDate
            }
        }
        case phoneCall(Cons_phoneCall)
        case phoneCallAccepted(Cons_phoneCallAccepted)
        case phoneCallDiscarded(Cons_phoneCallDiscarded)
        case phoneCallEmpty(Cons_phoneCallEmpty)
        case phoneCallRequested(Cons_phoneCallRequested)
        case phoneCallWaiting(Cons_phoneCallWaiting)

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

        public static func parse_phoneCall(_ reader: BufferReader) -> PhoneCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_phoneCallAccepted(_ reader: BufferReader) -> PhoneCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_phoneCallDiscarded(_ reader: BufferReader) -> PhoneCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_phoneCallEmpty(_ reader: BufferReader) -> PhoneCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_phoneCallRequested(_ reader: BufferReader) -> PhoneCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_phoneCallWaiting(_ reader: BufferReader) -> PhoneCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
