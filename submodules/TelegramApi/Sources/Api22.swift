public extension Api {
    enum ReceivedNotifyMessage: TypeConstructorDescription {
        public class Cons_receivedNotifyMessage {
            public var id: Int32
            public var flags: Int32
            public init(id: Int32, flags: Int32) {
                self.id = id
                self.flags = flags
            }
        }
        case receivedNotifyMessage(Cons_receivedNotifyMessage)

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

        public static func parse_receivedNotifyMessage(_ reader: BufferReader) -> ReceivedNotifyMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum RecentMeUrl: TypeConstructorDescription {
        public class Cons_recentMeUrlChat {
            public var url: String
            public var chatId: Int64
            public init(url: String, chatId: Int64) {
                self.url = url
                self.chatId = chatId
            }
        }
        public class Cons_recentMeUrlChatInvite {
            public var url: String
            public var chatInvite: Api.ChatInvite
            public init(url: String, chatInvite: Api.ChatInvite) {
                self.url = url
                self.chatInvite = chatInvite
            }
        }
        public class Cons_recentMeUrlStickerSet {
            public var url: String
            public var set: Api.StickerSetCovered
            public init(url: String, set: Api.StickerSetCovered) {
                self.url = url
                self.set = set
            }
        }
        public class Cons_recentMeUrlUnknown {
            public var url: String
            public init(url: String) {
                self.url = url
            }
        }
        public class Cons_recentMeUrlUser {
            public var url: String
            public var userId: Int64
            public init(url: String, userId: Int64) {
                self.url = url
                self.userId = userId
            }
        }
        case recentMeUrlChat(Cons_recentMeUrlChat)
        case recentMeUrlChatInvite(Cons_recentMeUrlChatInvite)
        case recentMeUrlStickerSet(Cons_recentMeUrlStickerSet)
        case recentMeUrlUnknown(Cons_recentMeUrlUnknown)
        case recentMeUrlUser(Cons_recentMeUrlUser)

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

        public static func parse_recentMeUrlChat(_ reader: BufferReader) -> RecentMeUrl? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_recentMeUrlChatInvite(_ reader: BufferReader) -> RecentMeUrl? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_recentMeUrlStickerSet(_ reader: BufferReader) -> RecentMeUrl? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_recentMeUrlUnknown(_ reader: BufferReader) -> RecentMeUrl? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_recentMeUrlUser(_ reader: BufferReader) -> RecentMeUrl? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum RecentStory: TypeConstructorDescription {
        public class Cons_recentStory {
            public var flags: Int32
            public var maxId: Int32?
            public init(flags: Int32, maxId: Int32?) {
                self.flags = flags
                self.maxId = maxId
            }
        }
        case recentStory(Cons_recentStory)

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

        public static func parse_recentStory(_ reader: BufferReader) -> RecentStory? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ReplyMarkup: TypeConstructorDescription {
        public class Cons_replyInlineMarkup {
            public var rows: [Api.KeyboardButtonRow]
            public init(rows: [Api.KeyboardButtonRow]) {
                self.rows = rows
            }
        }
        public class Cons_replyKeyboardForceReply {
            public var flags: Int32
            public var placeholder: String?
            public init(flags: Int32, placeholder: String?) {
                self.flags = flags
                self.placeholder = placeholder
            }
        }
        public class Cons_replyKeyboardHide {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        public class Cons_replyKeyboardMarkup {
            public var flags: Int32
            public var rows: [Api.KeyboardButtonRow]
            public var placeholder: String?
            public init(flags: Int32, rows: [Api.KeyboardButtonRow], placeholder: String?) {
                self.flags = flags
                self.rows = rows
                self.placeholder = placeholder
            }
        }
        case replyInlineMarkup(Cons_replyInlineMarkup)
        case replyKeyboardForceReply(Cons_replyKeyboardForceReply)
        case replyKeyboardHide(Cons_replyKeyboardHide)
        case replyKeyboardMarkup(Cons_replyKeyboardMarkup)

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

        public static func parse_replyInlineMarkup(_ reader: BufferReader) -> ReplyMarkup? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_replyKeyboardForceReply(_ reader: BufferReader) -> ReplyMarkup? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_replyKeyboardHide(_ reader: BufferReader) -> ReplyMarkup? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_replyKeyboardMarkup(_ reader: BufferReader) -> ReplyMarkup? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ReportReason: TypeConstructorDescription {
        case inputReportReasonChildAbuse
        case inputReportReasonCopyright
        case inputReportReasonFake
        case inputReportReasonGeoIrrelevant
        case inputReportReasonIllegalDrugs
        case inputReportReasonOther
        case inputReportReasonPersonalDetails
        case inputReportReasonPornography
        case inputReportReasonSpam
        case inputReportReasonViolence

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

        public static func parse_inputReportReasonChildAbuse(_ reader: BufferReader) -> ReportReason? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputReportReasonCopyright(_ reader: BufferReader) -> ReportReason? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputReportReasonFake(_ reader: BufferReader) -> ReportReason? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputReportReasonGeoIrrelevant(_ reader: BufferReader) -> ReportReason? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputReportReasonIllegalDrugs(_ reader: BufferReader) -> ReportReason? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputReportReasonOther(_ reader: BufferReader) -> ReportReason? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputReportReasonPersonalDetails(_ reader: BufferReader) -> ReportReason? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputReportReasonPornography(_ reader: BufferReader) -> ReportReason? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputReportReasonSpam(_ reader: BufferReader) -> ReportReason? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputReportReasonViolence(_ reader: BufferReader) -> ReportReason? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum ReportResult: TypeConstructorDescription {
        public class Cons_reportResultAddComment {
            public var flags: Int32
            public var option: Buffer
            public init(flags: Int32, option: Buffer) {
                self.flags = flags
                self.option = option
            }
        }
        public class Cons_reportResultChooseOption {
            public var title: String
            public var options: [Api.MessageReportOption]
            public init(title: String, options: [Api.MessageReportOption]) {
                self.title = title
                self.options = options
            }
        }
        case reportResultAddComment(Cons_reportResultAddComment)
        case reportResultChooseOption(Cons_reportResultChooseOption)
        case reportResultReported

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

        public static func parse_reportResultAddComment(_ reader: BufferReader) -> ReportResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_reportResultChooseOption(_ reader: BufferReader) -> ReportResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_reportResultReported(_ reader: BufferReader) -> ReportResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum RequestPeerType: TypeConstructorDescription {
        public class Cons_requestPeerTypeBroadcast {
            public var flags: Int32
            public var hasUsername: Api.Bool?
            public var userAdminRights: Api.ChatAdminRights?
            public var botAdminRights: Api.ChatAdminRights?
            public init(flags: Int32, hasUsername: Api.Bool?, userAdminRights: Api.ChatAdminRights?, botAdminRights: Api.ChatAdminRights?) {
                self.flags = flags
                self.hasUsername = hasUsername
                self.userAdminRights = userAdminRights
                self.botAdminRights = botAdminRights
            }
        }
        public class Cons_requestPeerTypeChat {
            public var flags: Int32
            public var hasUsername: Api.Bool?
            public var forum: Api.Bool?
            public var userAdminRights: Api.ChatAdminRights?
            public var botAdminRights: Api.ChatAdminRights?
            public init(flags: Int32, hasUsername: Api.Bool?, forum: Api.Bool?, userAdminRights: Api.ChatAdminRights?, botAdminRights: Api.ChatAdminRights?) {
                self.flags = flags
                self.hasUsername = hasUsername
                self.forum = forum
                self.userAdminRights = userAdminRights
                self.botAdminRights = botAdminRights
            }
        }
        public class Cons_requestPeerTypeUser {
            public var flags: Int32
            public var bot: Api.Bool?
            public var premium: Api.Bool?
            public init(flags: Int32, bot: Api.Bool?, premium: Api.Bool?) {
                self.flags = flags
                self.bot = bot
                self.premium = premium
            }
        }
        case requestPeerTypeBroadcast(Cons_requestPeerTypeBroadcast)
        case requestPeerTypeChat(Cons_requestPeerTypeChat)
        case requestPeerTypeUser(Cons_requestPeerTypeUser)

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

        public static func parse_requestPeerTypeBroadcast(_ reader: BufferReader) -> RequestPeerType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_requestPeerTypeChat(_ reader: BufferReader) -> RequestPeerType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_requestPeerTypeUser(_ reader: BufferReader) -> RequestPeerType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum RequestedPeer: TypeConstructorDescription {
        public class Cons_requestedPeerChannel {
            public var flags: Int32
            public var channelId: Int64
            public var title: String?
            public var username: String?
            public var photo: Api.Photo?
            public init(flags: Int32, channelId: Int64, title: String?, username: String?, photo: Api.Photo?) {
                self.flags = flags
                self.channelId = channelId
                self.title = title
                self.username = username
                self.photo = photo
            }
        }
        public class Cons_requestedPeerChat {
            public var flags: Int32
            public var chatId: Int64
            public var title: String?
            public var photo: Api.Photo?
            public init(flags: Int32, chatId: Int64, title: String?, photo: Api.Photo?) {
                self.flags = flags
                self.chatId = chatId
                self.title = title
                self.photo = photo
            }
        }
        public class Cons_requestedPeerUser {
            public var flags: Int32
            public var userId: Int64
            public var firstName: String?
            public var lastName: String?
            public var username: String?
            public var photo: Api.Photo?
            public init(flags: Int32, userId: Int64, firstName: String?, lastName: String?, username: String?, photo: Api.Photo?) {
                self.flags = flags
                self.userId = userId
                self.firstName = firstName
                self.lastName = lastName
                self.username = username
                self.photo = photo
            }
        }
        case requestedPeerChannel(Cons_requestedPeerChannel)
        case requestedPeerChat(Cons_requestedPeerChat)
        case requestedPeerUser(Cons_requestedPeerUser)

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

        public static func parse_requestedPeerChannel(_ reader: BufferReader) -> RequestedPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_requestedPeerChat(_ reader: BufferReader) -> RequestedPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_requestedPeerUser(_ reader: BufferReader) -> RequestedPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum RequirementToContact: TypeConstructorDescription {
        public class Cons_requirementToContactPaidMessages {
            public var starsAmount: Int64
            public init(starsAmount: Int64) {
                self.starsAmount = starsAmount
            }
        }
        case requirementToContactEmpty
        case requirementToContactPaidMessages(Cons_requirementToContactPaidMessages)
        case requirementToContactPremium

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

        public static func parse_requirementToContactEmpty(_ reader: BufferReader) -> RequirementToContact? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_requirementToContactPaidMessages(_ reader: BufferReader) -> RequirementToContact? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_requirementToContactPremium(_ reader: BufferReader) -> RequirementToContact? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
