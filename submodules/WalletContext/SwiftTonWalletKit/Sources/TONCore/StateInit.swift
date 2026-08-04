import Foundation

/// `tick_tock$_ tick:Bool tock:Bool`
public struct TickTock: Hashable, Sendable {
    public var tick: Bool
    public var tock: Bool

    public init(tick: Bool, tock: Bool) {
        self.tick = tick
        self.tock = tock
    }
}

/// A contract's initial state: code, data, and optional split/special/library fields.
///
/// Hashing this determines the contract address, so its bit layout is
/// address-critical.
public struct StateInit: Hashable, Sendable {
    public var splitDepth: UInt8?
    public var special: TickTock?
    public var code: Cell?
    public var data: Cell?
    public var libraries: [BigUInt: SimpleLibrary]

    public init(
        code: Cell? = nil,
        data: Cell? = nil,
        splitDepth: UInt8? = nil,
        special: TickTock? = nil,
        libraries: [BigUInt: SimpleLibrary] = [:]
    ) {
        self.code = code
        self.data = data
        self.splitDepth = splitDepth
        self.special = special
        self.libraries = libraries
    }

    public func store(into builder: Builder) throws {
        if let splitDepth {
            try builder.storeBit(true)
            try builder.storeUInt(UInt64(splitDepth), bits: 5)
        } else {
            try builder.storeBit(false)
        }

        if let special {
            try builder.storeBit(true)
            try builder.storeBit(special.tick)
            try builder.storeBit(special.tock)
        } else {
            try builder.storeBit(false)
        }

        try builder.storeMaybeRef(code)
        try builder.storeMaybeRef(data)

        if libraries.isEmpty {
            try builder.storeBit(false)
        } else {
            var dict = TONDictionary(key: BigUIntKey(bits: 256), value: SimpleLibraryValue())
            for (key, lib) in libraries { try dict.set(key, lib) }
            try dict.store(into: builder)
        }
    }

    public static func load(from slice: inout Slice) throws -> StateInit {
        var splitDepth: UInt8?
        if try slice.loadBit() {
            splitDepth = UInt8(try slice.loadUInt(5))
        }

        var special: TickTock?
        if try slice.loadBit() {
            let tick = try slice.loadBit()
            let tock = try slice.loadBit()
            special = TickTock(tick: tick, tock: tock)
        }

        let code = try slice.loadMaybeRef()
        let data = try slice.loadMaybeRef()

        let dict = try TONDictionary.load(
            key: BigUIntKey(bits: 256),
            value: SimpleLibraryValue(),
            from: &slice
        )
        var libraries: [BigUInt: SimpleLibrary] = [:]
        for key in dict.rawKeys {
            if let lib = try dict.get(key) { libraries[key] = lib }
        }

        return StateInit(
            code: code,
            data: data,
            splitDepth: splitDepth,
            special: special,
            libraries: libraries
        )
    }

    /// Serializes to a standalone cell.
    public func toCell() throws -> Cell {
        let builder = Builder()
        try store(into: builder)
        return try builder.endCell()
    }
}

/// `simple_lib$_ public:Bool root:^Cell`
public struct SimpleLibrary: Hashable, Sendable {
    public var isPublic: Bool
    public var root: Cell

    public init(isPublic: Bool, root: Cell) {
        self.isPublic = isPublic
        self.root = root
    }
}

public struct SimpleLibraryValue: DictionaryValueCoder {
    public typealias Value = SimpleLibrary
    public init() {}

    public func store(_ value: SimpleLibrary, into builder: Builder) throws {
        try builder.storeBit(value.isPublic)
        try builder.storeRef(value.root)
    }

    public func load(from slice: inout Slice) throws -> SimpleLibrary {
        let isPublic = try slice.loadBit()
        let root = try slice.loadRef()
        return SimpleLibrary(isPublic: isPublic, root: root)
    }
}

/// Derives a contract address: the workchain plus the hash of its state init.
public func contractAddress(workchain: Int8, init stateInit: StateInit) throws -> Address {
    Address(workchain: workchain, hash: try stateInit.toCell().hash())
}
