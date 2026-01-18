public extension Api.messages {
    enum SavedGifs: TypeConstructorDescription {
        public class Cons_savedGifs {
            public var hash: Int64
            public var gifs: [Api.Document]
            public init(hash: Int64, gifs: [Api.Document]) {
                self.hash = hash
                self.gifs = gifs
            }
        }
        case savedGifs(Cons_savedGifs)
        case savedGifsNotModified

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

        public static func parse_savedGifs(_ reader: BufferReader) -> SavedGifs? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_savedGifsNotModified(_ reader: BufferReader) -> SavedGifs? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum SavedReactionTags: TypeConstructorDescription {
        public class Cons_savedReactionTags {
            public var tags: [Api.SavedReactionTag]
            public var hash: Int64
            public init(tags: [Api.SavedReactionTag], hash: Int64) {
                self.tags = tags
                self.hash = hash
            }
        }
        case savedReactionTags(Cons_savedReactionTags)
        case savedReactionTagsNotModified

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

        public static func parse_savedReactionTags(_ reader: BufferReader) -> SavedReactionTags? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_savedReactionTagsNotModified(_ reader: BufferReader) -> SavedReactionTags? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum SearchCounter: TypeConstructorDescription {
        public class Cons_searchCounter {
            public var flags: Int32
            public var filter: Api.MessagesFilter
            public var count: Int32
            public init(flags: Int32, filter: Api.MessagesFilter, count: Int32) {
                self.flags = flags
                self.filter = filter
                self.count = count
            }
        }
        case searchCounter(Cons_searchCounter)

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

        public static func parse_searchCounter(_ reader: BufferReader) -> SearchCounter? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum SearchResultsCalendar: TypeConstructorDescription {
        case searchResultsCalendar(flags: Int32, count: Int32, minDate: Int32, minMsgId: Int32, offsetIdOffset: Int32?, periods: [Api.SearchResultsCalendarPeriod], messages: [Api.Message], chats: [Api.Chat], users: [Api.User])

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

        public static func parse_searchResultsCalendar(_ reader: BufferReader) -> SearchResultsCalendar? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum SearchResultsPositions: TypeConstructorDescription {
        case searchResultsPositions(count: Int32, positions: [Api.SearchResultsPosition])

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

        public static func parse_searchResultsPositions(_ reader: BufferReader) -> SearchResultsPositions? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum SentEncryptedMessage: TypeConstructorDescription {
        case sentEncryptedFile(date: Int32, file: Api.EncryptedFile)
        case sentEncryptedMessage(date: Int32)

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

        public static func parse_sentEncryptedFile(_ reader: BufferReader) -> SentEncryptedMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sentEncryptedMessage(_ reader: BufferReader) -> SentEncryptedMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum SponsoredMessages: TypeConstructorDescription {
        case sponsoredMessages(flags: Int32, postsBetween: Int32?, startDelay: Int32?, betweenDelay: Int32?, messages: [Api.SponsoredMessage], chats: [Api.Chat], users: [Api.User])
        case sponsoredMessagesEmpty

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

        public static func parse_sponsoredMessages(_ reader: BufferReader) -> SponsoredMessages? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sponsoredMessagesEmpty(_ reader: BufferReader) -> SponsoredMessages? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum StickerSet: TypeConstructorDescription {
        case stickerSet(set: Api.StickerSet, packs: [Api.StickerPack], keywords: [Api.StickerKeyword], documents: [Api.Document])
        case stickerSetNotModified

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

        public static func parse_stickerSet(_ reader: BufferReader) -> StickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_stickerSetNotModified(_ reader: BufferReader) -> StickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum StickerSetInstallResult: TypeConstructorDescription {
        case stickerSetInstallResultArchive(sets: [Api.StickerSetCovered])
        case stickerSetInstallResultSuccess

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

        public static func parse_stickerSetInstallResultArchive(_ reader: BufferReader) -> StickerSetInstallResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_stickerSetInstallResultSuccess(_ reader: BufferReader) -> StickerSetInstallResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum Stickers: TypeConstructorDescription {
        case stickers(hash: Int64, stickers: [Api.Document])
        case stickersNotModified

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

        public static func parse_stickers(_ reader: BufferReader) -> Stickers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_stickersNotModified(_ reader: BufferReader) -> Stickers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum TranscribedAudio: TypeConstructorDescription {
        case transcribedAudio(flags: Int32, transcriptionId: Int64, text: String, trialRemainsNum: Int32?, trialRemainsUntilDate: Int32?)

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

        public static func parse_transcribedAudio(_ reader: BufferReader) -> TranscribedAudio? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum TranslatedText: TypeConstructorDescription {
        case translateResult(result: [Api.TextWithEntities])

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

        public static func parse_translateResult(_ reader: BufferReader) -> TranslatedText? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum VotesList: TypeConstructorDescription {
        case votesList(flags: Int32, count: Int32, votes: [Api.MessagePeerVote], chats: [Api.Chat], users: [Api.User], nextOffset: String?)

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

        public static func parse_votesList(_ reader: BufferReader) -> VotesList? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    enum WebPage: TypeConstructorDescription {
        case webPage(webpage: Api.WebPage, chats: [Api.Chat], users: [Api.User])

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

        public static func parse_webPage(_ reader: BufferReader) -> WebPage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.messages {
    indirect enum WebPagePreview: TypeConstructorDescription {
        case webPagePreview(media: Api.MessageMedia, chats: [Api.Chat], users: [Api.User])

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

        public static func parse_webPagePreview(_ reader: BufferReader) -> WebPagePreview? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum BankCardData: TypeConstructorDescription {
        case bankCardData(title: String, openUrls: [Api.BankCardOpenUrl])

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

        public static func parse_bankCardData(_ reader: BufferReader) -> BankCardData? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum CheckCanSendGiftResult: TypeConstructorDescription {
        case checkCanSendGiftResultFail(reason: Api.TextWithEntities)
        case checkCanSendGiftResultOk

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

        public static func parse_checkCanSendGiftResultFail(_ reader: BufferReader) -> CheckCanSendGiftResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_checkCanSendGiftResultOk(_ reader: BufferReader) -> CheckCanSendGiftResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum CheckedGiftCode: TypeConstructorDescription {
        case checkedGiftCode(flags: Int32, fromId: Api.Peer?, giveawayMsgId: Int32?, toId: Int64?, date: Int32, days: Int32, usedDate: Int32?, chats: [Api.Chat], users: [Api.User])

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

        public static func parse_checkedGiftCode(_ reader: BufferReader) -> CheckedGiftCode? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum ConnectedStarRefBots: TypeConstructorDescription {
        case connectedStarRefBots(count: Int32, connectedBots: [Api.ConnectedBotStarRef], users: [Api.User])

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

        public static func parse_connectedStarRefBots(_ reader: BufferReader) -> ConnectedStarRefBots? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum ExportedInvoice: TypeConstructorDescription {
        case exportedInvoice(url: String)

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

        public static func parse_exportedInvoice(_ reader: BufferReader) -> ExportedInvoice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum GiveawayInfo: TypeConstructorDescription {
        case giveawayInfo(flags: Int32, startDate: Int32, joinedTooEarlyDate: Int32?, adminDisallowedChatId: Int64?, disallowedCountry: String?)
        case giveawayInfoResults(flags: Int32, startDate: Int32, giftCodeSlug: String?, starsPrize: Int64?, finishDate: Int32, winnersCount: Int32, activatedCount: Int32?)

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

        public static func parse_giveawayInfo(_ reader: BufferReader) -> GiveawayInfo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_giveawayInfoResults(_ reader: BufferReader) -> GiveawayInfo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.payments {
    enum PaymentForm: TypeConstructorDescription {
        case paymentForm(flags: Int32, formId: Int64, botId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, providerId: Int64, url: String, nativeProvider: String?, nativeParams: Api.DataJSON?, additionalMethods: [Api.PaymentFormMethod]?, savedInfo: Api.PaymentRequestedInfo?, savedCredentials: [Api.PaymentSavedCredentials]?, users: [Api.User])
        case paymentFormStarGift(formId: Int64, invoice: Api.Invoice)
        case paymentFormStars(flags: Int32, formId: Int64, botId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, users: [Api.User])

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

        public static func parse_paymentForm(_ reader: BufferReader) -> PaymentForm? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_paymentFormStarGift(_ reader: BufferReader) -> PaymentForm? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_paymentFormStars(_ reader: BufferReader) -> PaymentForm? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
