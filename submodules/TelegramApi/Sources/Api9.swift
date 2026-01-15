public extension Api {
    enum InputBusinessBotRecipients: TypeConstructorDescription {
        public class Cons_inputBusinessBotRecipients {
            public var flags: Int32
            public var users: [Api.InputUser]?
            public var excludeUsers: [Api.InputUser]?
            public init(flags: Int32, users: [Api.InputUser]?, excludeUsers: [Api.InputUser]?) {
                self.flags = flags
                self.users = users
                self.excludeUsers = excludeUsers
            }
        }
        case inputBusinessBotRecipients(Cons_inputBusinessBotRecipients)

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

        public static func parse_inputBusinessBotRecipients(_ reader: BufferReader) -> InputBusinessBotRecipients? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputBusinessChatLink: TypeConstructorDescription {
        public class Cons_inputBusinessChatLink {
            public var flags: Int32
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var title: String?
            public init(flags: Int32, message: String, entities: [Api.MessageEntity]?, title: String?) {
                self.flags = flags
                self.message = message
                self.entities = entities
                self.title = title
            }
        }
        case inputBusinessChatLink(Cons_inputBusinessChatLink)

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

        public static func parse_inputBusinessChatLink(_ reader: BufferReader) -> InputBusinessChatLink? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputBusinessGreetingMessage: TypeConstructorDescription {
        public class Cons_inputBusinessGreetingMessage {
            public var shortcutId: Int32
            public var recipients: Api.InputBusinessRecipients
            public var noActivityDays: Int32
            public init(shortcutId: Int32, recipients: Api.InputBusinessRecipients, noActivityDays: Int32) {
                self.shortcutId = shortcutId
                self.recipients = recipients
                self.noActivityDays = noActivityDays
            }
        }
        case inputBusinessGreetingMessage(Cons_inputBusinessGreetingMessage)

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

        public static func parse_inputBusinessGreetingMessage(_ reader: BufferReader) -> InputBusinessGreetingMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputBusinessIntro: TypeConstructorDescription {
        public class Cons_inputBusinessIntro {
            public var flags: Int32
            public var title: String
            public var description: String
            public var sticker: Api.InputDocument?
            public init(flags: Int32, title: String, description: String, sticker: Api.InputDocument?) {
                self.flags = flags
                self.title = title
                self.description = description
                self.sticker = sticker
            }
        }
        case inputBusinessIntro(Cons_inputBusinessIntro)

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

        public static func parse_inputBusinessIntro(_ reader: BufferReader) -> InputBusinessIntro? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputBusinessRecipients: TypeConstructorDescription {
        public class Cons_inputBusinessRecipients {
            public var flags: Int32
            public var users: [Api.InputUser]?
            public init(flags: Int32, users: [Api.InputUser]?) {
                self.flags = flags
                self.users = users
            }
        }
        case inputBusinessRecipients(Cons_inputBusinessRecipients)

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

        public static func parse_inputBusinessRecipients(_ reader: BufferReader) -> InputBusinessRecipients? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum InputChannel: TypeConstructorDescription {
        public class Cons_inputChannel {
            public var channelId: Int64
            public var accessHash: Int64
            public init(channelId: Int64, accessHash: Int64) {
                self.channelId = channelId
                self.accessHash = accessHash
            }
        }
        public class Cons_inputChannelFromMessage {
            public var peer: Api.InputPeer
            public var msgId: Int32
            public var channelId: Int64
            public init(peer: Api.InputPeer, msgId: Int32, channelId: Int64) {
                self.peer = peer
                self.msgId = msgId
                self.channelId = channelId
            }
        }
        case inputChannel(Cons_inputChannel)
        case inputChannelEmpty
        case inputChannelFromMessage(Cons_inputChannelFromMessage)

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

        public static func parse_inputChannel(_ reader: BufferReader) -> InputChannel? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputChannelEmpty(_ reader: BufferReader) -> InputChannel? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputChannelFromMessage(_ reader: BufferReader) -> InputChannel? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputChatPhoto: TypeConstructorDescription {
        public class Cons_inputChatPhoto {
            public var id: Api.InputPhoto
            public init(id: Api.InputPhoto) {
                self.id = id
            }
        }
        public class Cons_inputChatUploadedPhoto {
            public var flags: Int32
            public var file: Api.InputFile?
            public var video: Api.InputFile?
            public var videoStartTs: Double?
            public var videoEmojiMarkup: Api.VideoSize?
            public init(flags: Int32, file: Api.InputFile?, video: Api.InputFile?, videoStartTs: Double?, videoEmojiMarkup: Api.VideoSize?) {
                self.flags = flags
                self.file = file
                self.video = video
                self.videoStartTs = videoStartTs
                self.videoEmojiMarkup = videoEmojiMarkup
            }
        }
        case inputChatPhoto(Cons_inputChatPhoto)
        case inputChatPhotoEmpty
        case inputChatUploadedPhoto(Cons_inputChatUploadedPhoto)

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

        public static func parse_inputChatPhoto(_ reader: BufferReader) -> InputChatPhoto? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputChatPhotoEmpty(_ reader: BufferReader) -> InputChatPhoto? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputChatUploadedPhoto(_ reader: BufferReader) -> InputChatPhoto? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputChatTheme: TypeConstructorDescription {
        public class Cons_inputChatTheme {
            public var emoticon: String
            public init(emoticon: String) {
                self.emoticon = emoticon
            }
        }
        public class Cons_inputChatThemeUniqueGift {
            public var slug: String
            public init(slug: String) {
                self.slug = slug
            }
        }
        case inputChatTheme(Cons_inputChatTheme)
        case inputChatThemeEmpty
        case inputChatThemeUniqueGift(Cons_inputChatThemeUniqueGift)

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

        public static func parse_inputChatTheme(_ reader: BufferReader) -> InputChatTheme? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputChatThemeEmpty(_ reader: BufferReader) -> InputChatTheme? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputChatThemeUniqueGift(_ reader: BufferReader) -> InputChatTheme? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputChatlist: TypeConstructorDescription {
        public class Cons_inputChatlistDialogFilter {
            public var filterId: Int32
            public init(filterId: Int32) {
                self.filterId = filterId
            }
        }
        case inputChatlistDialogFilter(Cons_inputChatlistDialogFilter)

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

        public static func parse_inputChatlistDialogFilter(_ reader: BufferReader) -> InputChatlist? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputCheckPasswordSRP: TypeConstructorDescription {
        public class Cons_inputCheckPasswordSRP {
            public var srpId: Int64
            public var A: Buffer
            public var M1: Buffer
            public init(srpId: Int64, A: Buffer, M1: Buffer) {
                self.srpId = srpId
                self.A = A
                self.M1 = M1
            }
        }
        case inputCheckPasswordEmpty
        case inputCheckPasswordSRP(Cons_inputCheckPasswordSRP)

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

        public static func parse_inputCheckPasswordEmpty(_ reader: BufferReader) -> InputCheckPasswordSRP? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputCheckPasswordSRP(_ reader: BufferReader) -> InputCheckPasswordSRP? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputClientProxy: TypeConstructorDescription {
        public class Cons_inputClientProxy {
            public var address: String
            public var port: Int32
            public init(address: String, port: Int32) {
                self.address = address
                self.port = port
            }
        }
        case inputClientProxy(Cons_inputClientProxy)

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

        public static func parse_inputClientProxy(_ reader: BufferReader) -> InputClientProxy? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputCollectible: TypeConstructorDescription {
        public class Cons_inputCollectiblePhone {
            public var phone: String
            public init(phone: String) {
                self.phone = phone
            }
        }
        public class Cons_inputCollectibleUsername {
            public var username: String
            public init(username: String) {
                self.username = username
            }
        }
        case inputCollectiblePhone(Cons_inputCollectiblePhone)
        case inputCollectibleUsername(Cons_inputCollectibleUsername)

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

        public static func parse_inputCollectiblePhone(_ reader: BufferReader) -> InputCollectible? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputCollectibleUsername(_ reader: BufferReader) -> InputCollectible? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputContact: TypeConstructorDescription {
        public class Cons_inputPhoneContact {
            public var flags: Int32
            public var clientId: Int64
            public var phone: String
            public var firstName: String
            public var lastName: String
            public var note: Api.TextWithEntities?
            public init(flags: Int32, clientId: Int64, phone: String, firstName: String, lastName: String, note: Api.TextWithEntities?) {
                self.flags = flags
                self.clientId = clientId
                self.phone = phone
                self.firstName = firstName
                self.lastName = lastName
                self.note = note
            }
        }
        case inputPhoneContact(Cons_inputPhoneContact)

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

        public static func parse_inputPhoneContact(_ reader: BufferReader) -> InputContact? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum InputDialogPeer: TypeConstructorDescription {
        public class Cons_inputDialogPeer {
            public var peer: Api.InputPeer
            public init(peer: Api.InputPeer) {
                self.peer = peer
            }
        }
        public class Cons_inputDialogPeerFolder {
            public var folderId: Int32
            public init(folderId: Int32) {
                self.folderId = folderId
            }
        }
        case inputDialogPeer(Cons_inputDialogPeer)
        case inputDialogPeerFolder(Cons_inputDialogPeerFolder)

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

        public static func parse_inputDialogPeer(_ reader: BufferReader) -> InputDialogPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputDialogPeerFolder(_ reader: BufferReader) -> InputDialogPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputDocument: TypeConstructorDescription {
        public class Cons_inputDocument {
            public var id: Int64
            public var accessHash: Int64
            public var fileReference: Buffer
            public init(id: Int64, accessHash: Int64, fileReference: Buffer) {
                self.id = id
                self.accessHash = accessHash
                self.fileReference = fileReference
            }
        }
        case inputDocument(Cons_inputDocument)
        case inputDocumentEmpty

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

        public static func parse_inputDocument(_ reader: BufferReader) -> InputDocument? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputDocumentEmpty(_ reader: BufferReader) -> InputDocument? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputEncryptedChat: TypeConstructorDescription {
        public class Cons_inputEncryptedChat {
            public var chatId: Int32
            public var accessHash: Int64
            public init(chatId: Int32, accessHash: Int64) {
                self.chatId = chatId
                self.accessHash = accessHash
            }
        }
        case inputEncryptedChat(Cons_inputEncryptedChat)

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

        public static func parse_inputEncryptedChat(_ reader: BufferReader) -> InputEncryptedChat? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputEncryptedFile: TypeConstructorDescription {
        public class Cons_inputEncryptedFile {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
        }
        public class Cons_inputEncryptedFileBigUploaded {
            public var id: Int64
            public var parts: Int32
            public var keyFingerprint: Int32
            public init(id: Int64, parts: Int32, keyFingerprint: Int32) {
                self.id = id
                self.parts = parts
                self.keyFingerprint = keyFingerprint
            }
        }
        public class Cons_inputEncryptedFileUploaded {
            public var id: Int64
            public var parts: Int32
            public var md5Checksum: String
            public var keyFingerprint: Int32
            public init(id: Int64, parts: Int32, md5Checksum: String, keyFingerprint: Int32) {
                self.id = id
                self.parts = parts
                self.md5Checksum = md5Checksum
                self.keyFingerprint = keyFingerprint
            }
        }
        case inputEncryptedFile(Cons_inputEncryptedFile)
        case inputEncryptedFileBigUploaded(Cons_inputEncryptedFileBigUploaded)
        case inputEncryptedFileEmpty
        case inputEncryptedFileUploaded(Cons_inputEncryptedFileUploaded)

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

        public static func parse_inputEncryptedFile(_ reader: BufferReader) -> InputEncryptedFile? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputEncryptedFileBigUploaded(_ reader: BufferReader) -> InputEncryptedFile? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputEncryptedFileEmpty(_ reader: BufferReader) -> InputEncryptedFile? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputEncryptedFileUploaded(_ reader: BufferReader) -> InputEncryptedFile? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputFile: TypeConstructorDescription {
        public class Cons_inputFile {
            public var id: Int64
            public var parts: Int32
            public var name: String
            public var md5Checksum: String
            public init(id: Int64, parts: Int32, name: String, md5Checksum: String) {
                self.id = id
                self.parts = parts
                self.name = name
                self.md5Checksum = md5Checksum
            }
        }
        public class Cons_inputFileBig {
            public var id: Int64
            public var parts: Int32
            public var name: String
            public init(id: Int64, parts: Int32, name: String) {
                self.id = id
                self.parts = parts
                self.name = name
            }
        }
        public class Cons_inputFileStoryDocument {
            public var id: Api.InputDocument
            public init(id: Api.InputDocument) {
                self.id = id
            }
        }
        case inputFile(Cons_inputFile)
        case inputFileBig(Cons_inputFileBig)
        case inputFileStoryDocument(Cons_inputFileStoryDocument)

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

        public static func parse_inputFile(_ reader: BufferReader) -> InputFile? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputFileBig(_ reader: BufferReader) -> InputFile? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputFileStoryDocument(_ reader: BufferReader) -> InputFile? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
