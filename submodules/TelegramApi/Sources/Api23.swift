public extension Api {
    enum RestrictionReason: TypeConstructorDescription {
        case restrictionReason(platform: String, reason: String, text: String)

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
        case textAnchor(text: Api.RichText, name: String)
        case textBold(text: Api.RichText)
        case textConcat(texts: [Api.RichText])
        case textEmail(text: Api.RichText, email: String)
        case textEmpty
        case textFixed(text: Api.RichText)
        case textImage(documentId: Int64, w: Int32, h: Int32)
        case textItalic(text: Api.RichText)
        case textMarked(text: Api.RichText)
        case textPhone(text: Api.RichText, phone: String)
        case textPlain(text: String)
        case textStrike(text: Api.RichText)
        case textSubscript(text: Api.RichText)
        case textSuperscript(text: Api.RichText)
        case textUnderline(text: Api.RichText)
        case textUrl(text: Api.RichText, url: String, webpageId: Int64)

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
        case savedPhoneContact(phone: String, firstName: String, lastName: String, date: Int32)

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
        case monoForumDialog(flags: Int32, peer: Api.Peer, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadReactionsCount: Int32, draft: Api.DraftMessage?)
        case savedDialog(flags: Int32, peer: Api.Peer, topMessage: Int32)

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
        case savedReactionTag(flags: Int32, reaction: Api.Reaction, title: String?, count: Int32)

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
        case savedStarGift(flags: Int32, fromId: Api.Peer?, date: Int32, gift: Api.StarGift, message: Api.TextWithEntities?, msgId: Int32?, savedId: Int64?, convertStars: Int64?, upgradeStars: Int64?, canExportAt: Int32?, transferStars: Int64?, canTransferAt: Int32?, canResellAt: Int32?, collectionId: [Int32]?, prepaidUpgradeHash: String?, dropOriginalDetailsStars: Int64?, giftNum: Int32?, canCraftAt: Int32?, craftChancePermille: Int32?)

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
        case searchPostsFlood(flags: Int32, totalDaily: Int32, remains: Int32, waitTill: Int32?, starsAmount: Int64)

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
