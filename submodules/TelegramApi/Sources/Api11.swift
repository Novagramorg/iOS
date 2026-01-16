public extension Api {
    indirect enum InputMedia: TypeConstructorDescription {
        public class Cons_inputMediaContact {
            public var phoneNumber: String
            public var firstName: String
            public var lastName: String
            public var vcard: String
            public init(phoneNumber: String, firstName: String, lastName: String, vcard: String) {
                self.phoneNumber = phoneNumber
                self.firstName = firstName
                self.lastName = lastName
                self.vcard = vcard
            }
        }
        public class Cons_inputMediaDice {
            public var emoticon: String
            public init(emoticon: String) {
                self.emoticon = emoticon
            }
        }
        public class Cons_inputMediaDocument {
            public var flags: Int32
            public var id: Api.InputDocument
            public var videoCover: Api.InputPhoto?
            public var videoTimestamp: Int32?
            public var ttlSeconds: Int32?
            public var query: String?
            public init(flags: Int32, id: Api.InputDocument, videoCover: Api.InputPhoto?, videoTimestamp: Int32?, ttlSeconds: Int32?, query: String?) {
                self.flags = flags
                self.id = id
                self.videoCover = videoCover
                self.videoTimestamp = videoTimestamp
                self.ttlSeconds = ttlSeconds
                self.query = query
            }
        }
        public class Cons_inputMediaDocumentExternal {
            public var flags: Int32
            public var url: String
            public var ttlSeconds: Int32?
            public var videoCover: Api.InputPhoto?
            public var videoTimestamp: Int32?
            public init(flags: Int32, url: String, ttlSeconds: Int32?, videoCover: Api.InputPhoto?, videoTimestamp: Int32?) {
                self.flags = flags
                self.url = url
                self.ttlSeconds = ttlSeconds
                self.videoCover = videoCover
                self.videoTimestamp = videoTimestamp
            }
        }
        public class Cons_inputMediaGame {
            public var id: Api.InputGame
            public init(id: Api.InputGame) {
                self.id = id
            }
        }
        public class Cons_inputMediaGeoLive {
            public var flags: Int32
            public var geoPoint: Api.InputGeoPoint
            public var heading: Int32?
            public var period: Int32?
            public var proximityNotificationRadius: Int32?
            public init(flags: Int32, geoPoint: Api.InputGeoPoint, heading: Int32?, period: Int32?, proximityNotificationRadius: Int32?) {
                self.flags = flags
                self.geoPoint = geoPoint
                self.heading = heading
                self.period = period
                self.proximityNotificationRadius = proximityNotificationRadius
            }
        }
        public class Cons_inputMediaGeoPoint {
            public var geoPoint: Api.InputGeoPoint
            public init(geoPoint: Api.InputGeoPoint) {
                self.geoPoint = geoPoint
            }
        }
        public class Cons_inputMediaInvoice {
            public var flags: Int32
            public var title: String
            public var description: String
            public var photo: Api.InputWebDocument?
            public var invoice: Api.Invoice
            public var payload: Buffer
            public var provider: String?
            public var providerData: Api.DataJSON
            public var startParam: String?
            public var extendedMedia: Api.InputMedia?
            public init(flags: Int32, title: String, description: String, photo: Api.InputWebDocument?, invoice: Api.Invoice, payload: Buffer, provider: String?, providerData: Api.DataJSON, startParam: String?, extendedMedia: Api.InputMedia?) {
                self.flags = flags
                self.title = title
                self.description = description
                self.photo = photo
                self.invoice = invoice
                self.payload = payload
                self.provider = provider
                self.providerData = providerData
                self.startParam = startParam
                self.extendedMedia = extendedMedia
            }
        }
        public class Cons_inputMediaPaidMedia {
            public var flags: Int32
            public var starsAmount: Int64
            public var extendedMedia: [Api.InputMedia]
            public var payload: String?
            public init(flags: Int32, starsAmount: Int64, extendedMedia: [Api.InputMedia], payload: String?) {
                self.flags = flags
                self.starsAmount = starsAmount
                self.extendedMedia = extendedMedia
                self.payload = payload
            }
        }
        public class Cons_inputMediaPhoto {
            public var flags: Int32
            public var id: Api.InputPhoto
            public var ttlSeconds: Int32?
            public init(flags: Int32, id: Api.InputPhoto, ttlSeconds: Int32?) {
                self.flags = flags
                self.id = id
                self.ttlSeconds = ttlSeconds
            }
        }
        public class Cons_inputMediaPhotoExternal {
            public var flags: Int32
            public var url: String
            public var ttlSeconds: Int32?
            public init(flags: Int32, url: String, ttlSeconds: Int32?) {
                self.flags = flags
                self.url = url
                self.ttlSeconds = ttlSeconds
            }
        }
        public class Cons_inputMediaPoll {
            public var flags: Int32
            public var poll: Api.Poll
            public var correctAnswers: [Buffer]?
            public var solution: String?
            public var solutionEntities: [Api.MessageEntity]?
            public init(flags: Int32, poll: Api.Poll, correctAnswers: [Buffer]?, solution: String?, solutionEntities: [Api.MessageEntity]?) {
                self.flags = flags
                self.poll = poll
                self.correctAnswers = correctAnswers
                self.solution = solution
                self.solutionEntities = solutionEntities
            }
        }
        public class Cons_inputMediaStakeDice {
            public var gameHash: String
            public var tonAmount: Int64
            public var clientSeed: Buffer
            public init(gameHash: String, tonAmount: Int64, clientSeed: Buffer) {
                self.gameHash = gameHash
                self.tonAmount = tonAmount
                self.clientSeed = clientSeed
            }
        }
        public class Cons_inputMediaStory {
            public var peer: Api.InputPeer
            public var id: Int32
            public init(peer: Api.InputPeer, id: Int32) {
                self.peer = peer
                self.id = id
            }
        }
        public class Cons_inputMediaTodo {
            public var todo: Api.TodoList
            public init(todo: Api.TodoList) {
                self.todo = todo
            }
        }
        public class Cons_inputMediaUploadedDocument {
            public var flags: Int32
            public var file: Api.InputFile
            public var thumb: Api.InputFile?
            public var mimeType: String
            public var attributes: [Api.DocumentAttribute]
            public var stickers: [Api.InputDocument]?
            public var videoCover: Api.InputPhoto?
            public var videoTimestamp: Int32?
            public var ttlSeconds: Int32?
            public init(flags: Int32, file: Api.InputFile, thumb: Api.InputFile?, mimeType: String, attributes: [Api.DocumentAttribute], stickers: [Api.InputDocument]?, videoCover: Api.InputPhoto?, videoTimestamp: Int32?, ttlSeconds: Int32?) {
                self.flags = flags
                self.file = file
                self.thumb = thumb
                self.mimeType = mimeType
                self.attributes = attributes
                self.stickers = stickers
                self.videoCover = videoCover
                self.videoTimestamp = videoTimestamp
                self.ttlSeconds = ttlSeconds
            }
        }
        public class Cons_inputMediaUploadedPhoto {
            public var flags: Int32
            public var file: Api.InputFile
            public var stickers: [Api.InputDocument]?
            public var ttlSeconds: Int32?
            public init(flags: Int32, file: Api.InputFile, stickers: [Api.InputDocument]?, ttlSeconds: Int32?) {
                self.flags = flags
                self.file = file
                self.stickers = stickers
                self.ttlSeconds = ttlSeconds
            }
        }
        public class Cons_inputMediaVenue {
            public var geoPoint: Api.InputGeoPoint
            public var title: String
            public var address: String
            public var provider: String
            public var venueId: String
            public var venueType: String
            public init(geoPoint: Api.InputGeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String) {
                self.geoPoint = geoPoint
                self.title = title
                self.address = address
                self.provider = provider
                self.venueId = venueId
                self.venueType = venueType
            }
        }
        public class Cons_inputMediaWebPage {
            public var flags: Int32
            public var url: String
            public init(flags: Int32, url: String) {
                self.flags = flags
                self.url = url
            }
        }
        case inputMediaContact(Cons_inputMediaContact)
        case inputMediaDice(Cons_inputMediaDice)
        case inputMediaDocument(Cons_inputMediaDocument)
        case inputMediaDocumentExternal(Cons_inputMediaDocumentExternal)
        case inputMediaEmpty
        case inputMediaGame(Cons_inputMediaGame)
        case inputMediaGeoLive(Cons_inputMediaGeoLive)
        case inputMediaGeoPoint(Cons_inputMediaGeoPoint)
        case inputMediaInvoice(Cons_inputMediaInvoice)
        case inputMediaPaidMedia(Cons_inputMediaPaidMedia)
        case inputMediaPhoto(Cons_inputMediaPhoto)
        case inputMediaPhotoExternal(Cons_inputMediaPhotoExternal)
        case inputMediaPoll(Cons_inputMediaPoll)
        case inputMediaStakeDice(Cons_inputMediaStakeDice)
        case inputMediaStory(Cons_inputMediaStory)
        case inputMediaTodo(Cons_inputMediaTodo)
        case inputMediaUploadedDocument(Cons_inputMediaUploadedDocument)
        case inputMediaUploadedPhoto(Cons_inputMediaUploadedPhoto)
        case inputMediaVenue(Cons_inputMediaVenue)
        case inputMediaWebPage(Cons_inputMediaWebPage)

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
        public class Cons_inputMessageCallbackQuery {
            public var id: Int32
            public var queryId: Int64
            public init(id: Int32, queryId: Int64) {
                self.id = id
                self.queryId = queryId
            }
        }
        public class Cons_inputMessageID {
            public var id: Int32
            public init(id: Int32) {
                self.id = id
            }
        }
        public class Cons_inputMessageReplyTo {
            public var id: Int32
            public init(id: Int32) {
                self.id = id
            }
        }
        case inputMessageCallbackQuery(Cons_inputMessageCallbackQuery)
        case inputMessageID(Cons_inputMessageID)
        case inputMessagePinned
        case inputMessageReplyTo(Cons_inputMessageReplyTo)

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
        public class Cons_inputNotifyForumTopic {
            public var peer: Api.InputPeer
            public var topMsgId: Int32
            public init(peer: Api.InputPeer, topMsgId: Int32) {
                self.peer = peer
                self.topMsgId = topMsgId
            }
        }
        public class Cons_inputNotifyPeer {
            public var peer: Api.InputPeer
            public init(peer: Api.InputPeer) {
                self.peer = peer
            }
        }
        case inputNotifyBroadcasts
        case inputNotifyChats
        case inputNotifyForumTopic(Cons_inputNotifyForumTopic)
        case inputNotifyPeer(Cons_inputNotifyPeer)
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
        public class Cons_inputPasskeyCredentialFirebasePNV {
            public var pnvToken: String
            public init(pnvToken: String) {
                self.pnvToken = pnvToken
            }
        }
        public class Cons_inputPasskeyCredentialPublicKey {
            public var id: String
            public var rawId: String
            public var response: Api.InputPasskeyResponse
            public init(id: String, rawId: String, response: Api.InputPasskeyResponse) {
                self.id = id
                self.rawId = rawId
                self.response = response
            }
        }
        case inputPasskeyCredentialFirebasePNV(Cons_inputPasskeyCredentialFirebasePNV)
        case inputPasskeyCredentialPublicKey(Cons_inputPasskeyCredentialPublicKey)

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
        public class Cons_inputPasskeyResponseLogin {
            public var clientData: Api.DataJSON
            public var authenticatorData: Buffer
            public var signature: Buffer
            public var userHandle: String
            public init(clientData: Api.DataJSON, authenticatorData: Buffer, signature: Buffer, userHandle: String) {
                self.clientData = clientData
                self.authenticatorData = authenticatorData
                self.signature = signature
                self.userHandle = userHandle
            }
        }
        public class Cons_inputPasskeyResponseRegister {
            public var clientData: Api.DataJSON
            public var attestationData: Buffer
            public init(clientData: Api.DataJSON, attestationData: Buffer) {
                self.clientData = clientData
                self.attestationData = attestationData
            }
        }
        case inputPasskeyResponseLogin(Cons_inputPasskeyResponseLogin)
        case inputPasskeyResponseRegister(Cons_inputPasskeyResponseRegister)

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
