public extension Api {
    enum SecurePlainData: TypeConstructorDescription {
        public class Cons_securePlainEmail {
            public var email: String
            public init(email: String) {
                self.email = email
            }
        }
        public class Cons_securePlainPhone {
            public var phone: String
            public init(phone: String) {
                self.phone = phone
            }
        }
        case securePlainEmail(Cons_securePlainEmail)
        case securePlainPhone(Cons_securePlainPhone)

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

        public static func parse_securePlainEmail(_ reader: BufferReader) -> SecurePlainData? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_securePlainPhone(_ reader: BufferReader) -> SecurePlainData? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SecureRequiredType: TypeConstructorDescription {
        public class Cons_secureRequiredType {
            public var flags: Int32
            public var type: Api.SecureValueType
            public init(flags: Int32, type: Api.SecureValueType) {
                self.flags = flags
                self.type = type
            }
        }
        public class Cons_secureRequiredTypeOneOf {
            public var types: [Api.SecureRequiredType]
            public init(types: [Api.SecureRequiredType]) {
                self.types = types
            }
        }
        case secureRequiredType(Cons_secureRequiredType)
        case secureRequiredTypeOneOf(Cons_secureRequiredTypeOneOf)

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

        public static func parse_secureRequiredType(_ reader: BufferReader) -> SecureRequiredType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureRequiredTypeOneOf(_ reader: BufferReader) -> SecureRequiredType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SecureSecretSettings: TypeConstructorDescription {
        public class Cons_secureSecretSettings {
            public var secureAlgo: Api.SecurePasswordKdfAlgo
            public var secureSecret: Buffer
            public var secureSecretId: Int64
            public init(secureAlgo: Api.SecurePasswordKdfAlgo, secureSecret: Buffer, secureSecretId: Int64) {
                self.secureAlgo = secureAlgo
                self.secureSecret = secureSecret
                self.secureSecretId = secureSecretId
            }
        }
        case secureSecretSettings(Cons_secureSecretSettings)

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

        public static func parse_secureSecretSettings(_ reader: BufferReader) -> SecureSecretSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SecureValue: TypeConstructorDescription {
        public class Cons_secureValue {
            public var flags: Int32
            public var type: Api.SecureValueType
            public var data: Api.SecureData?
            public var frontSide: Api.SecureFile?
            public var reverseSide: Api.SecureFile?
            public var selfie: Api.SecureFile?
            public var translation: [Api.SecureFile]?
            public var files: [Api.SecureFile]?
            public var plainData: Api.SecurePlainData?
            public var hash: Buffer
            public init(flags: Int32, type: Api.SecureValueType, data: Api.SecureData?, frontSide: Api.SecureFile?, reverseSide: Api.SecureFile?, selfie: Api.SecureFile?, translation: [Api.SecureFile]?, files: [Api.SecureFile]?, plainData: Api.SecurePlainData?, hash: Buffer) {
                self.flags = flags
                self.type = type
                self.data = data
                self.frontSide = frontSide
                self.reverseSide = reverseSide
                self.selfie = selfie
                self.translation = translation
                self.files = files
                self.plainData = plainData
                self.hash = hash
            }
        }
        case secureValue(Cons_secureValue)

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

        public static func parse_secureValue(_ reader: BufferReader) -> SecureValue? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SecureValueError: TypeConstructorDescription {
        public class Cons_secureValueError {
            public var type: Api.SecureValueType
            public var hash: Buffer
            public var text: String
            public init(type: Api.SecureValueType, hash: Buffer, text: String) {
                self.type = type
                self.hash = hash
                self.text = text
            }
        }
        public class Cons_secureValueErrorData {
            public var type: Api.SecureValueType
            public var dataHash: Buffer
            public var field: String
            public var text: String
            public init(type: Api.SecureValueType, dataHash: Buffer, field: String, text: String) {
                self.type = type
                self.dataHash = dataHash
                self.field = field
                self.text = text
            }
        }
        public class Cons_secureValueErrorFile {
            public var type: Api.SecureValueType
            public var fileHash: Buffer
            public var text: String
            public init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
        }
        public class Cons_secureValueErrorFiles {
            public var type: Api.SecureValueType
            public var fileHash: [Buffer]
            public var text: String
            public init(type: Api.SecureValueType, fileHash: [Buffer], text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
        }
        public class Cons_secureValueErrorFrontSide {
            public var type: Api.SecureValueType
            public var fileHash: Buffer
            public var text: String
            public init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
        }
        public class Cons_secureValueErrorReverseSide {
            public var type: Api.SecureValueType
            public var fileHash: Buffer
            public var text: String
            public init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
        }
        public class Cons_secureValueErrorSelfie {
            public var type: Api.SecureValueType
            public var fileHash: Buffer
            public var text: String
            public init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
        }
        public class Cons_secureValueErrorTranslationFile {
            public var type: Api.SecureValueType
            public var fileHash: Buffer
            public var text: String
            public init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
        }
        public class Cons_secureValueErrorTranslationFiles {
            public var type: Api.SecureValueType
            public var fileHash: [Buffer]
            public var text: String
            public init(type: Api.SecureValueType, fileHash: [Buffer], text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
        }
        case secureValueError(Cons_secureValueError)
        case secureValueErrorData(Cons_secureValueErrorData)
        case secureValueErrorFile(Cons_secureValueErrorFile)
        case secureValueErrorFiles(Cons_secureValueErrorFiles)
        case secureValueErrorFrontSide(Cons_secureValueErrorFrontSide)
        case secureValueErrorReverseSide(Cons_secureValueErrorReverseSide)
        case secureValueErrorSelfie(Cons_secureValueErrorSelfie)
        case secureValueErrorTranslationFile(Cons_secureValueErrorTranslationFile)
        case secureValueErrorTranslationFiles(Cons_secureValueErrorTranslationFiles)

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

        public static func parse_secureValueError(_ reader: BufferReader) -> SecureValueError? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueErrorData(_ reader: BufferReader) -> SecureValueError? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueErrorFile(_ reader: BufferReader) -> SecureValueError? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueErrorFiles(_ reader: BufferReader) -> SecureValueError? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueErrorFrontSide(_ reader: BufferReader) -> SecureValueError? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueErrorReverseSide(_ reader: BufferReader) -> SecureValueError? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueErrorSelfie(_ reader: BufferReader) -> SecureValueError? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueErrorTranslationFile(_ reader: BufferReader) -> SecureValueError? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueErrorTranslationFiles(_ reader: BufferReader) -> SecureValueError? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SecureValueHash: TypeConstructorDescription {
        public class Cons_secureValueHash {
            public var type: Api.SecureValueType
            public var hash: Buffer
            public init(type: Api.SecureValueType, hash: Buffer) {
                self.type = type
                self.hash = hash
            }
        }
        case secureValueHash(Cons_secureValueHash)

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

        public static func parse_secureValueHash(_ reader: BufferReader) -> SecureValueHash? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SecureValueType: TypeConstructorDescription {
        case secureValueTypeAddress
        case secureValueTypeBankStatement
        case secureValueTypeDriverLicense
        case secureValueTypeEmail
        case secureValueTypeIdentityCard
        case secureValueTypeInternalPassport
        case secureValueTypePassport
        case secureValueTypePassportRegistration
        case secureValueTypePersonalDetails
        case secureValueTypePhone
        case secureValueTypeRentalAgreement
        case secureValueTypeTemporaryRegistration
        case secureValueTypeUtilityBill

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

        public static func parse_secureValueTypeAddress(_ reader: BufferReader) -> SecureValueType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueTypeBankStatement(_ reader: BufferReader) -> SecureValueType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueTypeDriverLicense(_ reader: BufferReader) -> SecureValueType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueTypeEmail(_ reader: BufferReader) -> SecureValueType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueTypeIdentityCard(_ reader: BufferReader) -> SecureValueType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueTypeInternalPassport(_ reader: BufferReader) -> SecureValueType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueTypePassport(_ reader: BufferReader) -> SecureValueType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueTypePassportRegistration(_ reader: BufferReader) -> SecureValueType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueTypePersonalDetails(_ reader: BufferReader) -> SecureValueType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueTypePhone(_ reader: BufferReader) -> SecureValueType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueTypeRentalAgreement(_ reader: BufferReader) -> SecureValueType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueTypeTemporaryRegistration(_ reader: BufferReader) -> SecureValueType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_secureValueTypeUtilityBill(_ reader: BufferReader) -> SecureValueType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SendAsPeer: TypeConstructorDescription {
        public class Cons_sendAsPeer {
            public var flags: Int32
            public var peer: Api.Peer
            public init(flags: Int32, peer: Api.Peer) {
                self.flags = flags
                self.peer = peer
            }
        }
        case sendAsPeer(Cons_sendAsPeer)

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

        public static func parse_sendAsPeer(_ reader: BufferReader) -> SendAsPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum SendMessageAction: TypeConstructorDescription {
        public class Cons_sendMessageEmojiInteraction {
            public var emoticon: String
            public var msgId: Int32
            public var interaction: Api.DataJSON
            public init(emoticon: String, msgId: Int32, interaction: Api.DataJSON) {
                self.emoticon = emoticon
                self.msgId = msgId
                self.interaction = interaction
            }
        }
        public class Cons_sendMessageEmojiInteractionSeen {
            public var emoticon: String
            public init(emoticon: String) {
                self.emoticon = emoticon
            }
        }
        public class Cons_sendMessageHistoryImportAction {
            public var progress: Int32
            public init(progress: Int32) {
                self.progress = progress
            }
        }
        public class Cons_sendMessageTextDraftAction {
            public var randomId: Int64
            public var text: Api.TextWithEntities
            public init(randomId: Int64, text: Api.TextWithEntities) {
                self.randomId = randomId
                self.text = text
            }
        }
        public class Cons_sendMessageUploadAudioAction {
            public var progress: Int32
            public init(progress: Int32) {
                self.progress = progress
            }
        }
        public class Cons_sendMessageUploadDocumentAction {
            public var progress: Int32
            public init(progress: Int32) {
                self.progress = progress
            }
        }
        public class Cons_sendMessageUploadPhotoAction {
            public var progress: Int32
            public init(progress: Int32) {
                self.progress = progress
            }
        }
        public class Cons_sendMessageUploadRoundAction {
            public var progress: Int32
            public init(progress: Int32) {
                self.progress = progress
            }
        }
        public class Cons_sendMessageUploadVideoAction {
            public var progress: Int32
            public init(progress: Int32) {
                self.progress = progress
            }
        }
        case sendMessageCancelAction
        case sendMessageChooseContactAction
        case sendMessageChooseStickerAction
        case sendMessageEmojiInteraction(Cons_sendMessageEmojiInteraction)
        case sendMessageEmojiInteractionSeen(Cons_sendMessageEmojiInteractionSeen)
        case sendMessageGamePlayAction
        case sendMessageGeoLocationAction
        case sendMessageHistoryImportAction(Cons_sendMessageHistoryImportAction)
        case sendMessageRecordAudioAction
        case sendMessageRecordRoundAction
        case sendMessageRecordVideoAction
        case sendMessageTextDraftAction(Cons_sendMessageTextDraftAction)
        case sendMessageTypingAction
        case sendMessageUploadAudioAction(Cons_sendMessageUploadAudioAction)
        case sendMessageUploadDocumentAction(Cons_sendMessageUploadDocumentAction)
        case sendMessageUploadPhotoAction(Cons_sendMessageUploadPhotoAction)
        case sendMessageUploadRoundAction(Cons_sendMessageUploadRoundAction)
        case sendMessageUploadVideoAction(Cons_sendMessageUploadVideoAction)
        case speakingInGroupCallAction

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

        public static func parse_sendMessageCancelAction(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sendMessageChooseContactAction(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sendMessageChooseStickerAction(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sendMessageEmojiInteraction(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sendMessageEmojiInteractionSeen(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sendMessageGamePlayAction(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sendMessageGeoLocationAction(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sendMessageHistoryImportAction(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sendMessageRecordAudioAction(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sendMessageRecordRoundAction(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sendMessageRecordVideoAction(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sendMessageTextDraftAction(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sendMessageTypingAction(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sendMessageUploadAudioAction(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sendMessageUploadDocumentAction(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sendMessageUploadPhotoAction(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sendMessageUploadRoundAction(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sendMessageUploadVideoAction(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_speakingInGroupCallAction(_ reader: BufferReader) -> SendMessageAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
