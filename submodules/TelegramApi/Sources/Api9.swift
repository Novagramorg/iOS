public extension Api {
    enum InputBusinessBotRecipients: TypeConstructorDescription {
        case inputBusinessBotRecipients(flags: Int32, users: [Api.InputUser]?, excludeUsers: [Api.InputUser]?)

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
        case inputBusinessChatLink(flags: Int32, message: String, entities: [Api.MessageEntity]?, title: String?)

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
        case inputBusinessGreetingMessage(shortcutId: Int32, recipients: Api.InputBusinessRecipients, noActivityDays: Int32)

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
        case inputBusinessIntro(flags: Int32, title: String, description: String, sticker: Api.InputDocument?)

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
        case inputBusinessRecipients(flags: Int32, users: [Api.InputUser]?)

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
        case inputChannel(channelId: Int64, accessHash: Int64)
        case inputChannelEmpty
        case inputChannelFromMessage(peer: Api.InputPeer, msgId: Int32, channelId: Int64)

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
        case inputChatPhoto(id: Api.InputPhoto)
        case inputChatPhotoEmpty
        case inputChatUploadedPhoto(flags: Int32, file: Api.InputFile?, video: Api.InputFile?, videoStartTs: Double?, videoEmojiMarkup: Api.VideoSize?)

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
        case inputChatTheme(emoticon: String)
        case inputChatThemeEmpty
        case inputChatThemeUniqueGift(slug: String)

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
        case inputChatlistDialogFilter(filterId: Int32)

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
        case inputCheckPasswordEmpty
        case inputCheckPasswordSRP(srpId: Int64, A: Buffer, M1: Buffer)

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
        case inputClientProxy(address: String, port: Int32)

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
        case inputCollectiblePhone(phone: String)
        case inputCollectibleUsername(username: String)

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
        case inputPhoneContact(flags: Int32, clientId: Int64, phone: String, firstName: String, lastName: String, note: Api.TextWithEntities?)

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
        case inputDialogPeer(peer: Api.InputPeer)
        case inputDialogPeerFolder(folderId: Int32)

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
        case inputDocument(id: Int64, accessHash: Int64, fileReference: Buffer)
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
        case inputEncryptedChat(chatId: Int32, accessHash: Int64)

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
        case inputEncryptedFile(id: Int64, accessHash: Int64)
        case inputEncryptedFileBigUploaded(id: Int64, parts: Int32, keyFingerprint: Int32)
        case inputEncryptedFileEmpty
        case inputEncryptedFileUploaded(id: Int64, parts: Int32, md5Checksum: String, keyFingerprint: Int32)

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
        case inputFile(id: Int64, parts: Int32, name: String, md5Checksum: String)
        case inputFileBig(id: Int64, parts: Int32, name: String)
        case inputFileStoryDocument(id: Api.InputDocument)

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
