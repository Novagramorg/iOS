public extension Api {
    enum InputPaymentCredentials: TypeConstructorDescription {
        public class Cons_inputPaymentCredentials {
            public var flags: Int32
            public var data: Api.DataJSON
            public init(flags: Int32, data: Api.DataJSON) {
                self.flags = flags
                self.data = data
            }
        }
        public class Cons_inputPaymentCredentialsApplePay {
            public var paymentData: Api.DataJSON
            public init(paymentData: Api.DataJSON) {
                self.paymentData = paymentData
            }
        }
        public class Cons_inputPaymentCredentialsGooglePay {
            public var paymentToken: Api.DataJSON
            public init(paymentToken: Api.DataJSON) {
                self.paymentToken = paymentToken
            }
        }
        public class Cons_inputPaymentCredentialsSaved {
            public var id: String
            public var tmpPassword: Buffer
            public init(id: String, tmpPassword: Buffer) {
                self.id = id
                self.tmpPassword = tmpPassword
            }
        }
        case inputPaymentCredentials(Cons_inputPaymentCredentials)
        case inputPaymentCredentialsApplePay(Cons_inputPaymentCredentialsApplePay)
        case inputPaymentCredentialsGooglePay(Cons_inputPaymentCredentialsGooglePay)
        case inputPaymentCredentialsSaved(Cons_inputPaymentCredentialsSaved)

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

        public static func parse_inputPaymentCredentials(_ reader: BufferReader) -> InputPaymentCredentials? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPaymentCredentialsApplePay(_ reader: BufferReader) -> InputPaymentCredentials? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPaymentCredentialsGooglePay(_ reader: BufferReader) -> InputPaymentCredentials? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPaymentCredentialsSaved(_ reader: BufferReader) -> InputPaymentCredentials? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum InputPeer: TypeConstructorDescription {
        public class Cons_inputPeerChannel {
            public var channelId: Int64
            public var accessHash: Int64
            public init(channelId: Int64, accessHash: Int64) {
                self.channelId = channelId
                self.accessHash = accessHash
            }
        }
        public class Cons_inputPeerChannelFromMessage {
            public var peer: Api.InputPeer
            public var msgId: Int32
            public var channelId: Int64
            public init(peer: Api.InputPeer, msgId: Int32, channelId: Int64) {
                self.peer = peer
                self.msgId = msgId
                self.channelId = channelId
            }
        }
        public class Cons_inputPeerChat {
            public var chatId: Int64
            public init(chatId: Int64) {
                self.chatId = chatId
            }
        }
        public class Cons_inputPeerUser {
            public var userId: Int64
            public var accessHash: Int64
            public init(userId: Int64, accessHash: Int64) {
                self.userId = userId
                self.accessHash = accessHash
            }
        }
        public class Cons_inputPeerUserFromMessage {
            public var peer: Api.InputPeer
            public var msgId: Int32
            public var userId: Int64
            public init(peer: Api.InputPeer, msgId: Int32, userId: Int64) {
                self.peer = peer
                self.msgId = msgId
                self.userId = userId
            }
        }
        case inputPeerChannel(Cons_inputPeerChannel)
        case inputPeerChannelFromMessage(Cons_inputPeerChannelFromMessage)
        case inputPeerChat(Cons_inputPeerChat)
        case inputPeerEmpty
        case inputPeerSelf
        case inputPeerUser(Cons_inputPeerUser)
        case inputPeerUserFromMessage(Cons_inputPeerUserFromMessage)

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

        public static func parse_inputPeerChannel(_ reader: BufferReader) -> InputPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPeerChannelFromMessage(_ reader: BufferReader) -> InputPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPeerChat(_ reader: BufferReader) -> InputPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPeerEmpty(_ reader: BufferReader) -> InputPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPeerSelf(_ reader: BufferReader) -> InputPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPeerUser(_ reader: BufferReader) -> InputPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPeerUserFromMessage(_ reader: BufferReader) -> InputPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputPeerNotifySettings: TypeConstructorDescription {
        public class Cons_inputPeerNotifySettings {
            public var flags: Int32
            public var showPreviews: Api.Bool?
            public var silent: Api.Bool?
            public var muteUntil: Int32?
            public var sound: Api.NotificationSound?
            public var storiesMuted: Api.Bool?
            public var storiesHideSender: Api.Bool?
            public var storiesSound: Api.NotificationSound?
            public init(flags: Int32, showPreviews: Api.Bool?, silent: Api.Bool?, muteUntil: Int32?, sound: Api.NotificationSound?, storiesMuted: Api.Bool?, storiesHideSender: Api.Bool?, storiesSound: Api.NotificationSound?) {
                self.flags = flags
                self.showPreviews = showPreviews
                self.silent = silent
                self.muteUntil = muteUntil
                self.sound = sound
                self.storiesMuted = storiesMuted
                self.storiesHideSender = storiesHideSender
                self.storiesSound = storiesSound
            }
        }
        case inputPeerNotifySettings(Cons_inputPeerNotifySettings)

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

        public static func parse_inputPeerNotifySettings(_ reader: BufferReader) -> InputPeerNotifySettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputPhoneCall: TypeConstructorDescription {
        public class Cons_inputPhoneCall {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
        }
        case inputPhoneCall(Cons_inputPhoneCall)

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

        public static func parse_inputPhoneCall(_ reader: BufferReader) -> InputPhoneCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputPhoto: TypeConstructorDescription {
        public class Cons_inputPhoto {
            public var id: Int64
            public var accessHash: Int64
            public var fileReference: Buffer
            public init(id: Int64, accessHash: Int64, fileReference: Buffer) {
                self.id = id
                self.accessHash = accessHash
                self.fileReference = fileReference
            }
        }
        case inputPhoto(Cons_inputPhoto)
        case inputPhotoEmpty

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

        public static func parse_inputPhoto(_ reader: BufferReader) -> InputPhoto? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPhotoEmpty(_ reader: BufferReader) -> InputPhoto? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputPrivacyKey: TypeConstructorDescription {
        case inputPrivacyKeyAbout
        case inputPrivacyKeyAddedByPhone
        case inputPrivacyKeyBirthday
        case inputPrivacyKeyChatInvite
        case inputPrivacyKeyForwards
        case inputPrivacyKeyNoPaidMessages
        case inputPrivacyKeyPhoneCall
        case inputPrivacyKeyPhoneNumber
        case inputPrivacyKeyPhoneP2P
        case inputPrivacyKeyProfilePhoto
        case inputPrivacyKeySavedMusic
        case inputPrivacyKeyStarGiftsAutoSave
        case inputPrivacyKeyStatusTimestamp
        case inputPrivacyKeyVoiceMessages

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

        public static func parse_inputPrivacyKeyAbout(_ reader: BufferReader) -> InputPrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyKeyAddedByPhone(_ reader: BufferReader) -> InputPrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyKeyBirthday(_ reader: BufferReader) -> InputPrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyKeyChatInvite(_ reader: BufferReader) -> InputPrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyKeyForwards(_ reader: BufferReader) -> InputPrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyKeyNoPaidMessages(_ reader: BufferReader) -> InputPrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyKeyPhoneCall(_ reader: BufferReader) -> InputPrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyKeyPhoneNumber(_ reader: BufferReader) -> InputPrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyKeyPhoneP2P(_ reader: BufferReader) -> InputPrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyKeyProfilePhoto(_ reader: BufferReader) -> InputPrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyKeySavedMusic(_ reader: BufferReader) -> InputPrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyKeyStarGiftsAutoSave(_ reader: BufferReader) -> InputPrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyKeyStatusTimestamp(_ reader: BufferReader) -> InputPrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyKeyVoiceMessages(_ reader: BufferReader) -> InputPrivacyKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputPrivacyRule: TypeConstructorDescription {
        public class Cons_inputPrivacyValueAllowChatParticipants {
            public var chats: [Int64]
            public init(chats: [Int64]) {
                self.chats = chats
            }
        }
        public class Cons_inputPrivacyValueAllowUsers {
            public var users: [Api.InputUser]
            public init(users: [Api.InputUser]) {
                self.users = users
            }
        }
        public class Cons_inputPrivacyValueDisallowChatParticipants {
            public var chats: [Int64]
            public init(chats: [Int64]) {
                self.chats = chats
            }
        }
        public class Cons_inputPrivacyValueDisallowUsers {
            public var users: [Api.InputUser]
            public init(users: [Api.InputUser]) {
                self.users = users
            }
        }
        case inputPrivacyValueAllowAll
        case inputPrivacyValueAllowBots
        case inputPrivacyValueAllowChatParticipants(Cons_inputPrivacyValueAllowChatParticipants)
        case inputPrivacyValueAllowCloseFriends
        case inputPrivacyValueAllowContacts
        case inputPrivacyValueAllowPremium
        case inputPrivacyValueAllowUsers(Cons_inputPrivacyValueAllowUsers)
        case inputPrivacyValueDisallowAll
        case inputPrivacyValueDisallowBots
        case inputPrivacyValueDisallowChatParticipants(Cons_inputPrivacyValueDisallowChatParticipants)
        case inputPrivacyValueDisallowContacts
        case inputPrivacyValueDisallowUsers(Cons_inputPrivacyValueDisallowUsers)

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

        public static func parse_inputPrivacyValueAllowAll(_ reader: BufferReader) -> InputPrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyValueAllowBots(_ reader: BufferReader) -> InputPrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyValueAllowChatParticipants(_ reader: BufferReader) -> InputPrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyValueAllowCloseFriends(_ reader: BufferReader) -> InputPrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyValueAllowContacts(_ reader: BufferReader) -> InputPrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyValueAllowPremium(_ reader: BufferReader) -> InputPrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyValueAllowUsers(_ reader: BufferReader) -> InputPrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyValueDisallowAll(_ reader: BufferReader) -> InputPrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyValueDisallowBots(_ reader: BufferReader) -> InputPrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyValueDisallowChatParticipants(_ reader: BufferReader) -> InputPrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyValueDisallowContacts(_ reader: BufferReader) -> InputPrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPrivacyValueDisallowUsers(_ reader: BufferReader) -> InputPrivacyRule? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
