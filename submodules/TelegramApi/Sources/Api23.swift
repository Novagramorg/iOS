public extension Api {
    enum RestrictionReason: TypeConstructorDescription {
        public class Cons_restrictionReason {
            public var platform: String
            public var reason: String
            public var text: String
            public init(platform: String, reason: String, text: String) {
                self.platform = platform
                self.reason = reason
                self.text = text
            }
        }
        case restrictionReason(Cons_restrictionReason)

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

        public static func parse_restrictionReason(_ reader: BufferReader) -> RestrictionReason? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum RichText: TypeConstructorDescription {
        public class Cons_textAnchor {
            public var text: Api.RichText
            public var name: String
            public init(text: Api.RichText, name: String) {
                self.text = text
                self.name = name
            }
        }
        public class Cons_textBold {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_textConcat {
            public var texts: [Api.RichText]
            public init(texts: [Api.RichText]) {
                self.texts = texts
            }
        }
        public class Cons_textEmail {
            public var text: Api.RichText
            public var email: String
            public init(text: Api.RichText, email: String) {
                self.text = text
                self.email = email
            }
        }
        public class Cons_textFixed {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_textImage {
            public var documentId: Int64
            public var w: Int32
            public var h: Int32
            public init(documentId: Int64, w: Int32, h: Int32) {
                self.documentId = documentId
                self.w = w
                self.h = h
            }
        }
        public class Cons_textItalic {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_textMarked {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_textPhone {
            public var text: Api.RichText
            public var phone: String
            public init(text: Api.RichText, phone: String) {
                self.text = text
                self.phone = phone
            }
        }
        public class Cons_textPlain {
            public var text: String
            public init(text: String) {
                self.text = text
            }
        }
        public class Cons_textStrike {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_textSubscript {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_textSuperscript {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_textUnderline {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
        }
        public class Cons_textUrl {
            public var text: Api.RichText
            public var url: String
            public var webpageId: Int64
            public init(text: Api.RichText, url: String, webpageId: Int64) {
                self.text = text
                self.url = url
                self.webpageId = webpageId
            }
        }
        case textAnchor(Cons_textAnchor)
        case textBold(Cons_textBold)
        case textConcat(Cons_textConcat)
        case textEmail(Cons_textEmail)
        case textEmpty
        case textFixed(Cons_textFixed)
        case textImage(Cons_textImage)
        case textItalic(Cons_textItalic)
        case textMarked(Cons_textMarked)
        case textPhone(Cons_textPhone)
        case textPlain(Cons_textPlain)
        case textStrike(Cons_textStrike)
        case textSubscript(Cons_textSubscript)
        case textSuperscript(Cons_textSuperscript)
        case textUnderline(Cons_textUnderline)
        case textUrl(Cons_textUrl)

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

        public static func parse_textAnchor(_ reader: BufferReader) -> RichText? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_textBold(_ reader: BufferReader) -> RichText? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_textConcat(_ reader: BufferReader) -> RichText? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_textEmail(_ reader: BufferReader) -> RichText? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_textEmpty(_ reader: BufferReader) -> RichText? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_textFixed(_ reader: BufferReader) -> RichText? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_textImage(_ reader: BufferReader) -> RichText? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_textItalic(_ reader: BufferReader) -> RichText? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_textMarked(_ reader: BufferReader) -> RichText? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_textPhone(_ reader: BufferReader) -> RichText? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_textPlain(_ reader: BufferReader) -> RichText? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_textStrike(_ reader: BufferReader) -> RichText? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_textSubscript(_ reader: BufferReader) -> RichText? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_textSuperscript(_ reader: BufferReader) -> RichText? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_textUnderline(_ reader: BufferReader) -> RichText? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_textUrl(_ reader: BufferReader) -> RichText? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SavedContact: TypeConstructorDescription {
        public class Cons_savedPhoneContact {
            public var phone: String
            public var firstName: String
            public var lastName: String
            public var date: Int32
            public init(phone: String, firstName: String, lastName: String, date: Int32) {
                self.phone = phone
                self.firstName = firstName
                self.lastName = lastName
                self.date = date
            }
        }
        case savedPhoneContact(Cons_savedPhoneContact)

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

        public static func parse_savedPhoneContact(_ reader: BufferReader) -> SavedContact? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum SavedDialog: TypeConstructorDescription {
        public class Cons_monoForumDialog {
            public var flags: Int32
            public var peer: Api.Peer
            public var topMessage: Int32
            public var readInboxMaxId: Int32
            public var readOutboxMaxId: Int32
            public var unreadCount: Int32
            public var unreadReactionsCount: Int32
            public var draft: Api.DraftMessage?
            public init(flags: Int32, peer: Api.Peer, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadReactionsCount: Int32, draft: Api.DraftMessage?) {
                self.flags = flags
                self.peer = peer
                self.topMessage = topMessage
                self.readInboxMaxId = readInboxMaxId
                self.readOutboxMaxId = readOutboxMaxId
                self.unreadCount = unreadCount
                self.unreadReactionsCount = unreadReactionsCount
                self.draft = draft
            }
        }
        public class Cons_savedDialog {
            public var flags: Int32
            public var peer: Api.Peer
            public var topMessage: Int32
            public init(flags: Int32, peer: Api.Peer, topMessage: Int32) {
                self.flags = flags
                self.peer = peer
                self.topMessage = topMessage
            }
        }
        case monoForumDialog(Cons_monoForumDialog)
        case savedDialog(Cons_savedDialog)

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

        public static func parse_monoForumDialog(_ reader: BufferReader) -> SavedDialog? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_savedDialog(_ reader: BufferReader) -> SavedDialog? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SavedReactionTag: TypeConstructorDescription {
        public class Cons_savedReactionTag {
            public var flags: Int32
            public var reaction: Api.Reaction
            public var title: String?
            public var count: Int32
            public init(flags: Int32, reaction: Api.Reaction, title: String?, count: Int32) {
                self.flags = flags
                self.reaction = reaction
                self.title = title
                self.count = count
            }
        }
        case savedReactionTag(Cons_savedReactionTag)

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

        public static func parse_savedReactionTag(_ reader: BufferReader) -> SavedReactionTag? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SavedStarGift: TypeConstructorDescription {
        public class Cons_savedStarGift {
            public var flags: Int32
            public var fromId: Api.Peer?
            public var date: Int32
            public var gift: Api.StarGift
            public var message: Api.TextWithEntities?
            public var msgId: Int32?
            public var savedId: Int64?
            public var convertStars: Int64?
            public var upgradeStars: Int64?
            public var canExportAt: Int32?
            public var transferStars: Int64?
            public var canTransferAt: Int32?
            public var canResellAt: Int32?
            public var collectionId: [Int32]?
            public var prepaidUpgradeHash: String?
            public var dropOriginalDetailsStars: Int64?
            public var giftNum: Int32?
            public var canCraftAt: Int32?
            public var craftChancePermille: Int32?
            public init(flags: Int32, fromId: Api.Peer?, date: Int32, gift: Api.StarGift, message: Api.TextWithEntities?, msgId: Int32?, savedId: Int64?, convertStars: Int64?, upgradeStars: Int64?, canExportAt: Int32?, transferStars: Int64?, canTransferAt: Int32?, canResellAt: Int32?, collectionId: [Int32]?, prepaidUpgradeHash: String?, dropOriginalDetailsStars: Int64?, giftNum: Int32?, canCraftAt: Int32?, craftChancePermille: Int32?) {
                self.flags = flags
                self.fromId = fromId
                self.date = date
                self.gift = gift
                self.message = message
                self.msgId = msgId
                self.savedId = savedId
                self.convertStars = convertStars
                self.upgradeStars = upgradeStars
                self.canExportAt = canExportAt
                self.transferStars = transferStars
                self.canTransferAt = canTransferAt
                self.canResellAt = canResellAt
                self.collectionId = collectionId
                self.prepaidUpgradeHash = prepaidUpgradeHash
                self.dropOriginalDetailsStars = dropOriginalDetailsStars
                self.giftNum = giftNum
                self.canCraftAt = canCraftAt
                self.craftChancePermille = craftChancePermille
            }
        }
        case savedStarGift(Cons_savedStarGift)

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

        public static func parse_savedStarGift(_ reader: BufferReader) -> SavedStarGift? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SearchPostsFlood: TypeConstructorDescription {
        public class Cons_searchPostsFlood {
            public var flags: Int32
            public var totalDaily: Int32
            public var remains: Int32
            public var waitTill: Int32?
            public var starsAmount: Int64
            public init(flags: Int32, totalDaily: Int32, remains: Int32, waitTill: Int32?, starsAmount: Int64) {
                self.flags = flags
                self.totalDaily = totalDaily
                self.remains = remains
                self.waitTill = waitTill
                self.starsAmount = starsAmount
            }
        }
        case searchPostsFlood(Cons_searchPostsFlood)

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

        public static func parse_searchPostsFlood(_ reader: BufferReader) -> SearchPostsFlood? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SearchResultsCalendarPeriod: TypeConstructorDescription {
        case searchResultsCalendarPeriod(date: Int32, minMsgId: Int32, maxMsgId: Int32, count: Int32)

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

        public static func parse_searchResultsCalendarPeriod(_ reader: BufferReader) -> SearchResultsCalendarPeriod? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SearchResultsPosition: TypeConstructorDescription {
        case searchResultPosition(msgId: Int32, date: Int32, offset: Int32)

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

        public static func parse_searchResultPosition(_ reader: BufferReader) -> SearchResultsPosition? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SecureCredentialsEncrypted: TypeConstructorDescription {
        case secureCredentialsEncrypted(data: Buffer, hash: Buffer, secret: Buffer)

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

        public static func parse_secureCredentialsEncrypted(_ reader: BufferReader) -> SecureCredentialsEncrypted? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SecureData: TypeConstructorDescription {
        case secureData(data: Buffer, dataHash: Buffer, secret: Buffer)

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

        public static func parse_secureData(_ reader: BufferReader) -> SecureData? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SecureFile: TypeConstructorDescription {
        case secureFile(id: Int64, accessHash: Int64, size: Int64, dcId: Int32, date: Int32, fileHash: Buffer, secret: Buffer)
        case secureFileEmpty

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

        public static func parse_secureFile(_ reader: BufferReader) -> SecureFile? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureFileEmpty(_ reader: BufferReader) -> SecureFile? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SecurePasswordKdfAlgo: TypeConstructorDescription {
        case securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(salt: Buffer)
        case securePasswordKdfAlgoSHA512(salt: Buffer)
        case securePasswordKdfAlgoUnknown

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

        public static func parse_securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(_ reader: BufferReader) -> SecurePasswordKdfAlgo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_securePasswordKdfAlgoSHA512(_ reader: BufferReader) -> SecurePasswordKdfAlgo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_securePasswordKdfAlgoUnknown(_ reader: BufferReader) -> SecurePasswordKdfAlgo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
