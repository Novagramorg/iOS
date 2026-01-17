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
        case peerChannel(channelId: Int64)
        case peerChat(chatId: Int64)
        case peerUser(userId: Int64)

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
        case peerBlocked(peerId: Api.Peer, date: Int32)

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
        case inputPeerColorCollectible(collectibleId: Int64)
        case peerColor(flags: Int32, color: Int32?, backgroundEmojiId: Int64?)
        case peerColorCollectible(flags: Int32, collectibleId: Int64, giftEmojiId: Int64, backgroundEmojiId: Int64, accentColor: Int32, colors: [Int32], darkAccentColor: Int32?, darkColors: [Int32]?)

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
        case peerLocated(peer: Api.Peer, expires: Int32, distance: Int32)
        case peerSelfLocated(expires: Int32)

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
        case peerNotifySettings(flags: Int32, showPreviews: Api.Bool?, silent: Api.Bool?, muteUntil: Int32?, iosSound: Api.NotificationSound?, androidSound: Api.NotificationSound?, otherSound: Api.NotificationSound?, storiesMuted: Api.Bool?, storiesHideSender: Api.Bool?, storiesIosSound: Api.NotificationSound?, storiesAndroidSound: Api.NotificationSound?, storiesOtherSound: Api.NotificationSound?)

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
        case peerSettings(flags: Int32, geoDistance: Int32?, requestChatTitle: String?, requestChatDate: Int32?, businessBotId: Int64?, businessBotManageUrl: String?, chargePaidMessageStars: Int64?, registrationMonth: String?, phoneCountry: String?, nameChangeDate: Int32?, photoChangeDate: Int32?)

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
        case peerStories(flags: Int32, peer: Api.Peer, maxReadId: Int32?, stories: [Api.StoryItem])

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
        case pendingSuggestion(suggestion: String, title: Api.TextWithEntities, description: Api.TextWithEntities, url: String)

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
        case phoneCall(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gAOrB: Buffer, keyFingerprint: Int64, protocol: Api.PhoneCallProtocol, connections: [Api.PhoneConnection], startDate: Int32, customParameters: Api.DataJSON?)
        case phoneCallAccepted(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gB: Buffer, protocol: Api.PhoneCallProtocol)
        case phoneCallDiscarded(flags: Int32, id: Int64, reason: Api.PhoneCallDiscardReason?, duration: Int32?)
        case phoneCallEmpty(id: Int64)
        case phoneCallRequested(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gAHash: Buffer, protocol: Api.PhoneCallProtocol)
        case phoneCallWaiting(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, protocol: Api.PhoneCallProtocol, receiveDate: Int32?)

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
