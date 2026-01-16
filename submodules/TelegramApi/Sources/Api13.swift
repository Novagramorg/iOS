public extension Api {
    enum InputQuickReplyShortcut: TypeConstructorDescription {
        public class Cons_inputQuickReplyShortcut {
            public var shortcut: String
            public init(shortcut: String) {
                self.shortcut = shortcut
            }
        }
        public class Cons_inputQuickReplyShortcutId {
            public var shortcutId: Int32
            public init(shortcutId: Int32) {
                self.shortcutId = shortcutId
            }
        }
        case inputQuickReplyShortcut(Cons_inputQuickReplyShortcut)
        case inputQuickReplyShortcutId(Cons_inputQuickReplyShortcutId)

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

        public static func parse_inputQuickReplyShortcut(_ reader: BufferReader) -> InputQuickReplyShortcut? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputQuickReplyShortcutId(_ reader: BufferReader) -> InputQuickReplyShortcut? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum InputReplyTo: TypeConstructorDescription {
        public class Cons_inputReplyToMessage {
            public var flags: Int32
            public var replyToMsgId: Int32
            public var topMsgId: Int32?
            public var replyToPeerId: Api.InputPeer?
            public var quoteText: String?
            public var quoteEntities: [Api.MessageEntity]?
            public var quoteOffset: Int32?
            public var monoforumPeerId: Api.InputPeer?
            public var todoItemId: Int32?
            public init(flags: Int32, replyToMsgId: Int32, topMsgId: Int32?, replyToPeerId: Api.InputPeer?, quoteText: String?, quoteEntities: [Api.MessageEntity]?, quoteOffset: Int32?, monoforumPeerId: Api.InputPeer?, todoItemId: Int32?) {
                self.flags = flags
                self.replyToMsgId = replyToMsgId
                self.topMsgId = topMsgId
                self.replyToPeerId = replyToPeerId
                self.quoteText = quoteText
                self.quoteEntities = quoteEntities
                self.quoteOffset = quoteOffset
                self.monoforumPeerId = monoforumPeerId
                self.todoItemId = todoItemId
            }
        }
        public class Cons_inputReplyToMonoForum {
            public var monoforumPeerId: Api.InputPeer
            public init(monoforumPeerId: Api.InputPeer) {
                self.monoforumPeerId = monoforumPeerId
            }
        }
        public class Cons_inputReplyToStory {
            public var peer: Api.InputPeer
            public var storyId: Int32
            public init(peer: Api.InputPeer, storyId: Int32) {
                self.peer = peer
                self.storyId = storyId
            }
        }
        case inputReplyToMessage(Cons_inputReplyToMessage)
        case inputReplyToMonoForum(Cons_inputReplyToMonoForum)
        case inputReplyToStory(Cons_inputReplyToStory)

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

        public static func parse_inputReplyToMessage(_ reader: BufferReader) -> InputReplyTo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputReplyToMonoForum(_ reader: BufferReader) -> InputReplyTo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputReplyToStory(_ reader: BufferReader) -> InputReplyTo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum InputSavedStarGift: TypeConstructorDescription {
        public class Cons_inputSavedStarGiftChat {
            public var peer: Api.InputPeer
            public var savedId: Int64
            public init(peer: Api.InputPeer, savedId: Int64) {
                self.peer = peer
                self.savedId = savedId
            }
        }
        public class Cons_inputSavedStarGiftSlug {
            public var slug: String
            public init(slug: String) {
                self.slug = slug
            }
        }
        public class Cons_inputSavedStarGiftUser {
            public var msgId: Int32
            public init(msgId: Int32) {
                self.msgId = msgId
            }
        }
        case inputSavedStarGiftChat(Cons_inputSavedStarGiftChat)
        case inputSavedStarGiftSlug(Cons_inputSavedStarGiftSlug)
        case inputSavedStarGiftUser(Cons_inputSavedStarGiftUser)

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

        public static func parse_inputSavedStarGiftChat(_ reader: BufferReader) -> InputSavedStarGift? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputSavedStarGiftSlug(_ reader: BufferReader) -> InputSavedStarGift? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputSavedStarGiftUser(_ reader: BufferReader) -> InputSavedStarGift? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputSecureFile: TypeConstructorDescription {
        public class Cons_inputSecureFile {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
        }
        public class Cons_inputSecureFileUploaded {
            public var id: Int64
            public var parts: Int32
            public var md5Checksum: String
            public var fileHash: Buffer
            public var secret: Buffer
            public init(id: Int64, parts: Int32, md5Checksum: String, fileHash: Buffer, secret: Buffer) {
                self.id = id
                self.parts = parts
                self.md5Checksum = md5Checksum
                self.fileHash = fileHash
                self.secret = secret
            }
        }
        case inputSecureFile(Cons_inputSecureFile)
        case inputSecureFileUploaded(Cons_inputSecureFileUploaded)

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

        public static func parse_inputSecureFile(_ reader: BufferReader) -> InputSecureFile? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputSecureFileUploaded(_ reader: BufferReader) -> InputSecureFile? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputSecureValue: TypeConstructorDescription {
        public class Cons_inputSecureValue {
            public var flags: Int32
            public var type: Api.SecureValueType
            public var data: Api.SecureData?
            public var frontSide: Api.InputSecureFile?
            public var reverseSide: Api.InputSecureFile?
            public var selfie: Api.InputSecureFile?
            public var translation: [Api.InputSecureFile]?
            public var files: [Api.InputSecureFile]?
            public var plainData: Api.SecurePlainData?
            public init(flags: Int32, type: Api.SecureValueType, data: Api.SecureData?, frontSide: Api.InputSecureFile?, reverseSide: Api.InputSecureFile?, selfie: Api.InputSecureFile?, translation: [Api.InputSecureFile]?, files: [Api.InputSecureFile]?, plainData: Api.SecurePlainData?) {
                self.flags = flags
                self.type = type
                self.data = data
                self.frontSide = frontSide
                self.reverseSide = reverseSide
                self.selfie = selfie
                self.translation = translation
                self.files = files
                self.plainData = plainData
            }
        }
        case inputSecureValue(Cons_inputSecureValue)

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

        public static func parse_inputSecureValue(_ reader: BufferReader) -> InputSecureValue? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum InputSingleMedia: TypeConstructorDescription {
        public class Cons_inputSingleMedia {
            public var flags: Int32
            public var media: Api.InputMedia
            public var randomId: Int64
            public var message: String
            public var entities: [Api.MessageEntity]?
            public init(flags: Int32, media: Api.InputMedia, randomId: Int64, message: String, entities: [Api.MessageEntity]?) {
                self.flags = flags
                self.media = media
                self.randomId = randomId
                self.message = message
                self.entities = entities
            }
        }
        case inputSingleMedia(Cons_inputSingleMedia)

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

        public static func parse_inputSingleMedia(_ reader: BufferReader) -> InputSingleMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputStarGiftAuction: TypeConstructorDescription {
        public class Cons_inputStarGiftAuction {
            public var giftId: Int64
            public init(giftId: Int64) {
                self.giftId = giftId
            }
        }
        public class Cons_inputStarGiftAuctionSlug {
            public var slug: String
            public init(slug: String) {
                self.slug = slug
            }
        }
        case inputStarGiftAuction(Cons_inputStarGiftAuction)
        case inputStarGiftAuctionSlug(Cons_inputStarGiftAuctionSlug)

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

        public static func parse_inputStarGiftAuction(_ reader: BufferReader) -> InputStarGiftAuction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStarGiftAuctionSlug(_ reader: BufferReader) -> InputStarGiftAuction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputStarsTransaction: TypeConstructorDescription {
        public class Cons_inputStarsTransaction {
            public var flags: Int32
            public var id: String
            public init(flags: Int32, id: String) {
                self.flags = flags
                self.id = id
            }
        }
        case inputStarsTransaction(Cons_inputStarsTransaction)

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

        public static func parse_inputStarsTransaction(_ reader: BufferReader) -> InputStarsTransaction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputStickerSet: TypeConstructorDescription {
        public class Cons_inputStickerSetDice {
            public var emoticon: String
            public init(emoticon: String) {
                self.emoticon = emoticon
            }
        }
        public class Cons_inputStickerSetID {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
        }
        public class Cons_inputStickerSetShortName {
            public var shortName: String
            public init(shortName: String) {
                self.shortName = shortName
            }
        }
        case inputStickerSetAnimatedEmoji
        case inputStickerSetAnimatedEmojiAnimations
        case inputStickerSetDice(Cons_inputStickerSetDice)
        case inputStickerSetEmojiChannelDefaultStatuses
        case inputStickerSetEmojiDefaultStatuses
        case inputStickerSetEmojiDefaultTopicIcons
        case inputStickerSetEmojiGenericAnimations
        case inputStickerSetEmpty
        case inputStickerSetID(Cons_inputStickerSetID)
        case inputStickerSetPremiumGifts
        case inputStickerSetShortName(Cons_inputStickerSetShortName)
        case inputStickerSetTonGifts

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

        public static func parse_inputStickerSetAnimatedEmoji(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetAnimatedEmojiAnimations(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetDice(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetEmojiChannelDefaultStatuses(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetEmojiDefaultStatuses(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetEmojiDefaultTopicIcons(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetEmojiGenericAnimations(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetEmpty(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetID(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetPremiumGifts(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetShortName(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetTonGifts(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputStickerSetItem: TypeConstructorDescription {
        public class Cons_inputStickerSetItem {
            public var flags: Int32
            public var document: Api.InputDocument
            public var emoji: String
            public var maskCoords: Api.MaskCoords?
            public var keywords: String?
            public init(flags: Int32, document: Api.InputDocument, emoji: String, maskCoords: Api.MaskCoords?, keywords: String?) {
                self.flags = flags
                self.document = document
                self.emoji = emoji
                self.maskCoords = maskCoords
                self.keywords = keywords
            }
        }
        case inputStickerSetItem(Cons_inputStickerSetItem)

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

        public static func parse_inputStickerSetItem(_ reader: BufferReader) -> InputStickerSetItem? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputStickeredMedia: TypeConstructorDescription {
        public class Cons_inputStickeredMediaDocument {
            public var id: Api.InputDocument
            public init(id: Api.InputDocument) {
                self.id = id
            }
        }
        public class Cons_inputStickeredMediaPhoto {
            public var id: Api.InputPhoto
            public init(id: Api.InputPhoto) {
                self.id = id
            }
        }
        case inputStickeredMediaDocument(Cons_inputStickeredMediaDocument)
        case inputStickeredMediaPhoto(Cons_inputStickeredMediaPhoto)

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

        public static func parse_inputStickeredMediaDocument(_ reader: BufferReader) -> InputStickeredMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickeredMediaPhoto(_ reader: BufferReader) -> InputStickeredMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum InputStorePaymentPurpose: TypeConstructorDescription {
        public class Cons_inputStorePaymentAuthCode {
            public var flags: Int32
            public var phoneNumber: String
            public var phoneCodeHash: String
            public var currency: String
            public var amount: Int64
            public init(flags: Int32, phoneNumber: String, phoneCodeHash: String, currency: String, amount: Int64) {
                self.flags = flags
                self.phoneNumber = phoneNumber
                self.phoneCodeHash = phoneCodeHash
                self.currency = currency
                self.amount = amount
            }
        }
        public class Cons_inputStorePaymentGiftPremium {
            public var userId: Api.InputUser
            public var currency: String
            public var amount: Int64
            public init(userId: Api.InputUser, currency: String, amount: Int64) {
                self.userId = userId
                self.currency = currency
                self.amount = amount
            }
        }
        public class Cons_inputStorePaymentPremiumGiftCode {
            public var flags: Int32
            public var users: [Api.InputUser]
            public var boostPeer: Api.InputPeer?
            public var currency: String
            public var amount: Int64
            public var message: Api.TextWithEntities?
            public init(flags: Int32, users: [Api.InputUser], boostPeer: Api.InputPeer?, currency: String, amount: Int64, message: Api.TextWithEntities?) {
                self.flags = flags
                self.users = users
                self.boostPeer = boostPeer
                self.currency = currency
                self.amount = amount
                self.message = message
            }
        }
        public class Cons_inputStorePaymentPremiumGiveaway {
            public var flags: Int32
            public var boostPeer: Api.InputPeer
            public var additionalPeers: [Api.InputPeer]?
            public var countriesIso2: [String]?
            public var prizeDescription: String?
            public var randomId: Int64
            public var untilDate: Int32
            public var currency: String
            public var amount: Int64
            public init(flags: Int32, boostPeer: Api.InputPeer, additionalPeers: [Api.InputPeer]?, countriesIso2: [String]?, prizeDescription: String?, randomId: Int64, untilDate: Int32, currency: String, amount: Int64) {
                self.flags = flags
                self.boostPeer = boostPeer
                self.additionalPeers = additionalPeers
                self.countriesIso2 = countriesIso2
                self.prizeDescription = prizeDescription
                self.randomId = randomId
                self.untilDate = untilDate
                self.currency = currency
                self.amount = amount
            }
        }
        public class Cons_inputStorePaymentPremiumSubscription {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        public class Cons_inputStorePaymentStarsGift {
            public var userId: Api.InputUser
            public var stars: Int64
            public var currency: String
            public var amount: Int64
            public init(userId: Api.InputUser, stars: Int64, currency: String, amount: Int64) {
                self.userId = userId
                self.stars = stars
                self.currency = currency
                self.amount = amount
            }
        }
        public class Cons_inputStorePaymentStarsGiveaway {
            public var flags: Int32
            public var stars: Int64
            public var boostPeer: Api.InputPeer
            public var additionalPeers: [Api.InputPeer]?
            public var countriesIso2: [String]?
            public var prizeDescription: String?
            public var randomId: Int64
            public var untilDate: Int32
            public var currency: String
            public var amount: Int64
            public var users: Int32
            public init(flags: Int32, stars: Int64, boostPeer: Api.InputPeer, additionalPeers: [Api.InputPeer]?, countriesIso2: [String]?, prizeDescription: String?, randomId: Int64, untilDate: Int32, currency: String, amount: Int64, users: Int32) {
                self.flags = flags
                self.stars = stars
                self.boostPeer = boostPeer
                self.additionalPeers = additionalPeers
                self.countriesIso2 = countriesIso2
                self.prizeDescription = prizeDescription
                self.randomId = randomId
                self.untilDate = untilDate
                self.currency = currency
                self.amount = amount
                self.users = users
            }
        }
        public class Cons_inputStorePaymentStarsTopup {
            public var flags: Int32
            public var stars: Int64
            public var currency: String
            public var amount: Int64
            public var spendPurposePeer: Api.InputPeer?
            public init(flags: Int32, stars: Int64, currency: String, amount: Int64, spendPurposePeer: Api.InputPeer?) {
                self.flags = flags
                self.stars = stars
                self.currency = currency
                self.amount = amount
                self.spendPurposePeer = spendPurposePeer
            }
        }
        case inputStorePaymentAuthCode(Cons_inputStorePaymentAuthCode)
        case inputStorePaymentGiftPremium(Cons_inputStorePaymentGiftPremium)
        case inputStorePaymentPremiumGiftCode(Cons_inputStorePaymentPremiumGiftCode)
        case inputStorePaymentPremiumGiveaway(Cons_inputStorePaymentPremiumGiveaway)
        case inputStorePaymentPremiumSubscription(Cons_inputStorePaymentPremiumSubscription)
        case inputStorePaymentStarsGift(Cons_inputStorePaymentStarsGift)
        case inputStorePaymentStarsGiveaway(Cons_inputStorePaymentStarsGiveaway)
        case inputStorePaymentStarsTopup(Cons_inputStorePaymentStarsTopup)

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

        public static func parse_inputStorePaymentAuthCode(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStorePaymentGiftPremium(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStorePaymentPremiumGiftCode(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStorePaymentPremiumGiveaway(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStorePaymentPremiumSubscription(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStorePaymentStarsGift(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStorePaymentStarsGiveaway(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStorePaymentStarsTopup(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
