public extension Api.wallet {
    enum GaslessInfo: TypeConstructorDescription {
        public class Cons_gaslessInfo: TypeConstructorDescription {
            public var flags: Int32
            public var left: Int32
            public var resetAt: Int32
            public var minAmount: Int64
            public var relayerAddress: String
            public init(flags: Int32, left: Int32, resetAt: Int32, minAmount: Int64, relayerAddress: String) {
                self.flags = flags
                self.left = left
                self.resetAt = resetAt
                self.minAmount = minAmount
                self.relayerAddress = relayerAddress
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("gaslessInfo", [("flags", ConstructorParameterDescription(self.flags)), ("left", ConstructorParameterDescription(self.left)), ("resetAt", ConstructorParameterDescription(self.resetAt)), ("minAmount", ConstructorParameterDescription(self.minAmount)), ("relayerAddress", ConstructorParameterDescription(self.relayerAddress))])
            }
        }
        case gaslessInfo(Cons_gaslessInfo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .gaslessInfo(let _data):
                if boxed {
                    buffer.appendInt32(-459792708)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.left, buffer: buffer, boxed: false)
                serializeInt32(_data.resetAt, buffer: buffer, boxed: false)
                serializeInt64(_data.minAmount, buffer: buffer, boxed: false)
                serializeString(_data.relayerAddress, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .gaslessInfo(let _data):
                return ("gaslessInfo", [("flags", ConstructorParameterDescription(_data.flags)), ("left", ConstructorParameterDescription(_data.left)), ("resetAt", ConstructorParameterDescription(_data.resetAt)), ("minAmount", ConstructorParameterDescription(_data.minAmount)), ("relayerAddress", ConstructorParameterDescription(_data.relayerAddress))])
            }
        }

        public static func parse_gaslessInfo(_ reader: BufferReader) -> GaslessInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: String?
            _5 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.wallet.GaslessInfo.gaslessInfo(Cons_gaslessInfo(flags: _1!, left: _2!, resetAt: _3!, minAmount: _4!, relayerAddress: _5!))
            }
            else {
                return nil
            }
        }
    }
}
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
    enum SentTransfer: TypeConstructorDescription {
        public class Cons_sentTransfer: TypeConstructorDescription {
            public var flags: Int32
            public var msgHash: String
            public var gaslessLeft: Int32
            public var gaslessResetAt: Int32
            public init(flags: Int32, msgHash: String, gaslessLeft: Int32, gaslessResetAt: Int32) {
                self.flags = flags
                self.msgHash = msgHash
                self.gaslessLeft = gaslessLeft
                self.gaslessResetAt = gaslessResetAt
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sentTransfer", [("flags", ConstructorParameterDescription(self.flags)), ("msgHash", ConstructorParameterDescription(self.msgHash)), ("gaslessLeft", ConstructorParameterDescription(self.gaslessLeft)), ("gaslessResetAt", ConstructorParameterDescription(self.gaslessResetAt))])
            }
        }
        case sentTransfer(Cons_sentTransfer)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .sentTransfer(let _data):
                if boxed {
                    buffer.appendInt32(1882463590)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.msgHash, buffer: buffer, boxed: false)
                serializeInt32(_data.gaslessLeft, buffer: buffer, boxed: false)
                serializeInt32(_data.gaslessResetAt, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .sentTransfer(let _data):
                return ("sentTransfer", [("flags", ConstructorParameterDescription(_data.flags)), ("msgHash", ConstructorParameterDescription(_data.msgHash)), ("gaslessLeft", ConstructorParameterDescription(_data.gaslessLeft)), ("gaslessResetAt", ConstructorParameterDescription(_data.gaslessResetAt))])
            }
        }

        public static func parse_sentTransfer(_ reader: BufferReader) -> SentTransfer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.wallet.SentTransfer.sentTransfer(Cons_sentTransfer(flags: _1!, msgHash: _2!, gaslessLeft: _3!, gaslessResetAt: _4!))
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
