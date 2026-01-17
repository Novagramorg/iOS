public extension Api {
    enum PhoneCallDiscardReason: TypeConstructorDescription {
        public class Cons_phoneCallDiscardReasonMigrateConferenceCall {
            public var slug: String
            public init(slug: String) {
                self.slug = slug
            }
        }
        case phoneCallDiscardReasonBusy
        case phoneCallDiscardReasonDisconnect
        case phoneCallDiscardReasonHangup
        case phoneCallDiscardReasonMigrateConferenceCall(Cons_phoneCallDiscardReasonMigrateConferenceCall)
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
        public class Cons_phoneCallProtocol {
            public var flags: Int32
            public var minLayer: Int32
            public var maxLayer: Int32
            public var libraryVersions: [String]
            public init(flags: Int32, minLayer: Int32, maxLayer: Int32, libraryVersions: [String]) {
                self.flags = flags
                self.minLayer = minLayer
                self.maxLayer = maxLayer
                self.libraryVersions = libraryVersions
            }
        }
        case phoneCallProtocol(Cons_phoneCallProtocol)

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
        public class Cons_phoneConnection {
            public var flags: Int32
            public var id: Int64
            public var ip: String
            public var ipv6: String
            public var port: Int32
            public var peerTag: Buffer
            public init(flags: Int32, id: Int64, ip: String, ipv6: String, port: Int32, peerTag: Buffer) {
                self.flags = flags
                self.id = id
                self.ip = ip
                self.ipv6 = ipv6
                self.port = port
                self.peerTag = peerTag
            }
        }
        public class Cons_phoneConnectionWebrtc {
            public var flags: Int32
            public var id: Int64
            public var ip: String
            public var ipv6: String
            public var port: Int32
            public var username: String
            public var password: String
            public init(flags: Int32, id: Int64, ip: String, ipv6: String, port: Int32, username: String, password: String) {
                self.flags = flags
                self.id = id
                self.ip = ip
                self.ipv6 = ipv6
                self.port = port
                self.username = username
                self.password = password
            }
        }
        case phoneConnection(Cons_phoneConnection)
        case phoneConnectionWebrtc(Cons_phoneConnectionWebrtc)

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
        public class Cons_photo {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var fileReference: Buffer
            public var date: Int32
            public var sizes: [Api.PhotoSize]
            public var videoSizes: [Api.VideoSize]?
            public var dcId: Int32
            public init(flags: Int32, id: Int64, accessHash: Int64, fileReference: Buffer, date: Int32, sizes: [Api.PhotoSize], videoSizes: [Api.VideoSize]?, dcId: Int32) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.fileReference = fileReference
                self.date = date
                self.sizes = sizes
                self.videoSizes = videoSizes
                self.dcId = dcId
            }
        }
        public class Cons_photoEmpty {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
        }
        case photo(Cons_photo)
        case photoEmpty(Cons_photoEmpty)

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
        public class Cons_photoCachedSize {
            public var type: String
            public var w: Int32
            public var h: Int32
            public var bytes: Buffer
            public init(type: String, w: Int32, h: Int32, bytes: Buffer) {
                self.type = type
                self.w = w
                self.h = h
                self.bytes = bytes
            }
        }
        public class Cons_photoPathSize {
            public var type: String
            public var bytes: Buffer
            public init(type: String, bytes: Buffer) {
                self.type = type
                self.bytes = bytes
            }
        }
        public class Cons_photoSize {
            public var type: String
            public var w: Int32
            public var h: Int32
            public var size: Int32
            public init(type: String, w: Int32, h: Int32, size: Int32) {
                self.type = type
                self.w = w
                self.h = h
                self.size = size
            }
        }
        public class Cons_photoSizeEmpty {
            public var type: String
            public init(type: String) {
                self.type = type
            }
        }
        public class Cons_photoSizeProgressive {
            public var type: String
            public var w: Int32
            public var h: Int32
            public var sizes: [Int32]
            public init(type: String, w: Int32, h: Int32, sizes: [Int32]) {
                self.type = type
                self.w = w
                self.h = h
                self.sizes = sizes
            }
        }
        public class Cons_photoStrippedSize {
            public var type: String
            public var bytes: Buffer
            public init(type: String, bytes: Buffer) {
                self.type = type
                self.bytes = bytes
            }
        }
        case photoCachedSize(Cons_photoCachedSize)
        case photoPathSize(Cons_photoPathSize)
        case photoSize(Cons_photoSize)
        case photoSizeEmpty(Cons_photoSizeEmpty)
        case photoSizeProgressive(Cons_photoSizeProgressive)
        case photoStrippedSize(Cons_photoStrippedSize)

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
        public class Cons_poll {
            public var id: Int64
            public var flags: Int32
            public var question: Api.TextWithEntities
            public var answers: [Api.PollAnswer]
            public var closePeriod: Int32?
            public var closeDate: Int32?
            public init(id: Int64, flags: Int32, question: Api.TextWithEntities, answers: [Api.PollAnswer], closePeriod: Int32?, closeDate: Int32?) {
                self.id = id
                self.flags = flags
                self.question = question
                self.answers = answers
                self.closePeriod = closePeriod
                self.closeDate = closeDate
            }
        }
        case poll(Cons_poll)

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
        public class Cons_pollAnswer {
            public var text: Api.TextWithEntities
            public var option: Buffer
            public init(text: Api.TextWithEntities, option: Buffer) {
                self.text = text
                self.option = option
            }
        }
        case pollAnswer(Cons_pollAnswer)

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
        public class Cons_pollAnswerVoters {
            public var flags: Int32
            public var option: Buffer
            public var voters: Int32
            public init(flags: Int32, option: Buffer, voters: Int32) {
                self.flags = flags
                self.option = option
                self.voters = voters
            }
        }
        case pollAnswerVoters(Cons_pollAnswerVoters)

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
        public class Cons_pollResults {
            public var flags: Int32
            public var results: [Api.PollAnswerVoters]?
            public var totalVoters: Int32?
            public var recentVoters: [Api.Peer]?
            public var solution: String?
            public var solutionEntities: [Api.MessageEntity]?
            public init(flags: Int32, results: [Api.PollAnswerVoters]?, totalVoters: Int32?, recentVoters: [Api.Peer]?, solution: String?, solutionEntities: [Api.MessageEntity]?) {
                self.flags = flags
                self.results = results
                self.totalVoters = totalVoters
                self.recentVoters = recentVoters
                self.solution = solution
                self.solutionEntities = solutionEntities
            }
        }
        case pollResults(Cons_pollResults)

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
        public class Cons_popularContact {
            public var clientId: Int64
            public var importers: Int32
            public init(clientId: Int64, importers: Int32) {
                self.clientId = clientId
                self.importers = importers
            }
        }
        case popularContact(Cons_popularContact)

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
        public class Cons_postAddress {
            public var streetLine1: String
            public var streetLine2: String
            public var city: String
            public var state: String
            public var countryIso2: String
            public var postCode: String
            public init(streetLine1: String, streetLine2: String, city: String, state: String, countryIso2: String, postCode: String) {
                self.streetLine1 = streetLine1
                self.streetLine2 = streetLine2
                self.city = city
                self.state = state
                self.countryIso2 = countryIso2
                self.postCode = postCode
            }
        }
        case postAddress(Cons_postAddress)

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
