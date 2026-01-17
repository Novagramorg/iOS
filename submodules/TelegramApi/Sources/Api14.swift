public extension Api {
    enum InputTheme: TypeConstructorDescription {
        public class Cons_inputTheme {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
        }
        public class Cons_inputThemeSlug {
            public var slug: String
            public init(slug: String) {
                self.slug = slug
            }
        }
        case inputTheme(Cons_inputTheme)
        case inputThemeSlug(Cons_inputThemeSlug)

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

        public static func parse_inputTheme(_ reader: BufferReader) -> InputTheme? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputThemeSlug(_ reader: BufferReader) -> InputTheme? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputThemeSettings: TypeConstructorDescription {
        public class Cons_inputThemeSettings {
            public var flags: Int32
            public var baseTheme: Api.BaseTheme
            public var accentColor: Int32
            public var outboxAccentColor: Int32?
            public var messageColors: [Int32]?
            public var wallpaper: Api.InputWallPaper?
            public var wallpaperSettings: Api.WallPaperSettings?
            public init(flags: Int32, baseTheme: Api.BaseTheme, accentColor: Int32, outboxAccentColor: Int32?, messageColors: [Int32]?, wallpaper: Api.InputWallPaper?, wallpaperSettings: Api.WallPaperSettings?) {
                self.flags = flags
                self.baseTheme = baseTheme
                self.accentColor = accentColor
                self.outboxAccentColor = outboxAccentColor
                self.messageColors = messageColors
                self.wallpaper = wallpaper
                self.wallpaperSettings = wallpaperSettings
            }
        }
        case inputThemeSettings(Cons_inputThemeSettings)

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

        public static func parse_inputThemeSettings(_ reader: BufferReader) -> InputThemeSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum InputUser: TypeConstructorDescription {
        public class Cons_inputUser {
            public var userId: Int64
            public var accessHash: Int64
            public init(userId: Int64, accessHash: Int64) {
                self.userId = userId
                self.accessHash = accessHash
            }
        }
        public class Cons_inputUserFromMessage {
            public var peer: Api.InputPeer
            public var msgId: Int32
            public var userId: Int64
            public init(peer: Api.InputPeer, msgId: Int32, userId: Int64) {
                self.peer = peer
                self.msgId = msgId
                self.userId = userId
            }
        }
        case inputUser(Cons_inputUser)
        case inputUserEmpty
        case inputUserFromMessage(Cons_inputUserFromMessage)
        case inputUserSelf

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

        public static func parse_inputUser(_ reader: BufferReader) -> InputUser? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputUserEmpty(_ reader: BufferReader) -> InputUser? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputUserFromMessage(_ reader: BufferReader) -> InputUser? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputUserSelf(_ reader: BufferReader) -> InputUser? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputWallPaper: TypeConstructorDescription {
        public class Cons_inputWallPaper {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
        }
        public class Cons_inputWallPaperNoFile {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
        }
        public class Cons_inputWallPaperSlug {
            public var slug: String
            public init(slug: String) {
                self.slug = slug
            }
        }
        case inputWallPaper(Cons_inputWallPaper)
        case inputWallPaperNoFile(Cons_inputWallPaperNoFile)
        case inputWallPaperSlug(Cons_inputWallPaperSlug)

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

        public static func parse_inputWallPaper(_ reader: BufferReader) -> InputWallPaper? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputWallPaperNoFile(_ reader: BufferReader) -> InputWallPaper? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputWallPaperSlug(_ reader: BufferReader) -> InputWallPaper? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputWebDocument: TypeConstructorDescription {
        public class Cons_inputWebDocument {
            public var url: String
            public var size: Int32
            public var mimeType: String
            public var attributes: [Api.DocumentAttribute]
            public init(url: String, size: Int32, mimeType: String, attributes: [Api.DocumentAttribute]) {
                self.url = url
                self.size = size
                self.mimeType = mimeType
                self.attributes = attributes
            }
        }
        case inputWebDocument(Cons_inputWebDocument)

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

        public static func parse_inputWebDocument(_ reader: BufferReader) -> InputWebDocument? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputWebFileLocation: TypeConstructorDescription {
        public class Cons_inputWebFileAudioAlbumThumbLocation {
            public var flags: Int32
            public var document: Api.InputDocument?
            public var title: String?
            public var performer: String?
            public init(flags: Int32, document: Api.InputDocument?, title: String?, performer: String?) {
                self.flags = flags
                self.document = document
                self.title = title
                self.performer = performer
            }
        }
        public class Cons_inputWebFileGeoPointLocation {
            public var geoPoint: Api.InputGeoPoint
            public var accessHash: Int64
            public var w: Int32
            public var h: Int32
            public var zoom: Int32
            public var scale: Int32
            public init(geoPoint: Api.InputGeoPoint, accessHash: Int64, w: Int32, h: Int32, zoom: Int32, scale: Int32) {
                self.geoPoint = geoPoint
                self.accessHash = accessHash
                self.w = w
                self.h = h
                self.zoom = zoom
                self.scale = scale
            }
        }
        public class Cons_inputWebFileLocation {
            public var url: String
            public var accessHash: Int64
            public init(url: String, accessHash: Int64) {
                self.url = url
                self.accessHash = accessHash
            }
        }
        case inputWebFileAudioAlbumThumbLocation(Cons_inputWebFileAudioAlbumThumbLocation)
        case inputWebFileGeoPointLocation(Cons_inputWebFileGeoPointLocation)
        case inputWebFileLocation(Cons_inputWebFileLocation)

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

        public static func parse_inputWebFileAudioAlbumThumbLocation(_ reader: BufferReader) -> InputWebFileLocation? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputWebFileGeoPointLocation(_ reader: BufferReader) -> InputWebFileLocation? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputWebFileLocation(_ reader: BufferReader) -> InputWebFileLocation? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Invoice: TypeConstructorDescription {
        public class Cons_invoice {
            public var flags: Int32
            public var currency: String
            public var prices: [Api.LabeledPrice]
            public var maxTipAmount: Int64?
            public var suggestedTipAmounts: [Int64]?
            public var termsUrl: String?
            public var subscriptionPeriod: Int32?
            public init(flags: Int32, currency: String, prices: [Api.LabeledPrice], maxTipAmount: Int64?, suggestedTipAmounts: [Int64]?, termsUrl: String?, subscriptionPeriod: Int32?) {
                self.flags = flags
                self.currency = currency
                self.prices = prices
                self.maxTipAmount = maxTipAmount
                self.suggestedTipAmounts = suggestedTipAmounts
                self.termsUrl = termsUrl
                self.subscriptionPeriod = subscriptionPeriod
            }
        }
        case invoice(Cons_invoice)

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

        public static func parse_invoice(_ reader: BufferReader) -> Invoice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum JSONObjectValue: TypeConstructorDescription {
        public class Cons_jsonObjectValue {
            public var key: String
            public var value: Api.JSONValue
            public init(key: String, value: Api.JSONValue) {
                self.key = key
                self.value = value
            }
        }
        case jsonObjectValue(Cons_jsonObjectValue)

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

        public static func parse_jsonObjectValue(_ reader: BufferReader) -> JSONObjectValue? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum JSONValue: TypeConstructorDescription {
        public class Cons_jsonArray {
            public var value: [Api.JSONValue]
            public init(value: [Api.JSONValue]) {
                self.value = value
            }
        }
        public class Cons_jsonBool {
            public var value: Api.Bool
            public init(value: Api.Bool) {
                self.value = value
            }
        }
        public class Cons_jsonNumber {
            public var value: Double
            public init(value: Double) {
                self.value = value
            }
        }
        public class Cons_jsonObject {
            public var value: [Api.JSONObjectValue]
            public init(value: [Api.JSONObjectValue]) {
                self.value = value
            }
        }
        public class Cons_jsonString {
            public var value: String
            public init(value: String) {
                self.value = value
            }
        }
        case jsonArray(Cons_jsonArray)
        case jsonBool(Cons_jsonBool)
        case jsonNull
        case jsonNumber(Cons_jsonNumber)
        case jsonObject(Cons_jsonObject)
        case jsonString(Cons_jsonString)

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

        public static func parse_jsonArray(_ reader: BufferReader) -> JSONValue? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_jsonBool(_ reader: BufferReader) -> JSONValue? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_jsonNull(_ reader: BufferReader) -> JSONValue? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_jsonNumber(_ reader: BufferReader) -> JSONValue? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_jsonObject(_ reader: BufferReader) -> JSONValue? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_jsonString(_ reader: BufferReader) -> JSONValue? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum KeyboardButton: TypeConstructorDescription {
        public class Cons_inputKeyboardButtonRequestPeer {
            public var flags: Int32
            public var text: String
            public var buttonId: Int32
            public var peerType: Api.RequestPeerType
            public var maxQuantity: Int32
            public init(flags: Int32, text: String, buttonId: Int32, peerType: Api.RequestPeerType, maxQuantity: Int32) {
                self.flags = flags
                self.text = text
                self.buttonId = buttonId
                self.peerType = peerType
                self.maxQuantity = maxQuantity
            }
        }
        public class Cons_inputKeyboardButtonUrlAuth {
            public var flags: Int32
            public var text: String
            public var fwdText: String?
            public var url: String
            public var bot: Api.InputUser
            public init(flags: Int32, text: String, fwdText: String?, url: String, bot: Api.InputUser) {
                self.flags = flags
                self.text = text
                self.fwdText = fwdText
                self.url = url
                self.bot = bot
            }
        }
        public class Cons_inputKeyboardButtonUserProfile {
            public var text: String
            public var userId: Api.InputUser
            public init(text: String, userId: Api.InputUser) {
                self.text = text
                self.userId = userId
            }
        }
        public class Cons_keyboardButton {
            public var text: String
            public init(text: String) {
                self.text = text
            }
        }
        public class Cons_keyboardButtonBuy {
            public var text: String
            public init(text: String) {
                self.text = text
            }
        }
        public class Cons_keyboardButtonCallback {
            public var flags: Int32
            public var text: String
            public var data: Buffer
            public init(flags: Int32, text: String, data: Buffer) {
                self.flags = flags
                self.text = text
                self.data = data
            }
        }
        public class Cons_keyboardButtonCopy {
            public var text: String
            public var copyText: String
            public init(text: String, copyText: String) {
                self.text = text
                self.copyText = copyText
            }
        }
        public class Cons_keyboardButtonGame {
            public var text: String
            public init(text: String) {
                self.text = text
            }
        }
        public class Cons_keyboardButtonRequestGeoLocation {
            public var text: String
            public init(text: String) {
                self.text = text
            }
        }
        public class Cons_keyboardButtonRequestPeer {
            public var text: String
            public var buttonId: Int32
            public var peerType: Api.RequestPeerType
            public var maxQuantity: Int32
            public init(text: String, buttonId: Int32, peerType: Api.RequestPeerType, maxQuantity: Int32) {
                self.text = text
                self.buttonId = buttonId
                self.peerType = peerType
                self.maxQuantity = maxQuantity
            }
        }
        public class Cons_keyboardButtonRequestPhone {
            public var text: String
            public init(text: String) {
                self.text = text
            }
        }
        public class Cons_keyboardButtonRequestPoll {
            public var flags: Int32
            public var quiz: Api.Bool?
            public var text: String
            public init(flags: Int32, quiz: Api.Bool?, text: String) {
                self.flags = flags
                self.quiz = quiz
                self.text = text
            }
        }
        public class Cons_keyboardButtonSimpleWebView {
            public var text: String
            public var url: String
            public init(text: String, url: String) {
                self.text = text
                self.url = url
            }
        }
        public class Cons_keyboardButtonSwitchInline {
            public var flags: Int32
            public var text: String
            public var query: String
            public var peerTypes: [Api.InlineQueryPeerType]?
            public init(flags: Int32, text: String, query: String, peerTypes: [Api.InlineQueryPeerType]?) {
                self.flags = flags
                self.text = text
                self.query = query
                self.peerTypes = peerTypes
            }
        }
        public class Cons_keyboardButtonUrl {
            public var text: String
            public var url: String
            public init(text: String, url: String) {
                self.text = text
                self.url = url
            }
        }
        public class Cons_keyboardButtonUrlAuth {
            public var flags: Int32
            public var text: String
            public var fwdText: String?
            public var url: String
            public var buttonId: Int32
            public init(flags: Int32, text: String, fwdText: String?, url: String, buttonId: Int32) {
                self.flags = flags
                self.text = text
                self.fwdText = fwdText
                self.url = url
                self.buttonId = buttonId
            }
        }
        public class Cons_keyboardButtonUserProfile {
            public var text: String
            public var userId: Int64
            public init(text: String, userId: Int64) {
                self.text = text
                self.userId = userId
            }
        }
        public class Cons_keyboardButtonWebView {
            public var text: String
            public var url: String
            public init(text: String, url: String) {
                self.text = text
                self.url = url
            }
        }
        case inputKeyboardButtonRequestPeer(Cons_inputKeyboardButtonRequestPeer)
        case inputKeyboardButtonUrlAuth(Cons_inputKeyboardButtonUrlAuth)
        case inputKeyboardButtonUserProfile(Cons_inputKeyboardButtonUserProfile)
        case keyboardButton(Cons_keyboardButton)
        case keyboardButtonBuy(Cons_keyboardButtonBuy)
        case keyboardButtonCallback(Cons_keyboardButtonCallback)
        case keyboardButtonCopy(Cons_keyboardButtonCopy)
        case keyboardButtonGame(Cons_keyboardButtonGame)
        case keyboardButtonRequestGeoLocation(Cons_keyboardButtonRequestGeoLocation)
        case keyboardButtonRequestPeer(Cons_keyboardButtonRequestPeer)
        case keyboardButtonRequestPhone(Cons_keyboardButtonRequestPhone)
        case keyboardButtonRequestPoll(Cons_keyboardButtonRequestPoll)
        case keyboardButtonSimpleWebView(Cons_keyboardButtonSimpleWebView)
        case keyboardButtonSwitchInline(Cons_keyboardButtonSwitchInline)
        case keyboardButtonUrl(Cons_keyboardButtonUrl)
        case keyboardButtonUrlAuth(Cons_keyboardButtonUrlAuth)
        case keyboardButtonUserProfile(Cons_keyboardButtonUserProfile)
        case keyboardButtonWebView(Cons_keyboardButtonWebView)

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

        public static func parse_inputKeyboardButtonRequestPeer(_ reader: BufferReader) -> KeyboardButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputKeyboardButtonUrlAuth(_ reader: BufferReader) -> KeyboardButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputKeyboardButtonUserProfile(_ reader: BufferReader) -> KeyboardButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_keyboardButton(_ reader: BufferReader) -> KeyboardButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_keyboardButtonBuy(_ reader: BufferReader) -> KeyboardButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_keyboardButtonCallback(_ reader: BufferReader) -> KeyboardButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_keyboardButtonCopy(_ reader: BufferReader) -> KeyboardButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_keyboardButtonGame(_ reader: BufferReader) -> KeyboardButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_keyboardButtonRequestGeoLocation(_ reader: BufferReader) -> KeyboardButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_keyboardButtonRequestPeer(_ reader: BufferReader) -> KeyboardButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_keyboardButtonRequestPhone(_ reader: BufferReader) -> KeyboardButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_keyboardButtonRequestPoll(_ reader: BufferReader) -> KeyboardButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_keyboardButtonSimpleWebView(_ reader: BufferReader) -> KeyboardButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_keyboardButtonSwitchInline(_ reader: BufferReader) -> KeyboardButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_keyboardButtonUrl(_ reader: BufferReader) -> KeyboardButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_keyboardButtonUrlAuth(_ reader: BufferReader) -> KeyboardButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_keyboardButtonUserProfile(_ reader: BufferReader) -> KeyboardButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_keyboardButtonWebView(_ reader: BufferReader) -> KeyboardButton? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
