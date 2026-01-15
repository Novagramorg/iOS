public extension Api {
    enum DisallowedGiftsSettings: TypeConstructorDescription {
        public class Cons_disallowedGiftsSettings {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        case disallowedGiftsSettings(Cons_disallowedGiftsSettings)

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

        public static func parse_disallowedGiftsSettings(_ reader: BufferReader) -> DisallowedGiftsSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Document: TypeConstructorDescription {
        public class Cons_document {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var fileReference: Buffer
            public var date: Int32
            public var mimeType: String
            public var size: Int64
            public var thumbs: [Api.PhotoSize]?
            public var videoThumbs: [Api.VideoSize]?
            public var dcId: Int32
            public var attributes: [Api.DocumentAttribute]
            public init(flags: Int32, id: Int64, accessHash: Int64, fileReference: Buffer, date: Int32, mimeType: String, size: Int64, thumbs: [Api.PhotoSize]?, videoThumbs: [Api.VideoSize]?, dcId: Int32, attributes: [Api.DocumentAttribute]) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.fileReference = fileReference
                self.date = date
                self.mimeType = mimeType
                self.size = size
                self.thumbs = thumbs
                self.videoThumbs = videoThumbs
                self.dcId = dcId
                self.attributes = attributes
            }
        }
        public class Cons_documentEmpty {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
        }
        case document(Cons_document)
        case documentEmpty(Cons_documentEmpty)

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

        public static func parse_document(_ reader: BufferReader) -> Document? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_documentEmpty(_ reader: BufferReader) -> Document? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum DocumentAttribute: TypeConstructorDescription {
        public class Cons_documentAttributeAudio {
            public var flags: Int32
            public var duration: Int32
            public var title: String?
            public var performer: String?
            public var waveform: Buffer?
            public init(flags: Int32, duration: Int32, title: String?, performer: String?, waveform: Buffer?) {
                self.flags = flags
                self.duration = duration
                self.title = title
                self.performer = performer
                self.waveform = waveform
            }
        }
        public class Cons_documentAttributeCustomEmoji {
            public var flags: Int32
            public var alt: String
            public var stickerset: Api.InputStickerSet
            public init(flags: Int32, alt: String, stickerset: Api.InputStickerSet) {
                self.flags = flags
                self.alt = alt
                self.stickerset = stickerset
            }
        }
        public class Cons_documentAttributeFilename {
            public var fileName: String
            public init(fileName: String) {
                self.fileName = fileName
            }
        }
        public class Cons_documentAttributeImageSize {
            public var w: Int32
            public var h: Int32
            public init(w: Int32, h: Int32) {
                self.w = w
                self.h = h
            }
        }
        public class Cons_documentAttributeSticker {
            public var flags: Int32
            public var alt: String
            public var stickerset: Api.InputStickerSet
            public var maskCoords: Api.MaskCoords?
            public init(flags: Int32, alt: String, stickerset: Api.InputStickerSet, maskCoords: Api.MaskCoords?) {
                self.flags = flags
                self.alt = alt
                self.stickerset = stickerset
                self.maskCoords = maskCoords
            }
        }
        public class Cons_documentAttributeVideo {
            public var flags: Int32
            public var duration: Double
            public var w: Int32
            public var h: Int32
            public var preloadPrefixSize: Int32?
            public var videoStartTs: Double?
            public var videoCodec: String?
            public init(flags: Int32, duration: Double, w: Int32, h: Int32, preloadPrefixSize: Int32?, videoStartTs: Double?, videoCodec: String?) {
                self.flags = flags
                self.duration = duration
                self.w = w
                self.h = h
                self.preloadPrefixSize = preloadPrefixSize
                self.videoStartTs = videoStartTs
                self.videoCodec = videoCodec
            }
        }
        case documentAttributeAnimated
        case documentAttributeAudio(Cons_documentAttributeAudio)
        case documentAttributeCustomEmoji(Cons_documentAttributeCustomEmoji)
        case documentAttributeFilename(Cons_documentAttributeFilename)
        case documentAttributeHasStickers
        case documentAttributeImageSize(Cons_documentAttributeImageSize)
        case documentAttributeSticker(Cons_documentAttributeSticker)
        case documentAttributeVideo(Cons_documentAttributeVideo)

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

        public static func parse_documentAttributeAnimated(_ reader: BufferReader) -> DocumentAttribute? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_documentAttributeAudio(_ reader: BufferReader) -> DocumentAttribute? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_documentAttributeCustomEmoji(_ reader: BufferReader) -> DocumentAttribute? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_documentAttributeFilename(_ reader: BufferReader) -> DocumentAttribute? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_documentAttributeHasStickers(_ reader: BufferReader) -> DocumentAttribute? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_documentAttributeImageSize(_ reader: BufferReader) -> DocumentAttribute? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_documentAttributeSticker(_ reader: BufferReader) -> DocumentAttribute? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_documentAttributeVideo(_ reader: BufferReader) -> DocumentAttribute? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum DraftMessage: TypeConstructorDescription {
        public class Cons_draftMessage {
            public var flags: Int32
            public var replyTo: Api.InputReplyTo?
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var media: Api.InputMedia?
            public var date: Int32
            public var effect: Int64?
            public var suggestedPost: Api.SuggestedPost?
            public init(flags: Int32, replyTo: Api.InputReplyTo?, message: String, entities: [Api.MessageEntity]?, media: Api.InputMedia?, date: Int32, effect: Int64?, suggestedPost: Api.SuggestedPost?) {
                self.flags = flags
                self.replyTo = replyTo
                self.message = message
                self.entities = entities
                self.media = media
                self.date = date
                self.effect = effect
                self.suggestedPost = suggestedPost
            }
        }
        public class Cons_draftMessageEmpty {
            public var flags: Int32
            public var date: Int32?
            public init(flags: Int32, date: Int32?) {
                self.flags = flags
                self.date = date
            }
        }
        case draftMessage(Cons_draftMessage)
        case draftMessageEmpty(Cons_draftMessageEmpty)

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

        public static func parse_draftMessage(_ reader: BufferReader) -> DraftMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_draftMessageEmpty(_ reader: BufferReader) -> DraftMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum EmailVerification: TypeConstructorDescription {
        public class Cons_emailVerificationApple {
            public var token: String
            public init(token: String) {
                self.token = token
            }
        }
        public class Cons_emailVerificationCode {
            public var code: String
            public init(code: String) {
                self.code = code
            }
        }
        public class Cons_emailVerificationGoogle {
            public var token: String
            public init(token: String) {
                self.token = token
            }
        }
        case emailVerificationApple(Cons_emailVerificationApple)
        case emailVerificationCode(Cons_emailVerificationCode)
        case emailVerificationGoogle(Cons_emailVerificationGoogle)

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

        public static func parse_emailVerificationApple(_ reader: BufferReader) -> EmailVerification? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_emailVerificationCode(_ reader: BufferReader) -> EmailVerification? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_emailVerificationGoogle(_ reader: BufferReader) -> EmailVerification? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum EmailVerifyPurpose: TypeConstructorDescription {
        public class Cons_emailVerifyPurposeLoginSetup {
            public var phoneNumber: String
            public var phoneCodeHash: String
            public init(phoneNumber: String, phoneCodeHash: String) {
                self.phoneNumber = phoneNumber
                self.phoneCodeHash = phoneCodeHash
            }
        }
        case emailVerifyPurposeLoginChange
        case emailVerifyPurposeLoginSetup(Cons_emailVerifyPurposeLoginSetup)
        case emailVerifyPurposePassport

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

        public static func parse_emailVerifyPurposeLoginChange(_ reader: BufferReader) -> EmailVerifyPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_emailVerifyPurposeLoginSetup(_ reader: BufferReader) -> EmailVerifyPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_emailVerifyPurposePassport(_ reader: BufferReader) -> EmailVerifyPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum EmojiGroup: TypeConstructorDescription {
        public class Cons_emojiGroup {
            public var title: String
            public var iconEmojiId: Int64
            public var emoticons: [String]
            public init(title: String, iconEmojiId: Int64, emoticons: [String]) {
                self.title = title
                self.iconEmojiId = iconEmojiId
                self.emoticons = emoticons
            }
        }
        public class Cons_emojiGroupGreeting {
            public var title: String
            public var iconEmojiId: Int64
            public var emoticons: [String]
            public init(title: String, iconEmojiId: Int64, emoticons: [String]) {
                self.title = title
                self.iconEmojiId = iconEmojiId
                self.emoticons = emoticons
            }
        }
        public class Cons_emojiGroupPremium {
            public var title: String
            public var iconEmojiId: Int64
            public init(title: String, iconEmojiId: Int64) {
                self.title = title
                self.iconEmojiId = iconEmojiId
            }
        }
        case emojiGroup(Cons_emojiGroup)
        case emojiGroupGreeting(Cons_emojiGroupGreeting)
        case emojiGroupPremium(Cons_emojiGroupPremium)

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

        public static func parse_emojiGroup(_ reader: BufferReader) -> EmojiGroup? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_emojiGroupGreeting(_ reader: BufferReader) -> EmojiGroup? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_emojiGroupPremium(_ reader: BufferReader) -> EmojiGroup? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum EmojiKeyword: TypeConstructorDescription {
        public class Cons_emojiKeyword {
            public var keyword: String
            public var emoticons: [String]
            public init(keyword: String, emoticons: [String]) {
                self.keyword = keyword
                self.emoticons = emoticons
            }
        }
        public class Cons_emojiKeywordDeleted {
            public var keyword: String
            public var emoticons: [String]
            public init(keyword: String, emoticons: [String]) {
                self.keyword = keyword
                self.emoticons = emoticons
            }
        }
        case emojiKeyword(Cons_emojiKeyword)
        case emojiKeywordDeleted(Cons_emojiKeywordDeleted)

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

        public static func parse_emojiKeyword(_ reader: BufferReader) -> EmojiKeyword? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_emojiKeywordDeleted(_ reader: BufferReader) -> EmojiKeyword? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum EmojiKeywordsDifference: TypeConstructorDescription {
        public class Cons_emojiKeywordsDifference {
            public var langCode: String
            public var fromVersion: Int32
            public var version: Int32
            public var keywords: [Api.EmojiKeyword]
            public init(langCode: String, fromVersion: Int32, version: Int32, keywords: [Api.EmojiKeyword]) {
                self.langCode = langCode
                self.fromVersion = fromVersion
                self.version = version
                self.keywords = keywords
            }
        }
        case emojiKeywordsDifference(Cons_emojiKeywordsDifference)

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

        public static func parse_emojiKeywordsDifference(_ reader: BufferReader) -> EmojiKeywordsDifference? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum EmojiLanguage: TypeConstructorDescription {
        public class Cons_emojiLanguage {
            public var langCode: String
            public init(langCode: String) {
                self.langCode = langCode
            }
        }
        case emojiLanguage(Cons_emojiLanguage)

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

        public static func parse_emojiLanguage(_ reader: BufferReader) -> EmojiLanguage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum EmojiList: TypeConstructorDescription {
        public class Cons_emojiList {
            public var hash: Int64
            public var documentId: [Int64]
            public init(hash: Int64, documentId: [Int64]) {
                self.hash = hash
                self.documentId = documentId
            }
        }
        case emojiList(Cons_emojiList)
        case emojiListNotModified

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

        public static func parse_emojiList(_ reader: BufferReader) -> EmojiList? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_emojiListNotModified(_ reader: BufferReader) -> EmojiList? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum EmojiStatus: TypeConstructorDescription {
        public class Cons_emojiStatus {
            public var flags: Int32
            public var documentId: Int64
            public var until: Int32?
            public init(flags: Int32, documentId: Int64, until: Int32?) {
                self.flags = flags
                self.documentId = documentId
                self.until = until
            }
        }
        public class Cons_emojiStatusCollectible {
            public var flags: Int32
            public var collectibleId: Int64
            public var documentId: Int64
            public var title: String
            public var slug: String
            public var patternDocumentId: Int64
            public var centerColor: Int32
            public var edgeColor: Int32
            public var patternColor: Int32
            public var textColor: Int32
            public var until: Int32?
            public init(flags: Int32, collectibleId: Int64, documentId: Int64, title: String, slug: String, patternDocumentId: Int64, centerColor: Int32, edgeColor: Int32, patternColor: Int32, textColor: Int32, until: Int32?) {
                self.flags = flags
                self.collectibleId = collectibleId
                self.documentId = documentId
                self.title = title
                self.slug = slug
                self.patternDocumentId = patternDocumentId
                self.centerColor = centerColor
                self.edgeColor = edgeColor
                self.patternColor = patternColor
                self.textColor = textColor
                self.until = until
            }
        }
        public class Cons_inputEmojiStatusCollectible {
            public var flags: Int32
            public var collectibleId: Int64
            public var until: Int32?
            public init(flags: Int32, collectibleId: Int64, until: Int32?) {
                self.flags = flags
                self.collectibleId = collectibleId
                self.until = until
            }
        }
        case emojiStatus(Cons_emojiStatus)
        case emojiStatusCollectible(Cons_emojiStatusCollectible)
        case emojiStatusEmpty
        case inputEmojiStatusCollectible(Cons_inputEmojiStatusCollectible)

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

        public static func parse_emojiStatus(_ reader: BufferReader) -> EmojiStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_emojiStatusCollectible(_ reader: BufferReader) -> EmojiStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_emojiStatusEmpty(_ reader: BufferReader) -> EmojiStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputEmojiStatusCollectible(_ reader: BufferReader) -> EmojiStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
