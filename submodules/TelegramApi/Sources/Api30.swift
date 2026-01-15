public extension Api.account {
    enum SavedMusicIds: TypeConstructorDescription {
        case savedMusicIds(ids: [Int64])
        case savedMusicIdsNotModified

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

        public static func parse_savedMusicIds(_ reader: BufferReader) -> SavedMusicIds? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_savedMusicIdsNotModified(_ reader: BufferReader) -> SavedMusicIds? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum SavedRingtone: TypeConstructorDescription {
        case savedRingtone
        case savedRingtoneConverted(document: Api.Document)

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

        public static func parse_savedRingtone(_ reader: BufferReader) -> SavedRingtone? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_savedRingtoneConverted(_ reader: BufferReader) -> SavedRingtone? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum SavedRingtones: TypeConstructorDescription {
        case savedRingtones(hash: Int64, ringtones: [Api.Document])
        case savedRingtonesNotModified

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

        public static func parse_savedRingtones(_ reader: BufferReader) -> SavedRingtones? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_savedRingtonesNotModified(_ reader: BufferReader) -> SavedRingtones? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum SentEmailCode: TypeConstructorDescription {
        case sentEmailCode(emailPattern: String, length: Int32)

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

        public static func parse_sentEmailCode(_ reader: BufferReader) -> SentEmailCode? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum Takeout: TypeConstructorDescription {
        case takeout(id: Int64)

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

        public static func parse_takeout(_ reader: BufferReader) -> Takeout? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum Themes: TypeConstructorDescription {
        case themes(hash: Int64, themes: [Api.Theme])
        case themesNotModified

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

        public static func parse_themes(_ reader: BufferReader) -> Themes? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_themesNotModified(_ reader: BufferReader) -> Themes? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum TmpPassword: TypeConstructorDescription {
        case tmpPassword(tmpPassword: Buffer, validUntil: Int32)

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

        public static func parse_tmpPassword(_ reader: BufferReader) -> TmpPassword? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum WallPapers: TypeConstructorDescription {
        case wallPapers(hash: Int64, wallpapers: [Api.WallPaper])
        case wallPapersNotModified

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

        public static func parse_wallPapers(_ reader: BufferReader) -> WallPapers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_wallPapersNotModified(_ reader: BufferReader) -> WallPapers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.account {
    enum WebAuthorizations: TypeConstructorDescription {
        case webAuthorizations(authorizations: [Api.WebAuthorization], users: [Api.User])

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

        public static func parse_webAuthorizations(_ reader: BufferReader) -> WebAuthorizations? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.auth {
    enum Authorization: TypeConstructorDescription {
        case authorization(flags: Int32, otherwiseReloginDays: Int32?, tmpSessions: Int32?, futureAuthToken: Buffer?, user: Api.User)
        case authorizationSignUpRequired(flags: Int32, termsOfService: Api.help.TermsOfService?)

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

        public static func parse_authorization(_ reader: BufferReader) -> Authorization? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_authorizationSignUpRequired(_ reader: BufferReader) -> Authorization? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.auth {
    enum CodeType: TypeConstructorDescription {
        case codeTypeCall
        case codeTypeFlashCall
        case codeTypeFragmentSms
        case codeTypeMissedCall
        case codeTypeSms

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

        public static func parse_codeTypeCall(_ reader: BufferReader) -> CodeType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_codeTypeFlashCall(_ reader: BufferReader) -> CodeType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_codeTypeFragmentSms(_ reader: BufferReader) -> CodeType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_codeTypeMissedCall(_ reader: BufferReader) -> CodeType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_codeTypeSms(_ reader: BufferReader) -> CodeType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.auth {
    enum ExportedAuthorization: TypeConstructorDescription {
        case exportedAuthorization(id: Int64, bytes: Buffer)

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

        public static func parse_exportedAuthorization(_ reader: BufferReader) -> ExportedAuthorization? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.auth {
    enum LoggedOut: TypeConstructorDescription {
        case loggedOut(flags: Int32, futureAuthToken: Buffer?)

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

        public static func parse_loggedOut(_ reader: BufferReader) -> LoggedOut? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.auth {
    enum LoginToken: TypeConstructorDescription {
        case loginToken(expires: Int32, token: Buffer)
        case loginTokenMigrateTo(dcId: Int32, token: Buffer)
        case loginTokenSuccess(authorization: Api.auth.Authorization)

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

        public static func parse_loginToken(_ reader: BufferReader) -> LoginToken? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_loginTokenMigrateTo(_ reader: BufferReader) -> LoginToken? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_loginTokenSuccess(_ reader: BufferReader) -> LoginToken? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.auth {
    enum PasskeyLoginOptions: TypeConstructorDescription {
        case passkeyLoginOptions(options: Api.DataJSON)

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

        public static func parse_passkeyLoginOptions(_ reader: BufferReader) -> PasskeyLoginOptions? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.auth {
    enum PasswordRecovery: TypeConstructorDescription {
        case passwordRecovery(emailPattern: String)

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

        public static func parse_passwordRecovery(_ reader: BufferReader) -> PasswordRecovery? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.auth {
    enum SentCode: TypeConstructorDescription {
        case sentCode(flags: Int32, type: Api.auth.SentCodeType, phoneCodeHash: String, nextType: Api.auth.CodeType?, timeout: Int32?)
        case sentCodePaymentRequired(storeProduct: String, phoneCodeHash: String, supportEmailAddress: String, supportEmailSubject: String, currency: String, amount: Int64)
        case sentCodeSuccess(authorization: Api.auth.Authorization)

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

        public static func parse_sentCode(_ reader: BufferReader) -> SentCode? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sentCodePaymentRequired(_ reader: BufferReader) -> SentCode? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sentCodeSuccess(_ reader: BufferReader) -> SentCode? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.auth {
    enum SentCodeType: TypeConstructorDescription {
        case sentCodeTypeApp(length: Int32)
        case sentCodeTypeCall(length: Int32)
        case sentCodeTypeEmailCode(flags: Int32, emailPattern: String, length: Int32, resetAvailablePeriod: Int32?, resetPendingDate: Int32?)
        case sentCodeTypeFirebaseSms(flags: Int32, nonce: Buffer?, playIntegrityProjectId: Int64?, playIntegrityNonce: Buffer?, receipt: String?, pushTimeout: Int32?, length: Int32)
        case sentCodeTypeFlashCall(pattern: String)
        case sentCodeTypeFragmentSms(url: String, length: Int32)
        case sentCodeTypeMissedCall(prefix: String, length: Int32)
        case sentCodeTypeSetUpEmailRequired(flags: Int32)
        case sentCodeTypeSms(length: Int32)
        case sentCodeTypeSmsPhrase(flags: Int32, beginning: String?)
        case sentCodeTypeSmsWord(flags: Int32, beginning: String?)

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

        public static func parse_sentCodeTypeApp(_ reader: BufferReader) -> SentCodeType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sentCodeTypeCall(_ reader: BufferReader) -> SentCodeType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sentCodeTypeEmailCode(_ reader: BufferReader) -> SentCodeType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sentCodeTypeFirebaseSms(_ reader: BufferReader) -> SentCodeType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sentCodeTypeFlashCall(_ reader: BufferReader) -> SentCodeType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sentCodeTypeFragmentSms(_ reader: BufferReader) -> SentCodeType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sentCodeTypeMissedCall(_ reader: BufferReader) -> SentCodeType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sentCodeTypeSetUpEmailRequired(_ reader: BufferReader) -> SentCodeType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sentCodeTypeSms(_ reader: BufferReader) -> SentCodeType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sentCodeTypeSmsPhrase(_ reader: BufferReader) -> SentCodeType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sentCodeTypeSmsWord(_ reader: BufferReader) -> SentCodeType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
