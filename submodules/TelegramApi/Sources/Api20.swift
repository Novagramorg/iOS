public extension Api {
    enum PhoneCallDiscardReason: TypeConstructorDescription {
        case phoneCallDiscardReasonBusy
        case phoneCallDiscardReasonDisconnect
        case phoneCallDiscardReasonHangup
        case phoneCallDiscardReasonMigrateConferenceCall(slug: String)
        case phoneCallDiscardReasonMissed

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

        public static func parse_phoneCallDiscardReasonBusy(_ reader: BufferReader) -> PhoneCallDiscardReason? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_phoneCallDiscardReasonDisconnect(_ reader: BufferReader) -> PhoneCallDiscardReason? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_phoneCallDiscardReasonHangup(_ reader: BufferReader) -> PhoneCallDiscardReason? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_phoneCallDiscardReasonMigrateConferenceCall(_ reader: BufferReader) -> PhoneCallDiscardReason? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_phoneCallDiscardReasonMissed(_ reader: BufferReader) -> PhoneCallDiscardReason? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PhoneCallProtocol: TypeConstructorDescription {
        case phoneCallProtocol(flags: Int32, minLayer: Int32, maxLayer: Int32, libraryVersions: [String])

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

        public static func parse_phoneCallProtocol(_ reader: BufferReader) -> PhoneCallProtocol? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PhoneConnection: TypeConstructorDescription {
        case phoneConnection(flags: Int32, id: Int64, ip: String, ipv6: String, port: Int32, peerTag: Buffer)
        case phoneConnectionWebrtc(flags: Int32, id: Int64, ip: String, ipv6: String, port: Int32, username: String, password: String)

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

        public static func parse_phoneConnection(_ reader: BufferReader) -> PhoneConnection? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_phoneConnectionWebrtc(_ reader: BufferReader) -> PhoneConnection? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Photo: TypeConstructorDescription {
        case photo(flags: Int32, id: Int64, accessHash: Int64, fileReference: Buffer, date: Int32, sizes: [Api.PhotoSize], videoSizes: [Api.VideoSize]?, dcId: Int32)
        case photoEmpty(id: Int64)

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

        public static func parse_photo(_ reader: BufferReader) -> Photo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_photoEmpty(_ reader: BufferReader) -> Photo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PhotoSize: TypeConstructorDescription {
        case photoCachedSize(type: String, w: Int32, h: Int32, bytes: Buffer)
        case photoPathSize(type: String, bytes: Buffer)
        case photoSize(type: String, w: Int32, h: Int32, size: Int32)
        case photoSizeEmpty(type: String)
        case photoSizeProgressive(type: String, w: Int32, h: Int32, sizes: [Int32])
        case photoStrippedSize(type: String, bytes: Buffer)

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

        public static func parse_photoCachedSize(_ reader: BufferReader) -> PhotoSize? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_photoPathSize(_ reader: BufferReader) -> PhotoSize? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_photoSize(_ reader: BufferReader) -> PhotoSize? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_photoSizeEmpty(_ reader: BufferReader) -> PhotoSize? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_photoSizeProgressive(_ reader: BufferReader) -> PhotoSize? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_photoStrippedSize(_ reader: BufferReader) -> PhotoSize? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Poll: TypeConstructorDescription {
        case poll(id: Int64, flags: Int32, question: Api.TextWithEntities, answers: [Api.PollAnswer], closePeriod: Int32?, closeDate: Int32?)

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

        public static func parse_poll(_ reader: BufferReader) -> Poll? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PollAnswer: TypeConstructorDescription {
        case pollAnswer(text: Api.TextWithEntities, option: Buffer)

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

        public static func parse_pollAnswer(_ reader: BufferReader) -> PollAnswer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PollAnswerVoters: TypeConstructorDescription {
        case pollAnswerVoters(flags: Int32, option: Buffer, voters: Int32)

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

        public static func parse_pollAnswerVoters(_ reader: BufferReader) -> PollAnswerVoters? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PollResults: TypeConstructorDescription {
        case pollResults(flags: Int32, results: [Api.PollAnswerVoters]?, totalVoters: Int32?, recentVoters: [Api.Peer]?, solution: String?, solutionEntities: [Api.MessageEntity]?)

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

        public static func parse_pollResults(_ reader: BufferReader) -> PollResults? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PopularContact: TypeConstructorDescription {
        case popularContact(clientId: Int64, importers: Int32)

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

        public static func parse_popularContact(_ reader: BufferReader) -> PopularContact? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PostAddress: TypeConstructorDescription {
        case postAddress(streetLine1: String, streetLine2: String, city: String, state: String, countryIso2: String, postCode: String)

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

        public static func parse_postAddress(_ reader: BufferReader) -> PostAddress? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PostInteractionCounters: TypeConstructorDescription {
        case postInteractionCountersMessage(msgId: Int32, views: Int32, forwards: Int32, reactions: Int32)
        case postInteractionCountersStory(storyId: Int32, views: Int32, forwards: Int32, reactions: Int32)

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

        public static func parse_postInteractionCountersMessage(_ reader: BufferReader) -> PostInteractionCounters? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_postInteractionCountersStory(_ reader: BufferReader) -> PostInteractionCounters? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PremiumGiftCodeOption: TypeConstructorDescription {
        case premiumGiftCodeOption(flags: Int32, users: Int32, months: Int32, storeProduct: String?, storeQuantity: Int32?, currency: String, amount: Int64)

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

        public static func parse_premiumGiftCodeOption(_ reader: BufferReader) -> PremiumGiftCodeOption? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PremiumSubscriptionOption: TypeConstructorDescription {
        case premiumSubscriptionOption(flags: Int32, transaction: String?, months: Int32, currency: String, amount: Int64, botUrl: String, storeProduct: String?)

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

        public static func parse_premiumSubscriptionOption(_ reader: BufferReader) -> PremiumSubscriptionOption? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PrepaidGiveaway: TypeConstructorDescription {
        case prepaidGiveaway(id: Int64, months: Int32, quantity: Int32, date: Int32)
        case prepaidStarsGiveaway(id: Int64, stars: Int64, quantity: Int32, boosts: Int32, date: Int32)

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

        public static func parse_prepaidGiveaway(_ reader: BufferReader) -> PrepaidGiveaway? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_prepaidStarsGiveaway(_ reader: BufferReader) -> PrepaidGiveaway? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PrivacyKey: TypeConstructorDescription {
        case privacyKeyAbout
        case privacyKeyAddedByPhone
        case privacyKeyBirthday
        case privacyKeyChatInvite
        case privacyKeyForwards
        case privacyKeyNoPaidMessages
        case privacyKeyPhoneCall
        case privacyKeyPhoneNumber
        case privacyKeyPhoneP2P
        case privacyKeyProfilePhoto
        case privacyKeySavedMusic
        case privacyKeyStarGiftsAutoSave
        case privacyKeyStatusTimestamp
        case privacyKeyVoiceMessages

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

        public static func parse_privacyKeyAbout(_ reader: BufferReader) -> PrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyKeyAddedByPhone(_ reader: BufferReader) -> PrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyKeyBirthday(_ reader: BufferReader) -> PrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyKeyChatInvite(_ reader: BufferReader) -> PrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyKeyForwards(_ reader: BufferReader) -> PrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyKeyNoPaidMessages(_ reader: BufferReader) -> PrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyKeyPhoneCall(_ reader: BufferReader) -> PrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyKeyPhoneNumber(_ reader: BufferReader) -> PrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyKeyPhoneP2P(_ reader: BufferReader) -> PrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyKeyProfilePhoto(_ reader: BufferReader) -> PrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyKeySavedMusic(_ reader: BufferReader) -> PrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyKeyStarGiftsAutoSave(_ reader: BufferReader) -> PrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyKeyStatusTimestamp(_ reader: BufferReader) -> PrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_privacyKeyVoiceMessages(_ reader: BufferReader) -> PrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
