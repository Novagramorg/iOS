public extension Api {
    enum ReceivedNotifyMessage: TypeConstructorDescription {
        case receivedNotifyMessage(id: Int32, flags: Int32)

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
        case recentMeUrlChat(url: String, chatId: Int64)
        case recentMeUrlChatInvite(url: String, chatInvite: Api.ChatInvite)
        case recentMeUrlStickerSet(url: String, set: Api.StickerSetCovered)
        case recentMeUrlUnknown(url: String)
        case recentMeUrlUser(url: String, userId: Int64)

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
        case recentStory(flags: Int32, maxId: Int32?)

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
        case replyInlineMarkup(rows: [Api.KeyboardButtonRow])
        case replyKeyboardForceReply(flags: Int32, placeholder: String?)
        case replyKeyboardHide(flags: Int32)
        case replyKeyboardMarkup(flags: Int32, rows: [Api.KeyboardButtonRow], placeholder: String?)

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
        case reportResultAddComment(flags: Int32, option: Buffer)
        case reportResultChooseOption(title: String, options: [Api.MessageReportOption])
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
        case requestPeerTypeBroadcast(flags: Int32, hasUsername: Api.Bool?, userAdminRights: Api.ChatAdminRights?, botAdminRights: Api.ChatAdminRights?)
        case requestPeerTypeChat(flags: Int32, hasUsername: Api.Bool?, forum: Api.Bool?, userAdminRights: Api.ChatAdminRights?, botAdminRights: Api.ChatAdminRights?)
        case requestPeerTypeUser(flags: Int32, bot: Api.Bool?, premium: Api.Bool?)

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
        case requestedPeerChannel(flags: Int32, channelId: Int64, title: String?, username: String?, photo: Api.Photo?)
        case requestedPeerChat(flags: Int32, chatId: Int64, title: String?, photo: Api.Photo?)
        case requestedPeerUser(flags: Int32, userId: Int64, firstName: String?, lastName: String?, username: String?, photo: Api.Photo?)

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
        case requirementToContactEmpty
        case requirementToContactPaidMessages(starsAmount: Int64)
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
