public extension Api.wallet {
    enum HolderDc: TypeConstructorDescription {
        public class Cons_holderDc: TypeConstructorDescription {
            public var dc: Int32
            public var publicKey: Buffer
            public init(dc: Int32, publicKey: Buffer) {
                self.dc = dc
                self.publicKey = publicKey
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("holderDc", [("dc", ConstructorParameterDescription(self.dc)), ("publicKey", ConstructorParameterDescription(self.publicKey))])
            }
        }
        case holderDc(Cons_holderDc)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .holderDc(let _data):
                if boxed {
                    buffer.appendInt32(-103410961)
                }
                serializeInt32(_data.dc, buffer: buffer, boxed: false)
                serializeBytes(_data.publicKey, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .holderDc(let _data):
                return ("holderDc", [("dc", ConstructorParameterDescription(_data.dc)), ("publicKey", ConstructorParameterDescription(_data.publicKey))])
            }
        }

        public static func parse_holderDc(_ reader: BufferReader) -> HolderDc? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.wallet.HolderDc.holderDc(Cons_holderDc(dc: _1!, publicKey: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.wallet {
    enum ProofChallenge: TypeConstructorDescription {
        public class Cons_proofChallenge: TypeConstructorDescription {
            public var payload: String
            public var expires: Int32
            public var domain: String
            public init(payload: String, expires: Int32, domain: String) {
                self.payload = payload
                self.expires = expires
                self.domain = domain
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("proofChallenge", [("payload", ConstructorParameterDescription(self.payload)), ("expires", ConstructorParameterDescription(self.expires)), ("domain", ConstructorParameterDescription(self.domain))])
            }
        }
        case proofChallenge(Cons_proofChallenge)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .proofChallenge(let _data):
                if boxed {
                    buffer.appendInt32(-1713105145)
                }
                serializeString(_data.payload, buffer: buffer, boxed: false)
                serializeInt32(_data.expires, buffer: buffer, boxed: false)
                serializeString(_data.domain, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .proofChallenge(let _data):
                return ("proofChallenge", [("payload", ConstructorParameterDescription(_data.payload)), ("expires", ConstructorParameterDescription(_data.expires)), ("domain", ConstructorParameterDescription(_data.domain))])
            }
        }

        public static func parse_proofChallenge(_ reader: BufferReader) -> ProofChallenge? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.wallet.ProofChallenge.proofChallenge(Cons_proofChallenge(payload: _1!, expires: _2!, domain: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.wallet {
    enum SecretPhraseParts: TypeConstructorDescription {
        public class Cons_secretPhraseParts: TypeConstructorDescription {
            public var token: String
            public var dcs: [Int32]
            public init(token: String, dcs: [Int32]) {
                self.token = token
                self.dcs = dcs
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("secretPhraseParts", [("token", ConstructorParameterDescription(self.token)), ("dcs", ConstructorParameterDescription(self.dcs))])
            }
        }
        case secretPhraseParts(Cons_secretPhraseParts)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secretPhraseParts(let _data):
                if boxed {
                    buffer.appendInt32(-422514943)
                }
                serializeString(_data.token, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.dcs.count))
                for item in _data.dcs {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .secretPhraseParts(let _data):
                return ("secretPhraseParts", [("token", ConstructorParameterDescription(_data.token)), ("dcs", ConstructorParameterDescription(_data.dcs))])
            }
        }

        public static func parse_secretPhraseParts(_ reader: BufferReader) -> SecretPhraseParts? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.wallet.SecretPhraseParts.secretPhraseParts(Cons_secretPhraseParts(token: _1!, dcs: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.wallet {
    enum TonConnectChallenge: TypeConstructorDescription {
        public class Cons_tonConnectChallenge: TypeConstructorDescription {
            public var challenge: Buffer
            public var eventId: Int64
            public init(challenge: Buffer, eventId: Int64) {
                self.challenge = challenge
                self.eventId = eventId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("tonConnectChallenge", [("challenge", ConstructorParameterDescription(self.challenge)), ("eventId", ConstructorParameterDescription(self.eventId))])
            }
        }
        case tonConnectChallenge(Cons_tonConnectChallenge)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .tonConnectChallenge(let _data):
                if boxed {
                    buffer.appendInt32(1271436947)
                }
                serializeBytes(_data.challenge, buffer: buffer, boxed: false)
                serializeInt64(_data.eventId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .tonConnectChallenge(let _data):
                return ("tonConnectChallenge", [("challenge", ConstructorParameterDescription(_data.challenge)), ("eventId", ConstructorParameterDescription(_data.eventId))])
            }
        }

        public static func parse_tonConnectChallenge(_ reader: BufferReader) -> TonConnectChallenge? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.wallet.TonConnectChallenge.tonConnectChallenge(Cons_tonConnectChallenge(challenge: _1!, eventId: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.wallet {
    enum TonConnectPending: TypeConstructorDescription {
        public class Cons_tonConnectPending: TypeConstructorDescription {
            public var session: Api.TonConnectSession
            public var requests: [Api.TonConnectRequest]
            public init(session: Api.TonConnectSession, requests: [Api.TonConnectRequest]) {
                self.session = session
                self.requests = requests
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("tonConnectPending", [("session", ConstructorParameterDescription(self.session)), ("requests", ConstructorParameterDescription(self.requests))])
            }
        }
        case tonConnectPending(Cons_tonConnectPending)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .tonConnectPending(let _data):
                if boxed {
                    buffer.appendInt32(-2050952924)
                }
                _data.session.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.requests.count))
                for item in _data.requests {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .tonConnectPending(let _data):
                return ("tonConnectPending", [("session", ConstructorParameterDescription(_data.session)), ("requests", ConstructorParameterDescription(_data.requests))])
            }
        }

        public static func parse_tonConnectPending(_ reader: BufferReader) -> TonConnectPending? {
            var _1: Api.TonConnectSession?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.TonConnectSession
            }
            var _2: [Api.TonConnectRequest]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.TonConnectRequest.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.wallet.TonConnectPending.tonConnectPending(Cons_tonConnectPending(session: _1!, requests: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.wallet {
    enum TonConnectSessions: TypeConstructorDescription {
        public class Cons_tonConnectSessions: TypeConstructorDescription {
            public var sessions: [Api.TonConnectSession]
            public init(sessions: [Api.TonConnectSession]) {
                self.sessions = sessions
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("tonConnectSessions", [("sessions", ConstructorParameterDescription(self.sessions))])
            }
        }
        case tonConnectSessions(Cons_tonConnectSessions)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .tonConnectSessions(let _data):
                if boxed {
                    buffer.appendInt32(236939414)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.sessions.count))
                for item in _data.sessions {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .tonConnectSessions(let _data):
                return ("tonConnectSessions", [("sessions", ConstructorParameterDescription(_data.sessions))])
            }
        }

        public static func parse_tonConnectSessions(_ reader: BufferReader) -> TonConnectSessions? {
            var _1: [Api.TonConnectSession]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.TonConnectSession.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.wallet.TonConnectSessions.tonConnectSessions(Cons_tonConnectSessions(sessions: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.wallet {
    enum Transactions: TypeConstructorDescription {
        public class Cons_transactions: TypeConstructorDescription {
            public var flags: Int32
            public var balance: Int64
            public var transactions: [Api.WalletTransaction]
            public var nextOffset: String?
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, balance: Int64, transactions: [Api.WalletTransaction], nextOffset: String?, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.balance = balance
                self.transactions = transactions
                self.nextOffset = nextOffset
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("transactions", [("flags", ConstructorParameterDescription(self.flags)), ("balance", ConstructorParameterDescription(self.balance)), ("transactions", ConstructorParameterDescription(self.transactions)), ("nextOffset", ConstructorParameterDescription(self.nextOffset)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case transactions(Cons_transactions)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .transactions(let _data):
                if boxed {
                    buffer.appendInt32(1126356389)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.balance, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.transactions.count))
                for item in _data.transactions {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.nextOffset!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .transactions(let _data):
                return ("transactions", [("flags", ConstructorParameterDescription(_data.flags)), ("balance", ConstructorParameterDescription(_data.balance)), ("transactions", ConstructorParameterDescription(_data.transactions)), ("nextOffset", ConstructorParameterDescription(_data.nextOffset)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_transactions(_ reader: BufferReader) -> Transactions? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [Api.WalletTransaction]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.WalletTransaction.self)
            }
            var _4: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.wallet.Transactions.transactions(Cons_transactions(flags: _1!, balance: _2!, transactions: _3!, nextOffset: _4, chats: _5!, users: _6!))
            }
            else {
                return nil
            }
        }
    }
}
