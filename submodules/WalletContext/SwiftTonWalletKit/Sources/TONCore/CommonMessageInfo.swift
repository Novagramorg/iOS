import Foundation

/// `CommonMsgInfo`: the header of a fully-specified message.
///
/// The three variants are distinguished by a 1- or 2-bit tag: `0` internal,
/// `10` external-in, `11` external-out.
public enum CommonMessageInfo: Hashable, Sendable {
    case internalMessage(InternalInfo)
    case externalIn(ExternalInInfo)
    case externalOut(ExternalOutInfo)

    public struct InternalInfo: Hashable, Sendable {
        public var ihrDisabled: Bool
        public var bounce: Bool
        public var bounced: Bool
        public var src: Address
        public var dest: Address
        public var value: CurrencyCollection
        public var ihrFee: BigUInt
        public var forwardFee: BigUInt
        public var createdLt: UInt64
        public var createdAt: UInt32

        public init(
            ihrDisabled: Bool = true,
            bounce: Bool,
            bounced: Bool = false,
            src: Address,
            dest: Address,
            value: CurrencyCollection,
            ihrFee: BigUInt = 0,
            forwardFee: BigUInt = 0,
            createdLt: UInt64 = 0,
            createdAt: UInt32 = 0
        ) {
            self.ihrDisabled = ihrDisabled
            self.bounce = bounce
            self.bounced = bounced
            self.src = src
            self.dest = dest
            self.value = value
            self.ihrFee = ihrFee
            self.forwardFee = forwardFee
            self.createdLt = createdLt
            self.createdAt = createdAt
        }
    }

    public struct ExternalInInfo: Hashable, Sendable {
        /// External source address, or nil for `addr_none`.
        public var src: ExternalAddress?
        public var dest: Address
        public var importFee: BigUInt

        public init(src: ExternalAddress? = nil, dest: Address, importFee: BigUInt = 0) {
            self.src = src
            self.dest = dest
            self.importFee = importFee
        }
    }

    public struct ExternalOutInfo: Hashable, Sendable {
        public var src: Address
        public var dest: ExternalAddress?
        public var createdLt: UInt64
        public var createdAt: UInt32

        public init(src: Address, dest: ExternalAddress? = nil, createdLt: UInt64 = 0, createdAt: UInt32 = 0) {
            self.src = src
            self.dest = dest
            self.createdLt = createdLt
            self.createdAt = createdAt
        }
    }

    public func store(into builder: Builder) throws {
        switch self {
        case .internalMessage(let info):
            try builder.storeBit(false)
            try builder.storeBit(info.ihrDisabled)
            try builder.storeBit(info.bounce)
            try builder.storeBit(info.bounced)
            try builder.storeAddress(info.src)
            try builder.storeAddress(info.dest)
            try info.value.store(into: builder)
            try builder.storeCoins(info.ihrFee)
            try builder.storeCoins(info.forwardFee)
            try builder.storeUInt(info.createdLt, bits: 64)
            try builder.storeUInt(UInt64(info.createdAt), bits: 32)
        case .externalIn(let info):
            try builder.storeBit(true)
            try builder.storeBit(false)
            try builder.storeExternalAddress(info.src)
            try builder.storeAddress(info.dest)
            try builder.storeCoins(info.importFee)
        case .externalOut(let info):
            try builder.storeBit(true)
            try builder.storeBit(true)
            try builder.storeAddress(info.src)
            try builder.storeExternalAddress(info.dest)
            try builder.storeUInt(info.createdLt, bits: 64)
            try builder.storeUInt(UInt64(info.createdAt), bits: 32)
        }
    }

    public static func load(from slice: inout Slice) throws -> CommonMessageInfo {
        if try slice.loadBit() == false {
            let ihrDisabled = try slice.loadBit()
            let bounce = try slice.loadBit()
            let bounced = try slice.loadBit()
            let src = try slice.loadAddress()
            let dest = try slice.loadAddress()
            let value = try CurrencyCollection.load(from: &slice)
            let ihrFee = try slice.loadCoins()
            let forwardFee = try slice.loadCoins()
            let createdLt = try slice.loadUInt(64)
            let createdAt = UInt32(try slice.loadUInt(32))
            return .internalMessage(
                InternalInfo(
                    ihrDisabled: ihrDisabled,
                    bounce: bounce,
                    bounced: bounced,
                    src: src,
                    dest: dest,
                    value: value,
                    ihrFee: ihrFee,
                    forwardFee: forwardFee,
                    createdLt: createdLt,
                    createdAt: createdAt
                )
            )
        }

        if try slice.loadBit() == false {
            let src = try slice.loadMaybeExternalAddress()
            let dest = try slice.loadAddress()
            let importFee = try slice.loadCoins()
            return .externalIn(ExternalInInfo(src: src, dest: dest, importFee: importFee))
        }

        let src = try slice.loadAddress()
        let dest = try slice.loadMaybeExternalAddress()
        let createdLt = try slice.loadUInt(64)
        let createdAt = UInt32(try slice.loadUInt(32))
        return .externalOut(
            ExternalOutInfo(src: src, dest: dest, createdLt: createdLt, createdAt: createdAt)
        )
    }
}

