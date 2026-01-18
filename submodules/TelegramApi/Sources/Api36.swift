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
        public class Cons_searchResultsCalendar {
            public var flags: Int32
            public var count: Int32
            public var minDate: Int32
            public var minMsgId: Int32
            public var offsetIdOffset: Int32?
            public var periods: [Api.SearchResultsCalendarPeriod]
            public var messages: [Api.Message]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, count: Int32, minDate: Int32, minMsgId: Int32, offsetIdOffset: Int32?, periods: [Api.SearchResultsCalendarPeriod], messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.count = count
                self.minDate = minDate
                self.minMsgId = minMsgId
                self.offsetIdOffset = offsetIdOffset
                self.periods = periods
                self.messages = messages
                self.chats = chats
                self.users = users
            }
        }
        case searchResultsCalendar(Cons_searchResultsCalendar)

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
        public class Cons_searchResultsPositions {
            public var count: Int32
            public var positions: [Api.SearchResultsPosition]
            public init(count: Int32, positions: [Api.SearchResultsPosition]) {
                self.count = count
                self.positions = positions
            }
        }
        case searchResultsPositions(Cons_searchResultsPositions)

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
        public class Cons_sentEncryptedFile {
            public var date: Int32
            public var file: Api.EncryptedFile
            public init(date: Int32, file: Api.EncryptedFile) {
                self.date = date
                self.file = file
            }
        }
        public class Cons_sentEncryptedMessage {
            public var date: Int32
            public init(date: Int32) {
                self.date = date
            }
        }
        case sentEncryptedFile(Cons_sentEncryptedFile)
        case sentEncryptedMessage(Cons_sentEncryptedMessage)

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
        public class Cons_sponsoredMessages {
            public var flags: Int32
            public var postsBetween: Int32?
            public var startDelay: Int32?
            public var betweenDelay: Int32?
            public var messages: [Api.SponsoredMessage]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, postsBetween: Int32?, startDelay: Int32?, betweenDelay: Int32?, messages: [Api.SponsoredMessage], chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.postsBetween = postsBetween
                self.startDelay = startDelay
                self.betweenDelay = betweenDelay
                self.messages = messages
                self.chats = chats
                self.users = users
            }
        }
        case sponsoredMessages(Cons_sponsoredMessages)
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
        public class Cons_stickerSet {
            public var set: Api.StickerSet
            public var packs: [Api.StickerPack]
            public var keywords: [Api.StickerKeyword]
            public var documents: [Api.Document]
            public init(set: Api.StickerSet, packs: [Api.StickerPack], keywords: [Api.StickerKeyword], documents: [Api.Document]) {
                self.set = set
                self.packs = packs
                self.keywords = keywords
                self.documents = documents
            }
        }
        case stickerSet(Cons_stickerSet)
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
        public class Cons_stickerSetInstallResultArchive {
            public var sets: [Api.StickerSetCovered]
            public init(sets: [Api.StickerSetCovered]) {
                self.sets = sets
            }
        }
        case stickerSetInstallResultArchive(Cons_stickerSetInstallResultArchive)
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
        public class Cons_stickers {
            public var hash: Int64
            public var stickers: [Api.Document]
            public init(hash: Int64, stickers: [Api.Document]) {
                self.hash = hash
                self.stickers = stickers
            }
        }
        case stickers(Cons_stickers)
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
        public class Cons_transcribedAudio {
            public var flags: Int32
            public var transcriptionId: Int64
            public var text: String
            public var trialRemainsNum: Int32?
            public var trialRemainsUntilDate: Int32?
            public init(flags: Int32, transcriptionId: Int64, text: String, trialRemainsNum: Int32?, trialRemainsUntilDate: Int32?) {
                self.flags = flags
                self.transcriptionId = transcriptionId
                self.text = text
                self.trialRemainsNum = trialRemainsNum
                self.trialRemainsUntilDate = trialRemainsUntilDate
            }
        }
        case transcribedAudio(Cons_transcribedAudio)

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
        public class Cons_translateResult {
            public var result: [Api.TextWithEntities]
            public init(result: [Api.TextWithEntities]) {
                self.result = result
            }
        }
        case translateResult(Cons_translateResult)

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
        public class Cons_votesList {
            public var flags: Int32
            public var count: Int32
            public var votes: [Api.MessagePeerVote]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var nextOffset: String?
            public init(flags: Int32, count: Int32, votes: [Api.MessagePeerVote], chats: [Api.Chat], users: [Api.User], nextOffset: String?) {
                self.flags = flags
                self.count = count
                self.votes = votes
                self.chats = chats
                self.users = users
                self.nextOffset = nextOffset
            }
        }
        case votesList(Cons_votesList)

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
        public class Cons_webPage {
            public var webpage: Api.WebPage
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(webpage: Api.WebPage, chats: [Api.Chat], users: [Api.User]) {
                self.webpage = webpage
                self.chats = chats
                self.users = users
            }
        }
        case webPage(Cons_webPage)

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
        public class Cons_webPagePreview {
            public var media: Api.MessageMedia
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(media: Api.MessageMedia, chats: [Api.Chat], users: [Api.User]) {
                self.media = media
                self.chats = chats
                self.users = users
            }
        }
        case webPagePreview(Cons_webPagePreview)

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
        public class Cons_bankCardData {
            public var title: String
            public var openUrls: [Api.BankCardOpenUrl]
            public init(title: String, openUrls: [Api.BankCardOpenUrl]) {
                self.title = title
                self.openUrls = openUrls
            }
        }
        case bankCardData(Cons_bankCardData)

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
        public class Cons_checkCanSendGiftResultFail {
            public var reason: Api.TextWithEntities
            public init(reason: Api.TextWithEntities) {
                self.reason = reason
            }
        }
        case checkCanSendGiftResultFail(Cons_checkCanSendGiftResultFail)
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
        public class Cons_checkedGiftCode {
            public var flags: Int32
            public var fromId: Api.Peer?
            public var giveawayMsgId: Int32?
            public var toId: Int64?
            public var date: Int32
            public var days: Int32
            public var usedDate: Int32?
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, fromId: Api.Peer?, giveawayMsgId: Int32?, toId: Int64?, date: Int32, days: Int32, usedDate: Int32?, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.fromId = fromId
                self.giveawayMsgId = giveawayMsgId
                self.toId = toId
                self.date = date
                self.days = days
                self.usedDate = usedDate
                self.chats = chats
                self.users = users
            }
        }
        case checkedGiftCode(Cons_checkedGiftCode)

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
        public class Cons_connectedStarRefBots {
            public var count: Int32
            public var connectedBots: [Api.ConnectedBotStarRef]
            public var users: [Api.User]
            public init(count: Int32, connectedBots: [Api.ConnectedBotStarRef], users: [Api.User]) {
                self.count = count
                self.connectedBots = connectedBots
                self.users = users
            }
        }
        case connectedStarRefBots(Cons_connectedStarRefBots)

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
        public class Cons_exportedInvoice {
            public var url: String
            public init(url: String) {
                self.url = url
            }
        }
        case exportedInvoice(Cons_exportedInvoice)

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
        public class Cons_giveawayInfo {
            public var flags: Int32
            public var startDate: Int32
            public var joinedTooEarlyDate: Int32?
            public var adminDisallowedChatId: Int64?
            public var disallowedCountry: String?
            public init(flags: Int32, startDate: Int32, joinedTooEarlyDate: Int32?, adminDisallowedChatId: Int64?, disallowedCountry: String?) {
                self.flags = flags
                self.startDate = startDate
                self.joinedTooEarlyDate = joinedTooEarlyDate
                self.adminDisallowedChatId = adminDisallowedChatId
                self.disallowedCountry = disallowedCountry
            }
        }
        public class Cons_giveawayInfoResults {
            public var flags: Int32
            public var startDate: Int32
            public var giftCodeSlug: String?
            public var starsPrize: Int64?
            public var finishDate: Int32
            public var winnersCount: Int32
            public var activatedCount: Int32?
            public init(flags: Int32, startDate: Int32, giftCodeSlug: String?, starsPrize: Int64?, finishDate: Int32, winnersCount: Int32, activatedCount: Int32?) {
                self.flags = flags
                self.startDate = startDate
                self.giftCodeSlug = giftCodeSlug
                self.starsPrize = starsPrize
                self.finishDate = finishDate
                self.winnersCount = winnersCount
                self.activatedCount = activatedCount
            }
        }
        case giveawayInfo(Cons_giveawayInfo)
        case giveawayInfoResults(Cons_giveawayInfoResults)

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
        public class Cons_paymentForm {
            public var flags: Int32
            public var formId: Int64
            public var botId: Int64
            public var title: String
            public var description: String
            public var photo: Api.WebDocument?
            public var invoice: Api.Invoice
            public var providerId: Int64
            public var url: String
            public var nativeProvider: String?
            public var nativeParams: Api.DataJSON?
            public var additionalMethods: [Api.PaymentFormMethod]?
            public var savedInfo: Api.PaymentRequestedInfo?
            public var savedCredentials: [Api.PaymentSavedCredentials]?
            public var users: [Api.User]
            public init(flags: Int32, formId: Int64, botId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, providerId: Int64, url: String, nativeProvider: String?, nativeParams: Api.DataJSON?, additionalMethods: [Api.PaymentFormMethod]?, savedInfo: Api.PaymentRequestedInfo?, savedCredentials: [Api.PaymentSavedCredentials]?, users: [Api.User]) {
                self.flags = flags
                self.formId = formId
                self.botId = botId
                self.title = title
                self.description = description
                self.photo = photo
                self.invoice = invoice
                self.providerId = providerId
                self.url = url
                self.nativeProvider = nativeProvider
                self.nativeParams = nativeParams
                self.additionalMethods = additionalMethods
                self.savedInfo = savedInfo
                self.savedCredentials = savedCredentials
                self.users = users
            }
        }
        public class Cons_paymentFormStarGift {
            public var formId: Int64
            public var invoice: Api.Invoice
            public init(formId: Int64, invoice: Api.Invoice) {
                self.formId = formId
                self.invoice = invoice
            }
        }
        public class Cons_paymentFormStars {
            public var flags: Int32
            public var formId: Int64
            public var botId: Int64
            public var title: String
            public var description: String
            public var photo: Api.WebDocument?
            public var invoice: Api.Invoice
            public var users: [Api.User]
            public init(flags: Int32, formId: Int64, botId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, users: [Api.User]) {
                self.flags = flags
                self.formId = formId
                self.botId = botId
                self.title = title
                self.description = description
                self.photo = photo
                self.invoice = invoice
                self.users = users
            }
        }
        case paymentForm(Cons_paymentForm)
        case paymentFormStarGift(Cons_paymentFormStarGift)
        case paymentFormStars(Cons_paymentFormStars)

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
