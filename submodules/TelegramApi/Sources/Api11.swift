public extension Api {
    indirect enum InputMedia: TypeConstructorDescription {
        case inputMediaContact(phoneNumber: String, firstName: String, lastName: String, vcard: String)
        case inputMediaDice(emoticon: String)
        case inputMediaDocument(flags: Int32, id: Api.InputDocument, videoCover: Api.InputPhoto?, videoTimestamp: Int32?, ttlSeconds: Int32?, query: String?)
        case inputMediaDocumentExternal(flags: Int32, url: String, ttlSeconds: Int32?, videoCover: Api.InputPhoto?, videoTimestamp: Int32?)
        case inputMediaEmpty
        case inputMediaGame(id: Api.InputGame)
        case inputMediaGeoLive(flags: Int32, geoPoint: Api.InputGeoPoint, heading: Int32?, period: Int32?, proximityNotificationRadius: Int32?)
        case inputMediaGeoPoint(geoPoint: Api.InputGeoPoint)
        case inputMediaInvoice(flags: Int32, title: String, description: String, photo: Api.InputWebDocument?, invoice: Api.Invoice, payload: Buffer, provider: String?, providerData: Api.DataJSON, startParam: String?, extendedMedia: Api.InputMedia?)
        case inputMediaPaidMedia(flags: Int32, starsAmount: Int64, extendedMedia: [Api.InputMedia], payload: String?)
        case inputMediaPhoto(flags: Int32, id: Api.InputPhoto, ttlSeconds: Int32?)
        case inputMediaPhotoExternal(flags: Int32, url: String, ttlSeconds: Int32?)
        case inputMediaPoll(flags: Int32, poll: Api.Poll, correctAnswers: [Buffer]?, solution: String?, solutionEntities: [Api.MessageEntity]?)
        case inputMediaStakeDice(gameHash: String, tonAmount: Int64, clientSeed: Buffer)
        case inputMediaStory(peer: Api.InputPeer, id: Int32)
        case inputMediaTodo(todo: Api.TodoList)
        case inputMediaUploadedDocument(flags: Int32, file: Api.InputFile, thumb: Api.InputFile?, mimeType: String, attributes: [Api.DocumentAttribute], stickers: [Api.InputDocument]?, videoCover: Api.InputPhoto?, videoTimestamp: Int32?, ttlSeconds: Int32?)
        case inputMediaUploadedPhoto(flags: Int32, file: Api.InputFile, stickers: [Api.InputDocument]?, ttlSeconds: Int32?)
        case inputMediaVenue(geoPoint: Api.InputGeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String)
        case inputMediaWebPage(flags: Int32, url: String)

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

        public static func parse_inputMediaContact(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaDice(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaDocument(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaDocumentExternal(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaEmpty(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaGame(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaGeoLive(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaGeoPoint(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaInvoice(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaPaidMedia(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaPhoto(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaPhotoExternal(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaPoll(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaStakeDice(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaStory(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaTodo(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaUploadedDocument(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaUploadedPhoto(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaVenue(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMediaWebPage(_ reader: BufferReader) -> InputMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputMessage: TypeConstructorDescription {
        case inputMessageCallbackQuery(id: Int32, queryId: Int64)
        case inputMessageID(id: Int32)
        case inputMessagePinned
        case inputMessageReplyTo(id: Int32)

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

        public static func parse_inputMessageCallbackQuery(_ reader: BufferReader) -> InputMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessageID(_ reader: BufferReader) -> InputMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessagePinned(_ reader: BufferReader) -> InputMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputMessageReplyTo(_ reader: BufferReader) -> InputMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum InputNotifyPeer: TypeConstructorDescription {
        case inputNotifyBroadcasts
        case inputNotifyChats
        case inputNotifyForumTopic(peer: Api.InputPeer, topMsgId: Int32)
        case inputNotifyPeer(peer: Api.InputPeer)
        case inputNotifyUsers

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

        public static func parse_inputNotifyBroadcasts(_ reader: BufferReader) -> InputNotifyPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputNotifyChats(_ reader: BufferReader) -> InputNotifyPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputNotifyForumTopic(_ reader: BufferReader) -> InputNotifyPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputNotifyPeer(_ reader: BufferReader) -> InputNotifyPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputNotifyUsers(_ reader: BufferReader) -> InputNotifyPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputPasskeyCredential: TypeConstructorDescription {
        case inputPasskeyCredentialFirebasePNV(pnvToken: String)
        case inputPasskeyCredentialPublicKey(id: String, rawId: String, response: Api.InputPasskeyResponse)

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

        public static func parse_inputPasskeyCredentialFirebasePNV(_ reader: BufferReader) -> InputPasskeyCredential? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPasskeyCredentialPublicKey(_ reader: BufferReader) -> InputPasskeyCredential? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputPasskeyResponse: TypeConstructorDescription {
        case inputPasskeyResponseLogin(clientData: Api.DataJSON, authenticatorData: Buffer, signature: Buffer, userHandle: String)
        case inputPasskeyResponseRegister(clientData: Api.DataJSON, attestationData: Buffer)

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

        public static func parse_inputPasskeyResponseLogin(_ reader: BufferReader) -> InputPasskeyResponse? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPasskeyResponseRegister(_ reader: BufferReader) -> InputPasskeyResponse? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