/// `CommonMsgInfoRelaxed`: as above, but the source may be `addr_none` and
/// external-in is not representable.
///
/// This is what an outgoing action list carries — the wallet contract fills in the
/// source when it sends.
public enum CommonMessageInfoRelaxed: Hashable, Sendable {
    case internalMessage(InternalInfo)
    case externalOut(ExternalOutInfo)

    public struct InternalInfo: Hashable, Sendable {
        public var ihrDisabled: Bool
        public var bounce: Bool
        public var bounced: Bool
        /// nil serializes as `addr_none`.
        public var src: Address?
        public var dest: Address
        public var value: CurrencyCollection
        public var ihrFee: BigUInt
        public var forwardFee: BigUInt
        public var createdLt: UInt64
        public var createdAt: UInt32

        public init(
            ihrDisabled: Bool = true,
            bounce: Bool,
            bounced: Bool = false,
            src: Address? = nil,
            dest: Address,
            value: CurrencyCollection,
            ihrFee: BigUInt = 0,
            forwardFee: BigUInt = 0,
            createdLt: UInt64 = 0,
            createdAt: UInt32 = 0
        ) {
            self.ihrDisabled = ihrDisabled
            self.bounce = bounce
            self.bounced = bounced
            self.src = src
            self.dest = dest
            self.value = value
            self.ihrFee = ihrFee
            self.forwardFee = forwardFee
            self.createdLt = createdLt
            self.createdAt = createdAt
        }
    }

    public struct ExternalOutInfo: Hashable, Sendable {
        public var src: Address?
        public var dest: ExternalAddress?
        public var createdLt: UInt64
        public var createdAt: UInt32

        public init(src: Address? = nil, dest: ExternalAddress? = nil, createdLt: UInt64 = 0, createdAt: UInt32 = 0) {
            self.src = src
            self.dest = dest
            self.createdLt = createdLt
            self.createdAt = createdAt
        }
    }

    public enum RelaxedError: Error, CustomStringConvertible {
        case externalInNotRepresentable
        public var description: String {
            "External-in messages cannot appear in CommonMsgInfoRelaxed"
        }
    }

    public func store(into builder: Builder) throws {
        switch self {
        case .internalMessage(let info):
            try builder.storeBit(false)
            try builder.storeBit(info.ihrDisabled)
            try builder.storeBit(info.bounce)
            try builder.storeBit(info.bounced)
            try builder.storeAddress(info.src)
            try builder.storeAddress(info.dest)
            try info.value.store(into: builder)
            try builder.storeCoins(info.ihrFee)
            try builder.storeCoins(info.forwardFee)
            try builder.storeUInt(info.createdLt, bits: 64)
            try builder.storeUInt(UInt64(info.createdAt), bits: 32)
        case .externalOut(let info):
            try builder.storeBit(true)
            try builder.storeBit(true)
            try builder.storeAddress(info.src)
            try builder.storeExternalAddress(info.dest)
            try builder.storeUInt(info.createdLt, bits: 64)
            try builder.storeUInt(UInt64(info.createdAt), bits: 32)
        }
    }

    public static func load(from slice: inout Slice) throws -> CommonMessageInfoRelaxed {
        if try slice.loadBit() == false {
            let ihrDisabled = try slice.loadBit()
            let bounce = try slice.loadBit()
            let bounced = try slice.loadBit()
            let src = try slice.loadMaybeAddress()
            let dest = try slice.loadAddress()
            let value = try CurrencyCollection.load(from: &slice)
            let ihrFee = try slice.loadCoins()
            let forwardFee = try slice.loadCoins()
            let createdLt = try slice.loadUInt(64)
            let createdAt = UInt32(try slice.loadUInt(32))
            return .internalMessage(
                InternalInfo(
                    ihrDisabled: ihrDisabled,
                    bounce: bounce,
                    bounced: bounced,
                    src: src,
                    dest: dest,
                    value: value,
                    ihrFee: ihrFee,
                    forwardFee: forwardFee,
                    createdLt: createdLt,
                    createdAt: createdAt
                )
            )
        }

        guard try slice.loadBit() else { throw RelaxedError.externalInNotRepresentable }

        let src = try slice.loadMaybeAddress()
        let dest = try slice.loadMaybeExternalAddress()
        let createdLt = try slice.loadUInt(64)
        let createdAt = UInt32(try slice.loadUInt(32))
        return .externalOut(
            ExternalOutInfo(src: src, dest: dest, createdLt: createdLt, createdAt: createdAt)
        )
    }
}
