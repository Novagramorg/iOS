public extension Api {
    indirect enum Updates: TypeConstructorDescription {
        case updateShort(update: Api.Update, date: Int32)
        case updateShortChatMessage(flags: Int32, id: Int32, fromId: Int64, chatId: Int64, message: String, pts: Int32, ptsCount: Int32, date: Int32, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int64?, replyTo: Api.MessageReplyHeader?, entities: [Api.MessageEntity]?, ttlPeriod: Int32?)
        case updateShortMessage(flags: Int32, id: Int32, userId: Int64, message: String, pts: Int32, ptsCount: Int32, date: Int32, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int64?, replyTo: Api.MessageReplyHeader?, entities: [Api.MessageEntity]?, ttlPeriod: Int32?)
        case updateShortSentMessage(flags: Int32, id: Int32, pts: Int32, ptsCount: Int32, date: Int32, media: Api.MessageMedia?, entities: [Api.MessageEntity]?, ttlPeriod: Int32?)
        case updates(updates: [Api.Update], users: [Api.User], chats: [Api.Chat], date: Int32, seq: Int32)
        case updatesCombined(updates: [Api.Update], users: [Api.User], chats: [Api.Chat], date: Int32, seqStart: Int32, seq: Int32)
        case updatesTooLong

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

        public static func parse_updateShort(_ reader: BufferReader) -> Updates? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateShortChatMessage(_ reader: BufferReader) -> Updates? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateShortMessage(_ reader: BufferReader) -> Updates? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updateShortSentMessage(_ reader: BufferReader) -> Updates? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updates(_ reader: BufferReader) -> Updates? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatesCombined(_ reader: BufferReader) -> Updates? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_updatesTooLong(_ reader: BufferReader) -> Updates? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum UrlAuthResult: TypeConstructorDescription {
        case urlAuthResultAccepted(url: String)
        case urlAuthResultDefault
        case urlAuthResultRequest(flags: Int32, bot: Api.User, domain: String)

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

        public static func parse_urlAuthResultAccepted(_ reader: BufferReader) -> UrlAuthResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_urlAuthResultDefault(_ reader: BufferReader) -> UrlAuthResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_urlAuthResultRequest(_ reader: BufferReader) -> UrlAuthResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum User: TypeConstructorDescription {
        case user(flags: Int32, flags2: Int32, id: Int64, accessHash: Int64?, firstName: String?, lastName: String?, username: String?, phone: String?, photo: Api.UserProfilePhoto?, status: Api.UserStatus?, botInfoVersion: Int32?, restrictionReason: [Api.RestrictionReason]?, botInlinePlaceholder: String?, langCode: String?, emojiStatus: Api.EmojiStatus?, usernames: [Api.Username]?, storiesMaxId: Api.RecentStory?, color: Api.PeerColor?, profileColor: Api.PeerColor?, botActiveUsers: Int32?, botVerificationIcon: Int64?, sendPaidMessagesStars: Int64?)
        case userEmpty(id: Int64)

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

        public static func parse_user(_ reader: BufferReader) -> User? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_userEmpty(_ reader: BufferReader) -> User? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum UserFull: TypeConstructorDescription {
        case userFull(flags: Int32, flags2: Int32, id: Int64, about: String?, settings: Api.PeerSettings, personalPhoto: Api.Photo?, profilePhoto: Api.Photo?, fallbackPhoto: Api.Photo?, notifySettings: Api.PeerNotifySettings, botInfo: Api.BotInfo?, pinnedMsgId: Int32?, commonChatsCount: Int32, folderId: Int32?, ttlPeriod: Int32?, theme: Api.ChatTheme?, privateForwardName: String?, botGroupAdminRights: Api.ChatAdminRights?, botBroadcastAdminRights: Api.ChatAdminRights?, wallpaper: Api.WallPaper?, stories: Api.PeerStories?, businessWorkHours: Api.BusinessWorkHours?, businessLocation: Api.BusinessLocation?, businessGreetingMessage: Api.BusinessGreetingMessage?, businessAwayMessage: Api.BusinessAwayMessage?, businessIntro: Api.BusinessIntro?, birthday: Api.Birthday?, personalChannelId: Int64?, personalChannelMessage: Int32?, stargiftsCount: Int32?, starrefProgram: Api.StarRefProgram?, botVerification: Api.BotVerification?, sendPaidMessagesStars: Int64?, disallowedGifts: Api.DisallowedGiftsSettings?, starsRating: Api.StarsRating?, starsMyPendingRating: Api.StarsRating?, starsMyPendingRatingDate: Int32?, mainTab: Api.ProfileTab?, savedMusic: Api.Document?, note: Api.TextWithEntities?)

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

        public static func parse_userFull(_ reader: BufferReader) -> UserFull? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum UserProfilePhoto: TypeConstructorDescription {
        case userProfilePhoto(flags: Int32, photoId: Int64, strippedThumb: Buffer?, dcId: Int32)
        case userProfilePhotoEmpty

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

        public static func parse_userProfilePhoto(_ reader: BufferReader) -> UserProfilePhoto? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_userProfilePhotoEmpty(_ reader: BufferReader) -> UserProfilePhoto? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum UserStatus: TypeConstructorDescription {
        case userStatusEmpty
        case userStatusLastMonth(flags: Int32)
        case userStatusLastWeek(flags: Int32)
        case userStatusOffline(wasOnline: Int32)
        case userStatusOnline(expires: Int32)
        case userStatusRecently(flags: Int32)

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

        public static func parse_userStatusEmpty(_ reader: BufferReader) -> UserStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_userStatusLastMonth(_ reader: BufferReader) -> UserStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_userStatusLastWeek(_ reader: BufferReader) -> UserStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_userStatusOffline(_ reader: BufferReader) -> UserStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_userStatusOnline(_ reader: BufferReader) -> UserStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_userStatusRecently(_ reader: BufferReader) -> UserStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Username: TypeConstructorDescription {
        case username(flags: Int32, username: String)

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

        public static func parse_username(_ reader: BufferReader) -> Username? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum VideoSize: TypeConstructorDescription {
        case videoSize(flags: Int32, type: String, w: Int32, h: Int32, size: Int32, videoStartTs: Double?)
        case videoSizeEmojiMarkup(emojiId: Int64, backgroundColors: [Int32])
        case videoSizeStickerMarkup(stickerset: Api.InputStickerSet, stickerId: Int64, backgroundColors: [Int32])

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

        public static func parse_videoSize(_ reader: BufferReader) -> VideoSize? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_videoSizeEmojiMarkup(_ reader: BufferReader) -> VideoSize? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_videoSizeStickerMarkup(_ reader: BufferReader) -> VideoSize? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum WallPaper: TypeConstructorDescription {
        case wallPaper(id: Int64, flags: Int32, accessHash: Int64, slug: String, document: Api.Document, settings: Api.WallPaperSettings?)
        case wallPaperNoFile(id: Int64, flags: Int32, settings: Api.WallPaperSettings?)

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

        public static func parse_wallPaper(_ reader: BufferReader) -> WallPaper? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_wallPaperNoFile(_ reader: BufferReader) -> WallPaper? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum WallPaperSettings: TypeConstructorDescription {
        case wallPaperSettings(flags: Int32, backgroundColor: Int32?, secondBackgroundColor: Int32?, thirdBackgroundColor: Int32?, fourthBackgroundColor: Int32?, intensity: Int32?, rotation: Int32?, emoticon: String?)

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

        public static func parse_wallPaperSettings(_ reader: BufferReader) -> WallPaperSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum WebAuthorization: TypeConstructorDescription {
        case webAuthorization(hash: Int64, botId: Int64, domain: String, browser: String, platform: String, dateCreated: Int32, dateActive: Int32, ip: String, region: String)

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

        public static func parse_webAuthorization(_ reader: BufferReader) -> WebAuthorization? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum WebDocument: TypeConstructorDescription {
        case webDocument(url: String, accessHash: Int64, size: Int32, mimeType: String, attributes: [Api.DocumentAttribute])
        case webDocumentNoProxy(url: String, size: Int32, mimeType: String, attributes: [Api.DocumentAttribute])

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

        public static func parse_webDocument(_ reader: BufferReader) -> WebDocument? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_webDocumentNoProxy(_ reader: BufferReader) -> WebDocument? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum WebPage: TypeConstructorDescription {
        case webPage(flags: Int32, id: Int64, url: String, displayUrl: String, hash: Int32, type: String?, siteName: String?, title: String?, description: String?, photo: Api.Photo?, embedUrl: String?, embedType: String?, embedWidth: Int32?, embedHeight: Int32?, duration: Int32?, author: String?, document: Api.Document?, cachedPage: Api.Page?, attributes: [Api.WebPageAttribute]?)
        case webPageEmpty(flags: Int32, id: Int64, url: String?)
        case webPageNotModified(flags: Int32, cachedPageViews: Int32?)
        case webPagePending(flags: Int32, id: Int64, url: String?, date: Int32)

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
        public static func parse_webPageEmpty(_ reader: BufferReader) -> WebPage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_webPageNotModified(_ reader: BufferReader) -> WebPage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_webPagePending(_ reader: BufferReader) -> WebPage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
