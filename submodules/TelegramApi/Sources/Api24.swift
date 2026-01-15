public extension Api {
    enum SecurePlainData: TypeConstructorDescription {
        case securePlainEmail(email: String)
        case securePlainPhone(phone: String)

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
        case secureRequiredType(flags: Int32, type: Api.SecureValueType)
        case secureRequiredTypeOneOf(types: [Api.SecureRequiredType])

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
        case secureSecretSettings(secureAlgo: Api.SecurePasswordKdfAlgo, secureSecret: Buffer, secureSecretId: Int64)

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
        case secureValue(flags: Int32, type: Api.SecureValueType, data: Api.SecureData?, frontSide: Api.SecureFile?, reverseSide: Api.SecureFile?, selfie: Api.SecureFile?, translation: [Api.SecureFile]?, files: [Api.SecureFile]?, plainData: Api.SecurePlainData?, hash: Buffer)

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
        case secureValueError(type: Api.SecureValueType, hash: Buffer, text: String)
        case secureValueErrorData(type: Api.SecureValueType, dataHash: Buffer, field: String, text: String)
        case secureValueErrorFile(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorFiles(type: Api.SecureValueType, fileHash: [Buffer], text: String)
        case secureValueErrorFrontSide(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorReverseSide(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorSelfie(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorTranslationFile(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorTranslationFiles(type: Api.SecureValueType, fileHash: [Buffer], text: String)

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
        case secureValueHash(type: Api.SecureValueType, hash: Buffer)

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
        case sendAsPeer(flags: Int32, peer: Api.Peer)

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
        case sendMessageCancelAction
        case sendMessageChooseContactAction
        case sendMessageChooseStickerAction
        case sendMessageEmojiInteraction(emoticon: String, msgId: Int32, interaction: Api.DataJSON)
        case sendMessageEmojiInteractionSeen(emoticon: String)
        case sendMessageGamePlayAction
        case sendMessageGeoLocationAction
        case sendMessageHistoryImportAction(progress: Int32)
        case sendMessageRecordAudioAction
        case sendMessageRecordRoundAction
        case sendMessageRecordVideoAction
        case sendMessageTextDraftAction(randomId: Int64, text: Api.TextWithEntities)
        case sendMessageTypingAction
        case sendMessageUploadAudioAction(progress: Int32)
        case sendMessageUploadDocumentAction(progress: Int32)
        case sendMessageUploadPhotoAction(progress: Int32)
        case sendMessageUploadRoundAction(progress: Int32)
        case sendMessageUploadVideoAction(progress: Int32)
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
