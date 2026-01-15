public extension Api {
    enum DisallowedGiftsSettings: TypeConstructorDescription {
        case disallowedGiftsSettings(flags: Int32)

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
        case document(flags: Int32, id: Int64, accessHash: Int64, fileReference: Buffer, date: Int32, mimeType: String, size: Int64, thumbs: [Api.PhotoSize]?, videoThumbs: [Api.VideoSize]?, dcId: Int32, attributes: [Api.DocumentAttribute])
        case documentEmpty(id: Int64)

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
        case documentAttributeAnimated
        case documentAttributeAudio(flags: Int32, duration: Int32, title: String?, performer: String?, waveform: Buffer?)
        case documentAttributeCustomEmoji(flags: Int32, alt: String, stickerset: Api.InputStickerSet)
        case documentAttributeFilename(fileName: String)
        case documentAttributeHasStickers
        case documentAttributeImageSize(w: Int32, h: Int32)
        case documentAttributeSticker(flags: Int32, alt: String, stickerset: Api.InputStickerSet, maskCoords: Api.MaskCoords?)
        case documentAttributeVideo(flags: Int32, duration: Double, w: Int32, h: Int32, preloadPrefixSize: Int32?, videoStartTs: Double?, videoCodec: String?)

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
        case draftMessage(flags: Int32, replyTo: Api.InputReplyTo?, message: String, entities: [Api.MessageEntity]?, media: Api.InputMedia?, date: Int32, effect: Int64?, suggestedPost: Api.SuggestedPost?)
        case draftMessageEmpty(flags: Int32, date: Int32?)

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
        case emailVerificationApple(token: String)
        case emailVerificationCode(code: String)
        case emailVerificationGoogle(token: String)

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
        case emailVerifyPurposeLoginChange
        case emailVerifyPurposeLoginSetup(phoneNumber: String, phoneCodeHash: String)
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
        case emojiGroup(title: String, iconEmojiId: Int64, emoticons: [String])
        case emojiGroupGreeting(title: String, iconEmojiId: Int64, emoticons: [String])
        case emojiGroupPremium(title: String, iconEmojiId: Int64)

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
        case emojiKeyword(keyword: String, emoticons: [String])
        case emojiKeywordDeleted(keyword: String, emoticons: [String])

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
        case emojiKeywordsDifference(langCode: String, fromVersion: Int32, version: Int32, keywords: [Api.EmojiKeyword])

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
        case emojiLanguage(langCode: String)

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
        case emojiList(hash: Int64, documentId: [Int64])
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
        case emojiStatus(flags: Int32, documentId: Int64, until: Int32?)
        case emojiStatusCollectible(flags: Int32, collectibleId: Int64, documentId: Int64, title: String, slug: String, patternDocumentId: Int64, centerColor: Int32, edgeColor: Int32, patternColor: Int32, textColor: Int32, until: Int32?)
        case emojiStatusEmpty
        case inputEmojiStatusCollectible(flags: Int32, collectibleId: Int64, until: Int32?)

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
