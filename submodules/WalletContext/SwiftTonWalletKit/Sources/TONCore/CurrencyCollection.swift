import Foundation

/// `currencies$_ grams:Grams other:ExtraCurrencyCollection`
///
/// The nanoton amount plus an optional dictionary of extra currencies keyed by
/// 32-bit currency id.
public struct CurrencyCollection: Hashable, Sendable {
    public var coins: BigUInt
    /// Extra currencies by id. Empty means the `other` dictionary is absent.
    public var other: [UInt32: BigUInt]

    public init(coins: BigUInt, other: [UInt32: BigUInt] = [:]) {
        self.coins = coins
        self.other = other
    }

    public func store(into builder: Builder) throws {
        try builder.storeCoins(coins)
        guard !other.isEmpty else {
            try builder.storeBit(false)
            return
        }
        var dict = TONDictionary(key: UIntKey(bits: 32), value: BigVarUIntValue(lengthBits: 5))
        for (id, amount) in other {
            try dict.set(UInt64(id), amount)
        }
        try dict.store(into: builder)
    }

    public static func load(from slice: inout Slice) throws -> CurrencyCollection {
        let coins = try slice.loadCoins()
        let dict = try TONDictionary.load(
            key: UIntKey(bits: 32),
            value: BigVarUIntValue(lengthBits: 5),
            from: &slice
        )
        var other: [UInt32: BigUInt] = [:]
        for raw in dict.rawKeys {
            let id = UInt32(raw)
            if let value = try dict.get(UInt64(id)) { other[id] = value }
        }
        return CurrencyCollection(coins: coins, other: other)
    }
}

/// `VarUInteger` values with a configurable length-prefix width.
///
/// Extra currencies use `BigVarUint(5)` — a 5-bit byte-count prefix, since amounts are
/// bounded by 32 bytes.
public struct BigVarUIntValue: DictionaryValueCoder {
    public typealias Value = BigUInt
    public let lengthBits: Int

    public init(lengthBits: Int) {
        self.lengthBits = lengthBits
    }

    public func store(_ value: BigUInt, into builder: Builder) throws {
        try builder.storeVarUInt(value, lengthBits: lengthBits)
    }

    public func load(from slice: inout Slice) throws -> BigUInt {
        try slice.loadVarUInt(lengthBits: lengthBits)
    }
}
