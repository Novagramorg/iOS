public extension Api.account {
    enum SavedMusicIds: TypeConstructorDescription {
        public class Cons_savedMusicIds {
            public var ids: [Int64]
            public init(ids: [Int64]) {
                self.ids = ids
            }
        }
        case savedMusicIds(Cons_savedMusicIds)
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
        public class Cons_savedRingtoneConverted {
            public var document: Api.Document
            public init(document: Api.Document) {
                self.document = document
            }
        }
        case savedRingtone
        case savedRingtoneConverted(Cons_savedRingtoneConverted)

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
        public class Cons_savedRingtones {
            public var hash: Int64
            public var ringtones: [Api.Document]
            public init(hash: Int64, ringtones: [Api.Document]) {
                self.hash = hash
                self.ringtones = ringtones
            }
        }
        case savedRingtones(Cons_savedRingtones)
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
        public class Cons_sentEmailCode {
            public var emailPattern: String
            public var length: Int32
            public init(emailPattern: String, length: Int32) {
                self.emailPattern = emailPattern
                self.length = length
            }
        }
        case sentEmailCode(Cons_sentEmailCode)

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
        public class Cons_takeout {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
        }
        case takeout(Cons_takeout)

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
        public class Cons_themes {
            public var hash: Int64
            public var themes: [Api.Theme]
            public init(hash: Int64, themes: [Api.Theme]) {
                self.hash = hash
                self.themes = themes
            }
        }
        case themes(Cons_themes)
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
        public class Cons_tmpPassword {
            public var tmpPassword: Buffer
            public var validUntil: Int32
            public init(tmpPassword: Buffer, validUntil: Int32) {
                self.tmpPassword = tmpPassword
                self.validUntil = validUntil
            }
        }
        case tmpPassword(Cons_tmpPassword)

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
        public class Cons_wallPapers {
            public var hash: Int64
            public var wallpapers: [Api.WallPaper]
            public init(hash: Int64, wallpapers: [Api.WallPaper]) {
                self.hash = hash
                self.wallpapers = wallpapers
            }
        }
        case wallPapers(Cons_wallPapers)
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
        public class Cons_webAuthorizations {
            public var authorizations: [Api.WebAuthorization]
            public var users: [Api.User]
            public init(authorizations: [Api.WebAuthorization], users: [Api.User]) {
                self.authorizations = authorizations
                self.users = users
            }
        }
        case webAuthorizations(Cons_webAuthorizations)

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
        public class Cons_authorization {
            public var flags: Int32
            public var otherwiseReloginDays: Int32?
            public var tmpSessions: Int32?
            public var futureAuthToken: Buffer?
            public var user: Api.User
            public init(flags: Int32, otherwiseReloginDays: Int32?, tmpSessions: Int32?, futureAuthToken: Buffer?, user: Api.User) {
                self.flags = flags
                self.otherwiseReloginDays = otherwiseReloginDays
                self.tmpSessions = tmpSessions
                self.futureAuthToken = futureAuthToken
                self.user = user
            }
        }
        public class Cons_authorizationSignUpRequired {
            public var flags: Int32
            public var termsOfService: Api.help.TermsOfService?
            public init(flags: Int32, termsOfService: Api.help.TermsOfService?) {
                self.flags = flags
                self.termsOfService = termsOfService
            }
        }
        case authorization(Cons_authorization)
        case authorizationSignUpRequired(Cons_authorizationSignUpRequired)

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
        public class Cons_exportedAuthorization {
            public var id: Int64
            public var bytes: Buffer
            public init(id: Int64, bytes: Buffer) {
                self.id = id
                self.bytes = bytes
            }
        }
        case exportedAuthorization(Cons_exportedAuthorization)

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
        public class Cons_loggedOut {
            public var flags: Int32
            public var futureAuthToken: Buffer?
            public init(flags: Int32, futureAuthToken: Buffer?) {
                self.flags = flags
                self.futureAuthToken = futureAuthToken
            }
        }
        case loggedOut(Cons_loggedOut)

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
        public class Cons_loginToken {
            public var expires: Int32
            public var token: Buffer
            public init(expires: Int32, token: Buffer) {
                self.expires = expires
                self.token = token
            }
        }
        public class Cons_loginTokenMigrateTo {
            public var dcId: Int32
            public var token: Buffer
            public init(dcId: Int32, token: Buffer) {
                self.dcId = dcId
                self.token = token
            }
        }
        public class Cons_loginTokenSuccess {
            public var authorization: Api.auth.Authorization
            public init(authorization: Api.auth.Authorization) {
                self.authorization = authorization
            }
        }
        case loginToken(Cons_loginToken)
        case loginTokenMigrateTo(Cons_loginTokenMigrateTo)
        case loginTokenSuccess(Cons_loginTokenSuccess)

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
        public class Cons_passkeyLoginOptions {
            public var options: Api.DataJSON
            public init(options: Api.DataJSON) {
                self.options = options
            }
        }
        case passkeyLoginOptions(Cons_passkeyLoginOptions)

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
        public class Cons_passwordRecovery {
            public var emailPattern: String
            public init(emailPattern: String) {
                self.emailPattern = emailPattern
            }
        }
        case passwordRecovery(Cons_passwordRecovery)

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
        public class Cons_sentCode {
            public var flags: Int32
            public var type: Api.auth.SentCodeType
            public var phoneCodeHash: String
            public var nextType: Api.auth.CodeType?
            public var timeout: Int32?
            public init(flags: Int32, type: Api.auth.SentCodeType, phoneCodeHash: String, nextType: Api.auth.CodeType?, timeout: Int32?) {
                self.flags = flags
                self.type = type
                self.phoneCodeHash = phoneCodeHash
                self.nextType = nextType
                self.timeout = timeout
            }
        }
        public class Cons_sentCodePaymentRequired {
            public var storeProduct: String
            public var phoneCodeHash: String
            public var supportEmailAddress: String
            public var supportEmailSubject: String
            public var currency: String
            public var amount: Int64
            public init(storeProduct: String, phoneCodeHash: String, supportEmailAddress: String, supportEmailSubject: String, currency: String, amount: Int64) {
                self.storeProduct = storeProduct
                self.phoneCodeHash = phoneCodeHash
                self.supportEmailAddress = supportEmailAddress
                self.supportEmailSubject = supportEmailSubject
                self.currency = currency
                self.amount = amount
            }
        }
        public class Cons_sentCodeSuccess {
            public var authorization: Api.auth.Authorization
            public init(authorization: Api.auth.Authorization) {
                self.authorization = authorization
            }
        }
        case sentCode(Cons_sentCode)
        case sentCodePaymentRequired(Cons_sentCodePaymentRequired)
        case sentCodeSuccess(Cons_sentCodeSuccess)

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
        public class Cons_sentCodeTypeApp {
            public var length: Int32
            public init(length: Int32) {
                self.length = length
            }
        }
        public class Cons_sentCodeTypeCall {
            public var length: Int32
            public init(length: Int32) {
                self.length = length
            }
        }
        public class Cons_sentCodeTypeEmailCode {
            public var flags: Int32
            public var emailPattern: String
            public var length: Int32
            public var resetAvailablePeriod: Int32?
            public var resetPendingDate: Int32?
            public init(flags: Int32, emailPattern: String, length: Int32, resetAvailablePeriod: Int32?, resetPendingDate: Int32?) {
                self.flags = flags
                self.emailPattern = emailPattern
                self.length = length
                self.resetAvailablePeriod = resetAvailablePeriod
                self.resetPendingDate = resetPendingDate
            }
        }
        public class Cons_sentCodeTypeFirebaseSms {
            public var flags: Int32
            public var nonce: Buffer?
            public var playIntegrityProjectId: Int64?
            public var playIntegrityNonce: Buffer?
            public var receipt: String?
            public var pushTimeout: Int32?
            public var length: Int32
            public init(flags: Int32, nonce: Buffer?, playIntegrityProjectId: Int64?, playIntegrityNonce: Buffer?, receipt: String?, pushTimeout: Int32?, length: Int32) {
                self.flags = flags
                self.nonce = nonce
                self.playIntegrityProjectId = playIntegrityProjectId
                self.playIntegrityNonce = playIntegrityNonce
                self.receipt = receipt
                self.pushTimeout = pushTimeout
                self.length = length
            }
        }
        public class Cons_sentCodeTypeFlashCall {
            public var pattern: String
            public init(pattern: String) {
                self.pattern = pattern
            }
        }
        public class Cons_sentCodeTypeFragmentSms {
            public var url: String
            public var length: Int32
            public init(url: String, length: Int32) {
                self.url = url
                self.length = length
            }
        }
        public class Cons_sentCodeTypeMissedCall {
            public var prefix: String
            public var length: Int32
            public init(prefix: String, length: Int32) {
                self.prefix = prefix
                self.length = length
            }
        }
        public class Cons_sentCodeTypeSetUpEmailRequired {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        public class Cons_sentCodeTypeSms {
            public var length: Int32
            public init(length: Int32) {
                self.length = length
            }
        }
        public class Cons_sentCodeTypeSmsPhrase {
            public var flags: Int32
            public var beginning: String?
            public init(flags: Int32, beginning: String?) {
                self.flags = flags
                self.beginning = beginning
            }
        }
        public class Cons_sentCodeTypeSmsWord {
            public var flags: Int32
            public var beginning: String?
            public init(flags: Int32, beginning: String?) {
                self.flags = flags
                self.beginning = beginning
            }
        }
        case sentCodeTypeApp(Cons_sentCodeTypeApp)
        case sentCodeTypeCall(Cons_sentCodeTypeCall)
        case sentCodeTypeEmailCode(Cons_sentCodeTypeEmailCode)
        case sentCodeTypeFirebaseSms(Cons_sentCodeTypeFirebaseSms)
        case sentCodeTypeFlashCall(Cons_sentCodeTypeFlashCall)
        case sentCodeTypeFragmentSms(Cons_sentCodeTypeFragmentSms)
        case sentCodeTypeMissedCall(Cons_sentCodeTypeMissedCall)
        case sentCodeTypeSetUpEmailRequired(Cons_sentCodeTypeSetUpEmailRequired)
        case sentCodeTypeSms(Cons_sentCodeTypeSms)
        case sentCodeTypeSmsPhrase(Cons_sentCodeTypeSmsPhrase)
        case sentCodeTypeSmsWord(Cons_sentCodeTypeSmsWord)

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
