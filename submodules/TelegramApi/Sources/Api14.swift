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
            switch self {
            case .inputTheme(let _data):
                if boxed {
                    buffer.appendInt32(1012306921)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputThemeSlug(let _data):
                if boxed {
                    buffer.appendInt32(-175567375)
                }
                serializeString(_data.slug, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputTheme(let _data):
                return ("inputTheme", [("id", _data.id as Any), ("accessHash", _data.accessHash as Any)])
            case .inputThemeSlug(let _data):
                return ("inputThemeSlug", [("slug", _data.slug as Any)])
            }
        }

        public static func parse_inputTheme(_ reader: BufferReader) -> InputTheme? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputTheme.inputTheme(Cons_inputTheme(id: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputThemeSlug(_ reader: BufferReader) -> InputTheme? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputTheme.inputThemeSlug(Cons_inputThemeSlug(slug: _1!))
            }
            else {
                return nil
            }
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
            switch self {
            case .inputThemeSettings(let _data):
                if boxed {
                    buffer.appendInt32(-1881255857)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.baseTheme.serialize(buffer, true)
                serializeInt32(_data.accentColor, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.outboxAccentColor!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.messageColors!.count))
                    for item in _data.messageColors! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.wallpaper!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.wallpaperSettings!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputThemeSettings(let _data):
                return ("inputThemeSettings", [("flags", _data.flags as Any), ("baseTheme", _data.baseTheme as Any), ("accentColor", _data.accentColor as Any), ("outboxAccentColor", _data.outboxAccentColor as Any), ("messageColors", _data.messageColors as Any), ("wallpaper", _data.wallpaper as Any), ("wallpaperSettings", _data.wallpaperSettings as Any)])
            }
        }

        public static func parse_inputThemeSettings(_ reader: BufferReader) -> InputThemeSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.BaseTheme?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.BaseTheme
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {
                _4 = reader.readInt32()
            }
            var _5: [Int32]?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _5 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                }
            }
            var _6: Api.InputWallPaper?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.InputWallPaper
                }
            }
            var _7: Api.WallPaperSettings?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.WallPaperSettings
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.InputThemeSettings.inputThemeSettings(Cons_inputThemeSettings(flags: _1!, baseTheme: _2!, accentColor: _3!, outboxAccentColor: _4, messageColors: _5, wallpaper: _6, wallpaperSettings: _7))
            }
            else {
                return nil
            }
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
            switch self {
            case .inputUser(let _data):
                if boxed {
                    buffer.appendInt32(-233744186)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputUserEmpty:
                if boxed {
                    buffer.appendInt32(-1182234929)
                }
                break
            case .inputUserFromMessage(let _data):
                if boxed {
                    buffer.appendInt32(497305826)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                break
            case .inputUserSelf:
                if boxed {
                    buffer.appendInt32(-138301121)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputUser(let _data):
                return ("inputUser", [("userId", _data.userId as Any), ("accessHash", _data.accessHash as Any)])
            case .inputUserEmpty:
                return ("inputUserEmpty", [])
            case .inputUserFromMessage(let _data):
                return ("inputUserFromMessage", [("peer", _data.peer as Any), ("msgId", _data.msgId as Any), ("userId", _data.userId as Any)])
            case .inputUserSelf:
                return ("inputUserSelf", [])
            }
        }

        public static func parse_inputUser(_ reader: BufferReader) -> InputUser? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputUser.inputUser(Cons_inputUser(userId: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputUserEmpty(_ reader: BufferReader) -> InputUser? {
            return Api.InputUser.inputUserEmpty
        }
        public static func parse_inputUserFromMessage(_ reader: BufferReader) -> InputUser? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputUser.inputUserFromMessage(Cons_inputUserFromMessage(peer: _1!, msgId: _2!, userId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputUserSelf(_ reader: BufferReader) -> InputUser? {
            return Api.InputUser.inputUserSelf
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
            switch self {
            case .inputWallPaper(let _data):
                if boxed {
                    buffer.appendInt32(-433014407)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputWallPaperNoFile(let _data):
                if boxed {
                    buffer.appendInt32(-1770371538)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                break
            case .inputWallPaperSlug(let _data):
                if boxed {
                    buffer.appendInt32(1913199744)
                }
                serializeString(_data.slug, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputWallPaper(let _data):
                return ("inputWallPaper", [("id", _data.id as Any), ("accessHash", _data.accessHash as Any)])
            case .inputWallPaperNoFile(let _data):
                return ("inputWallPaperNoFile", [("id", _data.id as Any)])
            case .inputWallPaperSlug(let _data):
                return ("inputWallPaperSlug", [("slug", _data.slug as Any)])
            }
        }

        public static func parse_inputWallPaper(_ reader: BufferReader) -> InputWallPaper? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputWallPaper.inputWallPaper(Cons_inputWallPaper(id: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputWallPaperNoFile(_ reader: BufferReader) -> InputWallPaper? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputWallPaper.inputWallPaperNoFile(Cons_inputWallPaperNoFile(id: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputWallPaperSlug(_ reader: BufferReader) -> InputWallPaper? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputWallPaper.inputWallPaperSlug(Cons_inputWallPaperSlug(slug: _1!))
            }
            else {
                return nil
            }
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
            switch self {
            case .inputWebDocument(let _data):
                if boxed {
                    buffer.appendInt32(-1678949555)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt32(_data.size, buffer: buffer, boxed: false)
                serializeString(_data.mimeType, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.attributes.count))
                for item in _data.attributes {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputWebDocument(let _data):
                return ("inputWebDocument", [("url", _data.url as Any), ("size", _data.size as Any), ("mimeType", _data.mimeType as Any), ("attributes", _data.attributes as Any)])
            }
        }

        public static func parse_inputWebDocument(_ reader: BufferReader) -> InputWebDocument? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DocumentAttribute.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputWebDocument.inputWebDocument(Cons_inputWebDocument(url: _1!, size: _2!, mimeType: _3!, attributes: _4!))
            }
            else {
                return nil
            }
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
            switch self {
            case .inputWebFileAudioAlbumThumbLocation(let _data):
                if boxed {
                    buffer.appendInt32(-193992412)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.document!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.performer!, buffer: buffer, boxed: false)
                }
                break
            case .inputWebFileGeoPointLocation(let _data):
                if boxed {
                    buffer.appendInt32(-1625153079)
                }
                _data.geoPoint.serialize(buffer, true)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeInt32(_data.w, buffer: buffer, boxed: false)
                serializeInt32(_data.h, buffer: buffer, boxed: false)
                serializeInt32(_data.zoom, buffer: buffer, boxed: false)
                serializeInt32(_data.scale, buffer: buffer, boxed: false)
                break
            case .inputWebFileLocation(let _data):
                if boxed {
                    buffer.appendInt32(-1036396922)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputWebFileAudioAlbumThumbLocation(let _data):
                return ("inputWebFileAudioAlbumThumbLocation", [("flags", _data.flags as Any), ("document", _data.document as Any), ("title", _data.title as Any), ("performer", _data.performer as Any)])
            case .inputWebFileGeoPointLocation(let _data):
                return ("inputWebFileGeoPointLocation", [("geoPoint", _data.geoPoint as Any), ("accessHash", _data.accessHash as Any), ("w", _data.w as Any), ("h", _data.h as Any), ("zoom", _data.zoom as Any), ("scale", _data.scale as Any)])
            case .inputWebFileLocation(let _data):
                return ("inputWebFileLocation", [("url", _data.url as Any), ("accessHash", _data.accessHash as Any)])
            }
        }

        public static func parse_inputWebFileAudioAlbumThumbLocation(_ reader: BufferReader) -> InputWebFileLocation? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputDocument?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.InputDocument
                }
            }
            var _3: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _3 = parseString(reader)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputWebFileLocation.inputWebFileAudioAlbumThumbLocation(Cons_inputWebFileAudioAlbumThumbLocation(flags: _1!, document: _2, title: _3, performer: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_inputWebFileGeoPointLocation(_ reader: BufferReader) -> InputWebFileLocation? {
            var _1: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputWebFileLocation.inputWebFileGeoPointLocation(Cons_inputWebFileGeoPointLocation(geoPoint: _1!, accessHash: _2!, w: _3!, h: _4!, zoom: _5!, scale: _6!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputWebFileLocation(_ reader: BufferReader) -> InputWebFileLocation? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputWebFileLocation.inputWebFileLocation(Cons_inputWebFileLocation(url: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
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
            switch self {
            case .invoice(let _data):
                if boxed {
                    buffer.appendInt32(77522308)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.prices.count))
                for item in _data.prices {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeInt64(_data.maxTipAmount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.suggestedTipAmounts!.count))
                    for item in _data.suggestedTipAmounts! {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    serializeString(_data.termsUrl!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeInt32(_data.subscriptionPeriod!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .invoice(let _data):
                return ("invoice", [("flags", _data.flags as Any), ("currency", _data.currency as Any), ("prices", _data.prices as Any), ("maxTipAmount", _data.maxTipAmount as Any), ("suggestedTipAmounts", _data.suggestedTipAmounts as Any), ("termsUrl", _data.termsUrl as Any), ("subscriptionPeriod", _data.subscriptionPeriod as Any)])
            }
        }

        public static func parse_invoice(_ reader: BufferReader) -> Invoice? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.LabeledPrice]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.LabeledPrice.self)
            }
            var _4: Int64?
            if Int(_1!) & Int(1 << 8) != 0 {
                _4 = reader.readInt64()
            }
            var _5: [Int64]?
            if Int(_1!) & Int(1 << 8) != 0 {
                if let _ = reader.readInt32() {
                    _5 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
                }
            }
            var _6: String?
            if Int(_1!) & Int(1 << 10) != 0 {
                _6 = parseString(reader)
            }
            var _7: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {
                _7 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 8) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 8) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 10) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 11) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.Invoice.invoice(Cons_invoice(flags: _1!, currency: _2!, prices: _3!, maxTipAmount: _4, suggestedTipAmounts: _5, termsUrl: _6, subscriptionPeriod: _7))
            }
            else {
                return nil
            }
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
            switch self {
            case .jsonObjectValue(let _data):
                if boxed {
                    buffer.appendInt32(-1059185703)
                }
                serializeString(_data.key, buffer: buffer, boxed: false)
                _data.value.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .jsonObjectValue(let _data):
                return ("jsonObjectValue", [("key", _data.key as Any), ("value", _data.value as Any)])
            }
        }

        public static func parse_jsonObjectValue(_ reader: BufferReader) -> JSONObjectValue? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.JSONValue?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.JSONValue
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.JSONObjectValue.jsonObjectValue(Cons_jsonObjectValue(key: _1!, value: _2!))
            }
            else {
                return nil
            }
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
            switch self {
            case .jsonArray(let _data):
                if boxed {
                    buffer.appendInt32(-146520221)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.value.count))
                for item in _data.value {
                    item.serialize(buffer, true)
                }
                break
            case .jsonBool(let _data):
                if boxed {
                    buffer.appendInt32(-952869270)
                }
                _data.value.serialize(buffer, true)
                break
            case .jsonNull:
                if boxed {
                    buffer.appendInt32(1064139624)
                }
                break
            case .jsonNumber(let _data):
                if boxed {
                    buffer.appendInt32(736157604)
                }
                serializeDouble(_data.value, buffer: buffer, boxed: false)
                break
            case .jsonObject(let _data):
                if boxed {
                    buffer.appendInt32(-1715350371)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.value.count))
                for item in _data.value {
                    item.serialize(buffer, true)
                }
                break
            case .jsonString(let _data):
                if boxed {
                    buffer.appendInt32(-1222740358)
                }
                serializeString(_data.value, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .jsonArray(let _data):
                return ("jsonArray", [("value", _data.value as Any)])
            case .jsonBool(let _data):
                return ("jsonBool", [("value", _data.value as Any)])
            case .jsonNull:
                return ("jsonNull", [])
            case .jsonNumber(let _data):
                return ("jsonNumber", [("value", _data.value as Any)])
            case .jsonObject(let _data):
                return ("jsonObject", [("value", _data.value as Any)])
            case .jsonString(let _data):
                return ("jsonString", [("value", _data.value as Any)])
            }
        }

        public static func parse_jsonArray(_ reader: BufferReader) -> JSONValue? {
            var _1: [Api.JSONValue]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.JSONValue.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonArray(Cons_jsonArray(value: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_jsonBool(_ reader: BufferReader) -> JSONValue? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonBool(Cons_jsonBool(value: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_jsonNull(_ reader: BufferReader) -> JSONValue? {
            return Api.JSONValue.jsonNull
        }
        public static func parse_jsonNumber(_ reader: BufferReader) -> JSONValue? {
            var _1: Double?
            _1 = reader.readDouble()
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonNumber(Cons_jsonNumber(value: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_jsonObject(_ reader: BufferReader) -> JSONValue? {
            var _1: [Api.JSONObjectValue]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.JSONObjectValue.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonObject(Cons_jsonObject(value: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_jsonString(_ reader: BufferReader) -> JSONValue? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonString(Cons_jsonString(value: _1!))
            }
            else {
                return nil
            }
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
            switch self {
            case .inputKeyboardButtonRequestPeer(let _data):
                if boxed {
                    buffer.appendInt32(-916050683)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                serializeInt32(_data.buttonId, buffer: buffer, boxed: false)
                _data.peerType.serialize(buffer, true)
                serializeInt32(_data.maxQuantity, buffer: buffer, boxed: false)
                break
            case .inputKeyboardButtonUrlAuth(let _data):
                if boxed {
                    buffer.appendInt32(-802258988)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.fwdText!, buffer: buffer, boxed: false)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                _data.bot.serialize(buffer, true)
                break
            case .inputKeyboardButtonUserProfile(let _data):
                if boxed {
                    buffer.appendInt32(-376962181)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                _data.userId.serialize(buffer, true)
                break
            case .keyboardButton(let _data):
                if boxed {
                    buffer.appendInt32(-1560655744)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .keyboardButtonBuy(let _data):
                if boxed {
                    buffer.appendInt32(-1344716869)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .keyboardButtonCallback(let _data):
                if boxed {
                    buffer.appendInt32(901503851)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                serializeBytes(_data.data, buffer: buffer, boxed: false)
                break
            case .keyboardButtonCopy(let _data):
                if boxed {
                    buffer.appendInt32(1976723854)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                serializeString(_data.copyText, buffer: buffer, boxed: false)
                break
            case .keyboardButtonGame(let _data):
                if boxed {
                    buffer.appendInt32(1358175439)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .keyboardButtonRequestGeoLocation(let _data):
                if boxed {
                    buffer.appendInt32(-59151553)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .keyboardButtonRequestPeer(let _data):
                if boxed {
                    buffer.appendInt32(1406648280)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                serializeInt32(_data.buttonId, buffer: buffer, boxed: false)
                _data.peerType.serialize(buffer, true)
                serializeInt32(_data.maxQuantity, buffer: buffer, boxed: false)
                break
            case .keyboardButtonRequestPhone(let _data):
                if boxed {
                    buffer.appendInt32(-1318425559)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .keyboardButtonRequestPoll(let _data):
                if boxed {
                    buffer.appendInt32(-1144565411)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.quiz!.serialize(buffer, true)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .keyboardButtonSimpleWebView(let _data):
                if boxed {
                    buffer.appendInt32(-1598009252)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            case .keyboardButtonSwitchInline(let _data):
                if boxed {
                    buffer.appendInt32(-1816527947)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                serializeString(_data.query, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.peerTypes!.count))
                    for item in _data.peerTypes! {
                        item.serialize(buffer, true)
                    }
                }
                break
            case .keyboardButtonUrl(let _data):
                if boxed {
                    buffer.appendInt32(629866245)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            case .keyboardButtonUrlAuth(let _data):
                if boxed {
                    buffer.appendInt32(280464681)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.fwdText!, buffer: buffer, boxed: false)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt32(_data.buttonId, buffer: buffer, boxed: false)
                break
            case .keyboardButtonUserProfile(let _data):
                if boxed {
                    buffer.appendInt32(814112961)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                break
            case .keyboardButtonWebView(let _data):
                if boxed {
                    buffer.appendInt32(326529584)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputKeyboardButtonRequestPeer(let _data):
                return ("inputKeyboardButtonRequestPeer", [("flags", _data.flags as Any), ("text", _data.text as Any), ("buttonId", _data.buttonId as Any), ("peerType", _data.peerType as Any), ("maxQuantity", _data.maxQuantity as Any)])
            case .inputKeyboardButtonUrlAuth(let _data):
                return ("inputKeyboardButtonUrlAuth", [("flags", _data.flags as Any), ("text", _data.text as Any), ("fwdText", _data.fwdText as Any), ("url", _data.url as Any), ("bot", _data.bot as Any)])
            case .inputKeyboardButtonUserProfile(let _data):
                return ("inputKeyboardButtonUserProfile", [("text", _data.text as Any), ("userId", _data.userId as Any)])
            case .keyboardButton(let _data):
                return ("keyboardButton", [("text", _data.text as Any)])
            case .keyboardButtonBuy(let _data):
                return ("keyboardButtonBuy", [("text", _data.text as Any)])
            case .keyboardButtonCallback(let _data):
                return ("keyboardButtonCallback", [("flags", _data.flags as Any), ("text", _data.text as Any), ("data", _data.data as Any)])
            case .keyboardButtonCopy(let _data):
                return ("keyboardButtonCopy", [("text", _data.text as Any), ("copyText", _data.copyText as Any)])
            case .keyboardButtonGame(let _data):
                return ("keyboardButtonGame", [("text", _data.text as Any)])
            case .keyboardButtonRequestGeoLocation(let _data):
                return ("keyboardButtonRequestGeoLocation", [("text", _data.text as Any)])
            case .keyboardButtonRequestPeer(let _data):
                return ("keyboardButtonRequestPeer", [("text", _data.text as Any), ("buttonId", _data.buttonId as Any), ("peerType", _data.peerType as Any), ("maxQuantity", _data.maxQuantity as Any)])
            case .keyboardButtonRequestPhone(let _data):
                return ("keyboardButtonRequestPhone", [("text", _data.text as Any)])
            case .keyboardButtonRequestPoll(let _data):
                return ("keyboardButtonRequestPoll", [("flags", _data.flags as Any), ("quiz", _data.quiz as Any), ("text", _data.text as Any)])
            case .keyboardButtonSimpleWebView(let _data):
                return ("keyboardButtonSimpleWebView", [("text", _data.text as Any), ("url", _data.url as Any)])
            case .keyboardButtonSwitchInline(let _data):
                return ("keyboardButtonSwitchInline", [("flags", _data.flags as Any), ("text", _data.text as Any), ("query", _data.query as Any), ("peerTypes", _data.peerTypes as Any)])
            case .keyboardButtonUrl(let _data):
                return ("keyboardButtonUrl", [("text", _data.text as Any), ("url", _data.url as Any)])
            case .keyboardButtonUrlAuth(let _data):
                return ("keyboardButtonUrlAuth", [("flags", _data.flags as Any), ("text", _data.text as Any), ("fwdText", _data.fwdText as Any), ("url", _data.url as Any), ("buttonId", _data.buttonId as Any)])
            case .keyboardButtonUserProfile(let _data):
                return ("keyboardButtonUserProfile", [("text", _data.text as Any), ("userId", _data.userId as Any)])
            case .keyboardButtonWebView(let _data):
                return ("keyboardButtonWebView", [("text", _data.text as Any), ("url", _data.url as Any)])
            }
        }

        public static func parse_inputKeyboardButtonRequestPeer(_ reader: BufferReader) -> KeyboardButton? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.RequestPeerType?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.RequestPeerType
            }
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.KeyboardButton.inputKeyboardButtonRequestPeer(Cons_inputKeyboardButtonRequestPeer(flags: _1!, text: _2!, buttonId: _3!, peerType: _4!, maxQuantity: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputKeyboardButtonUrlAuth(_ reader: BufferReader) -> KeyboardButton? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _3 = parseString(reader)
            }
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.InputUser?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.KeyboardButton.inputKeyboardButtonUrlAuth(Cons_inputKeyboardButtonUrlAuth(flags: _1!, text: _2!, fwdText: _3, url: _4!, bot: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputKeyboardButtonUserProfile(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.InputUser?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.KeyboardButton.inputKeyboardButtonUserProfile(Cons_inputKeyboardButtonUserProfile(text: _1!, userId: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButton(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButton.keyboardButton(Cons_keyboardButton(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonBuy(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButton.keyboardButtonBuy(Cons_keyboardButtonBuy(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonCallback(_ reader: BufferReader) -> KeyboardButton? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.KeyboardButton.keyboardButtonCallback(Cons_keyboardButtonCallback(flags: _1!, text: _2!, data: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonCopy(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.KeyboardButton.keyboardButtonCopy(Cons_keyboardButtonCopy(text: _1!, copyText: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonGame(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButton.keyboardButtonGame(Cons_keyboardButtonGame(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonRequestGeoLocation(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButton.keyboardButtonRequestGeoLocation(Cons_keyboardButtonRequestGeoLocation(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonRequestPeer(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.RequestPeerType?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.RequestPeerType
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.KeyboardButton.keyboardButtonRequestPeer(Cons_keyboardButtonRequestPeer(text: _1!, buttonId: _2!, peerType: _3!, maxQuantity: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonRequestPhone(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButton.keyboardButtonRequestPhone(Cons_keyboardButtonRequestPhone(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonRequestPoll(_ reader: BufferReader) -> KeyboardButton? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.KeyboardButton.keyboardButtonRequestPoll(Cons_keyboardButtonRequestPoll(flags: _1!, quiz: _2, text: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonSimpleWebView(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.KeyboardButton.keyboardButtonSimpleWebView(Cons_keyboardButtonSimpleWebView(text: _1!, url: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonSwitchInline(_ reader: BufferReader) -> KeyboardButton? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.InlineQueryPeerType]?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InlineQueryPeerType.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.KeyboardButton.keyboardButtonSwitchInline(Cons_keyboardButtonSwitchInline(flags: _1!, text: _2!, query: _3!, peerTypes: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonUrl(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.KeyboardButton.keyboardButtonUrl(Cons_keyboardButtonUrl(text: _1!, url: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonUrlAuth(_ reader: BufferReader) -> KeyboardButton? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.KeyboardButton.keyboardButtonUrlAuth(Cons_keyboardButtonUrlAuth(flags: _1!, text: _2!, fwdText: _3, url: _4!, buttonId: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonUserProfile(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.KeyboardButton.keyboardButtonUserProfile(Cons_keyboardButtonUserProfile(text: _1!, userId: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonWebView(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.KeyboardButton.keyboardButtonWebView(Cons_keyboardButtonWebView(text: _1!, url: _2!))
            }
            else {
                return nil
            }
        }
    }
}
