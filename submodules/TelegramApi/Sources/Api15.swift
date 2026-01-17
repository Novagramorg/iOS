public extension Api {
    enum KeyboardButtonRow: TypeConstructorDescription {
        public class Cons_keyboardButtonRow {
            public var buttons: [Api.KeyboardButton]
            public init(buttons: [Api.KeyboardButton]) {
                self.buttons = buttons
            }
        }
        case keyboardButtonRow(Cons_keyboardButtonRow)

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

        public static func parse_keyboardButtonRow(_ reader: BufferReader) -> KeyboardButtonRow? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum LabeledPrice: TypeConstructorDescription {
        public class Cons_labeledPrice {
            public var label: String
            public var amount: Int64
            public init(label: String, amount: Int64) {
                self.label = label
                self.amount = amount
            }
        }
        case labeledPrice(Cons_labeledPrice)

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

        public static func parse_labeledPrice(_ reader: BufferReader) -> LabeledPrice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum LangPackDifference: TypeConstructorDescription {
        public class Cons_langPackDifference {
            public var langCode: String
            public var fromVersion: Int32
            public var version: Int32
            public var strings: [Api.LangPackString]
            public init(langCode: String, fromVersion: Int32, version: Int32, strings: [Api.LangPackString]) {
                self.langCode = langCode
                self.fromVersion = fromVersion
                self.version = version
                self.strings = strings
            }
        }
        case langPackDifference(Cons_langPackDifference)

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

        public static func parse_langPackDifference(_ reader: BufferReader) -> LangPackDifference? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum LangPackLanguage: TypeConstructorDescription {
        public class Cons_langPackLanguage {
            public var flags: Int32
            public var name: String
            public var nativeName: String
            public var langCode: String
            public var baseLangCode: String?
            public var pluralCode: String
            public var stringsCount: Int32
            public var translatedCount: Int32
            public var translationsUrl: String
            public init(flags: Int32, name: String, nativeName: String, langCode: String, baseLangCode: String?, pluralCode: String, stringsCount: Int32, translatedCount: Int32, translationsUrl: String) {
                self.flags = flags
                self.name = name
                self.nativeName = nativeName
                self.langCode = langCode
                self.baseLangCode = baseLangCode
                self.pluralCode = pluralCode
                self.stringsCount = stringsCount
                self.translatedCount = translatedCount
                self.translationsUrl = translationsUrl
            }
        }
        case langPackLanguage(Cons_langPackLanguage)

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

        public static func parse_langPackLanguage(_ reader: BufferReader) -> LangPackLanguage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum LangPackString: TypeConstructorDescription {
        public class Cons_langPackString {
            public var key: String
            public var value: String
            public init(key: String, value: String) {
                self.key = key
                self.value = value
            }
        }
        public class Cons_langPackStringDeleted {
            public var key: String
            public init(key: String) {
                self.key = key
            }
        }
        public class Cons_langPackStringPluralized {
            public var flags: Int32
            public var key: String
            public var zeroValue: String?
            public var oneValue: String?
            public var twoValue: String?
            public var fewValue: String?
            public var manyValue: String?
            public var otherValue: String
            public init(flags: Int32, key: String, zeroValue: String?, oneValue: String?, twoValue: String?, fewValue: String?, manyValue: String?, otherValue: String) {
                self.flags = flags
                self.key = key
                self.zeroValue = zeroValue
                self.oneValue = oneValue
                self.twoValue = twoValue
                self.fewValue = fewValue
                self.manyValue = manyValue
                self.otherValue = otherValue
            }
        }
        case langPackString(Cons_langPackString)
        case langPackStringDeleted(Cons_langPackStringDeleted)
        case langPackStringPluralized(Cons_langPackStringPluralized)

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

        public static func parse_langPackString(_ reader: BufferReader) -> LangPackString? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_langPackStringDeleted(_ reader: BufferReader) -> LangPackString? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_langPackStringPluralized(_ reader: BufferReader) -> LangPackString? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum MaskCoords: TypeConstructorDescription {
        case maskCoords(n: Int32, x: Double, y: Double, zoom: Double)

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

        public static func parse_maskCoords(_ reader: BufferReader) -> MaskCoords? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum MediaArea: TypeConstructorDescription {
        case inputMediaAreaChannelPost(coordinates: Api.MediaAreaCoordinates, channel: Api.InputChannel, msgId: Int32)
        case inputMediaAreaVenue(coordinates: Api.MediaAreaCoordinates, queryId: Int64, resultId: String)
        case mediaAreaChannelPost(coordinates: Api.MediaAreaCoordinates, channelId: Int64, msgId: Int32)
        case mediaAreaGeoPoint(flags: Int32, coordinates: Api.MediaAreaCoordinates, geo: Api.GeoPoint, address: Api.GeoPointAddress?)
        case mediaAreaStarGift(coordinates: Api.MediaAreaCoordinates, slug: String)
        case mediaAreaSuggestedReaction(flags: Int32, coordinates: Api.MediaAreaCoordinates, reaction: Api.Reaction)
        case mediaAreaUrl(coordinates: Api.MediaAreaCoordinates, url: String)
        case mediaAreaVenue(coordinates: Api.MediaAreaCoordinates, geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String)
        case mediaAreaWeather(coordinates: Api.MediaAreaCoordinates, emoji: String, temperatureC: Double, color: Int32)

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

        public static func parse_inputMediaAreaChannelPost(_ reader: BufferReader) -> MediaArea? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaAreaVenue(_ reader: BufferReader) -> MediaArea? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_mediaAreaChannelPost(_ reader: BufferReader) -> MediaArea? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_mediaAreaGeoPoint(_ reader: BufferReader) -> MediaArea? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_mediaAreaStarGift(_ reader: BufferReader) -> MediaArea? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_mediaAreaSuggestedReaction(_ reader: BufferReader) -> MediaArea? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_mediaAreaUrl(_ reader: BufferReader) -> MediaArea? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_mediaAreaVenue(_ reader: BufferReader) -> MediaArea? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_mediaAreaWeather(_ reader: BufferReader) -> MediaArea? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum MediaAreaCoordinates: TypeConstructorDescription {
        case mediaAreaCoordinates(flags: Int32, x: Double, y: Double, w: Double, h: Double, rotation: Double, radius: Double?)

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

        public static func parse_mediaAreaCoordinates(_ reader: BufferReader) -> MediaAreaCoordinates? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum Message: TypeConstructorDescription {
        case message(flags: Int32, flags2: Int32, id: Int32, fromId: Api.Peer?, fromBoostsApplied: Int32?, peerId: Api.Peer, savedPeerId: Api.Peer?, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int64?, viaBusinessBotId: Int64?, replyTo: Api.MessageReplyHeader?, date: Int32, message: String, media: Api.MessageMedia?, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, views: Int32?, forwards: Int32?, replies: Api.MessageReplies?, editDate: Int32?, postAuthor: String?, groupedId: Int64?, reactions: Api.MessageReactions?, restrictionReason: [Api.RestrictionReason]?, ttlPeriod: Int32?, quickReplyShortcutId: Int32?, effect: Int64?, factcheck: Api.FactCheck?, reportDeliveryUntilDate: Int32?, paidMessageStars: Int64?, suggestedPost: Api.SuggestedPost?, scheduleRepeatPeriod: Int32?, summaryFromLanguage: String?)
        case messageEmpty(flags: Int32, id: Int32, peerId: Api.Peer?)
        case messageService(flags: Int32, id: Int32, fromId: Api.Peer?, peerId: Api.Peer, savedPeerId: Api.Peer?, replyTo: Api.MessageReplyHeader?, date: Int32, action: Api.MessageAction, reactions: Api.MessageReactions?, ttlPeriod: Int32?)

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

        public static func parse_message(_ reader: BufferReader) -> Message? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageEmpty(_ reader: BufferReader) -> Message? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageService(_ reader: BufferReader) -> Message? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum MessageAction: TypeConstructorDescription {
        case messageActionBoostApply(boosts: Int32)
        case messageActionBotAllowed(flags: Int32, domain: String?, app: Api.BotApp?)
        case messageActionChannelCreate(title: String)
        case messageActionChannelMigrateFrom(title: String, chatId: Int64)
        case messageActionChatAddUser(users: [Int64])
        case messageActionChatCreate(title: String, users: [Int64])
        case messageActionChatDeletePhoto
        case messageActionChatDeleteUser(userId: Int64)
        case messageActionChatEditPhoto(photo: Api.Photo)
        case messageActionChatEditTitle(title: String)
        case messageActionChatJoinedByLink(inviterId: Int64)
        case messageActionChatJoinedByRequest
        case messageActionChatMigrateTo(channelId: Int64)
        case messageActionConferenceCall(flags: Int32, callId: Int64, duration: Int32?, otherParticipants: [Api.Peer]?)
        case messageActionContactSignUp
        case messageActionCustomAction(message: String)
        case messageActionEmpty
        case messageActionGameScore(gameId: Int64, score: Int32)
        case messageActionGeoProximityReached(fromId: Api.Peer, toId: Api.Peer, distance: Int32)
        case messageActionGiftCode(flags: Int32, boostPeer: Api.Peer?, days: Int32, slug: String, currency: String?, amount: Int64?, cryptoCurrency: String?, cryptoAmount: Int64?, message: Api.TextWithEntities?)
        case messageActionGiftPremium(flags: Int32, currency: String, amount: Int64, days: Int32, cryptoCurrency: String?, cryptoAmount: Int64?, message: Api.TextWithEntities?)
        case messageActionGiftStars(flags: Int32, currency: String, amount: Int64, stars: Int64, cryptoCurrency: String?, cryptoAmount: Int64?, transactionId: String?)
        case messageActionGiftTon(flags: Int32, currency: String, amount: Int64, cryptoCurrency: String, cryptoAmount: Int64, transactionId: String?)
        case messageActionGiveawayLaunch(flags: Int32, stars: Int64?)
        case messageActionGiveawayResults(flags: Int32, winnersCount: Int32, unclaimedCount: Int32)
        case messageActionGroupCall(flags: Int32, call: Api.InputGroupCall, duration: Int32?)
        case messageActionGroupCallScheduled(call: Api.InputGroupCall, scheduleDate: Int32)
        case messageActionHistoryClear
        case messageActionInviteToGroupCall(call: Api.InputGroupCall, users: [Int64])
        case messageActionPaidMessagesPrice(flags: Int32, stars: Int64)
        case messageActionPaidMessagesRefunded(count: Int32, stars: Int64)
        case messageActionPaymentRefunded(flags: Int32, peer: Api.Peer, currency: String, totalAmount: Int64, payload: Buffer?, charge: Api.PaymentCharge)
        case messageActionPaymentSent(flags: Int32, currency: String, totalAmount: Int64, invoiceSlug: String?, subscriptionUntilDate: Int32?)
        case messageActionPaymentSentMe(flags: Int32, currency: String, totalAmount: Int64, payload: Buffer, info: Api.PaymentRequestedInfo?, shippingOptionId: String?, charge: Api.PaymentCharge, subscriptionUntilDate: Int32?)
        case messageActionPhoneCall(flags: Int32, callId: Int64, reason: Api.PhoneCallDiscardReason?, duration: Int32?)
        case messageActionPinMessage
        case messageActionPrizeStars(flags: Int32, stars: Int64, transactionId: String, boostPeer: Api.Peer, giveawayMsgId: Int32)
        case messageActionRequestedPeer(buttonId: Int32, peers: [Api.Peer])
        case messageActionRequestedPeerSentMe(buttonId: Int32, peers: [Api.RequestedPeer])
        case messageActionScreenshotTaken
        case messageActionSecureValuesSent(types: [Api.SecureValueType])
        case messageActionSecureValuesSentMe(values: [Api.SecureValue], credentials: Api.SecureCredentialsEncrypted)
        case messageActionSetChatTheme(theme: Api.ChatTheme)
        case messageActionSetChatWallPaper(flags: Int32, wallpaper: Api.WallPaper)
        case messageActionSetMessagesTTL(flags: Int32, period: Int32, autoSettingFrom: Int64?)
        case messageActionStarGift(flags: Int32, gift: Api.StarGift, message: Api.TextWithEntities?, convertStars: Int64?, upgradeMsgId: Int32?, upgradeStars: Int64?, fromId: Api.Peer?, peer: Api.Peer?, savedId: Int64?, prepaidUpgradeHash: String?, giftMsgId: Int32?, toId: Api.Peer?, giftNum: Int32?)
        case messageActionStarGiftCraftFail
        case messageActionStarGiftPurchaseOffer(flags: Int32, gift: Api.StarGift, price: Api.StarsAmount, expiresAt: Int32)
        case messageActionStarGiftPurchaseOfferDeclined(flags: Int32, gift: Api.StarGift, price: Api.StarsAmount)
        case messageActionStarGiftUnique(flags: Int32, gift: Api.StarGift, canExportAt: Int32?, transferStars: Int64?, fromId: Api.Peer?, peer: Api.Peer?, savedId: Int64?, resaleAmount: Api.StarsAmount?, canTransferAt: Int32?, canResellAt: Int32?, dropOriginalDetailsStars: Int64?, canCraftAt: Int32?, craftChancePermille: Int32?)
        case messageActionSuggestBirthday(birthday: Api.Birthday)
        case messageActionSuggestProfilePhoto(photo: Api.Photo)
        case messageActionSuggestedPostApproval(flags: Int32, rejectComment: String?, scheduleDate: Int32?, price: Api.StarsAmount?)
        case messageActionSuggestedPostRefund(flags: Int32)
        case messageActionSuggestedPostSuccess(price: Api.StarsAmount)
        case messageActionTodoAppendTasks(list: [Api.TodoItem])
        case messageActionTodoCompletions(completed: [Int32], incompleted: [Int32])
        case messageActionTopicCreate(flags: Int32, title: String, iconColor: Int32, iconEmojiId: Int64?)
        case messageActionTopicEdit(flags: Int32, title: String?, iconEmojiId: Int64?, closed: Api.Bool?, hidden: Api.Bool?)
        case messageActionWebViewDataSent(text: String)
        case messageActionWebViewDataSentMe(text: String, data: String)

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

        public static func parse_messageActionBoostApply(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionBotAllowed(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChannelCreate(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChannelMigrateFrom(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChatAddUser(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChatCreate(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChatDeletePhoto(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChatDeleteUser(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChatEditPhoto(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChatEditTitle(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChatJoinedByLink(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChatJoinedByRequest(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionChatMigrateTo(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionConferenceCall(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionContactSignUp(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionCustomAction(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionEmpty(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGameScore(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGeoProximityReached(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGiftCode(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGiftPremium(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGiftStars(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGiftTon(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGiveawayLaunch(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGiveawayResults(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGroupCall(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionGroupCallScheduled(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionHistoryClear(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionInviteToGroupCall(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionPaidMessagesPrice(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionPaidMessagesRefunded(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionPaymentRefunded(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionPaymentSent(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionPaymentSentMe(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionPhoneCall(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionPinMessage(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionPrizeStars(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionRequestedPeer(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionRequestedPeerSentMe(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionScreenshotTaken(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSecureValuesSent(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSecureValuesSentMe(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSetChatTheme(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSetChatWallPaper(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSetMessagesTTL(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionStarGift(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionStarGiftCraftFail(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionStarGiftPurchaseOffer(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionStarGiftPurchaseOfferDeclined(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionStarGiftUnique(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSuggestBirthday(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSuggestProfilePhoto(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSuggestedPostApproval(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSuggestedPostRefund(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionSuggestedPostSuccess(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionTodoAppendTasks(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionTodoCompletions(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionTopicCreate(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionTopicEdit(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionWebViewDataSent(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_messageActionWebViewDataSentMe(_ reader: BufferReader) -> MessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
