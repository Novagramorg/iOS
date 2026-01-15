public extension Api {
    enum InputPaymentCredentials: TypeConstructorDescription {
        case inputPaymentCredentials(flags: Int32, data: Api.DataJSON)
        case inputPaymentCredentialsApplePay(paymentData: Api.DataJSON)
        case inputPaymentCredentialsGooglePay(paymentToken: Api.DataJSON)
        case inputPaymentCredentialsSaved(id: String, tmpPassword: Buffer)

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
        case inputPeerChannel(channelId: Int64, accessHash: Int64)
        case inputPeerChannelFromMessage(peer: Api.InputPeer, msgId: Int32, channelId: Int64)
        case inputPeerChat(chatId: Int64)
        case inputPeerEmpty
        case inputPeerSelf
        case inputPeerUser(userId: Int64, accessHash: Int64)
        case inputPeerUserFromMessage(peer: Api.InputPeer, msgId: Int32, userId: Int64)

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
        case inputPeerNotifySettings(flags: Int32, showPreviews: Api.Bool?, silent: Api.Bool?, muteUntil: Int32?, sound: Api.NotificationSound?, storiesMuted: Api.Bool?, storiesHideSender: Api.Bool?, storiesSound: Api.NotificationSound?)

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
        case inputPhoneCall(id: Int64, accessHash: Int64)

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
        case inputPhoto(id: Int64, accessHash: Int64, fileReference: Buffer)
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
        case inputPrivacyValueAllowAll
        case inputPrivacyValueAllowBots
        case inputPrivacyValueAllowChatParticipants(chats: [Int64])
        case inputPrivacyValueAllowCloseFriends
        case inputPrivacyValueAllowContacts
        case inputPrivacyValueAllowPremium
        case inputPrivacyValueAllowUsers(users: [Api.InputUser])
        case inputPrivacyValueDisallowAll
        case inputPrivacyValueDisallowBots
        case inputPrivacyValueDisallowChatParticipants(chats: [Int64])
        case inputPrivacyValueDisallowContacts
        case inputPrivacyValueDisallowUsers(users: [Api.InputUser])

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
