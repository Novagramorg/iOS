import Foundation

/// `message$_ info:CommonMsgInfo init:(Maybe (Either StateInit ^StateInit))
///  body:(Either X ^X)`
///
/// The `Either` fields let the state init and body sit inline or behind a ref
/// depending on space. Which one gets chosen changes the cell hash, so the
/// space-accounting rules below are reproduced exactly from the reference.
public struct Message: Hashable, Sendable {
    public var info: CommonMessageInfo
    public var stateInit: StateInit?
    public var body: Cell

    public init(info: CommonMessageInfo, stateInit: StateInit? = nil, body: Cell = Cell.empty) {
        self.info = info
        self.stateInit = stateInit
        self.body = body
    }

    /// Serializes into `builder`.
    ///
    /// `forceRef` pushes both the state init and the body behind references
    /// regardless of available space — required by TEP-467 normalized hashing.
    public func store(into builder: Builder, forceRef: Bool = false) throws {
        try info.store(into: builder)

        if let stateInit {
            try builder.storeBit(true)
            let initCell = try stateInit.toCell()
            // Reference rule for full messages: the *combined* size of the state init
            // and the body has to fit, not just the state init.
            let needRef = forceRef
                || (builder.availableBits - 2) < (initCell.bits.length + body.bits.length)
            if needRef {
                try builder.storeBit(true)
                try builder.storeRef(initCell)
            } else {
                try builder.storeBit(false)
                try builder.storeCellInline(initCell)
            }
        } else {
            try builder.storeBit(false)
        }

        let bodyNeedsRef = forceRef
            || (builder.availableBits - 1) < body.bits.length
            || (builder.refCount + body.refs.count) > Cell.maxRefs
        if bodyNeedsRef {
            try builder.storeBit(true)
            try builder.storeRef(body)
        } else {
            try builder.storeBit(false)
            try builder.storeCellInline(body)
        }
    }

    public func toCell(forceRef: Bool = false) throws -> Cell {
        let builder = Builder()
        try store(into: builder, forceRef: forceRef)
        return try builder.endCell()
    }

    public static func load(from slice: inout Slice) throws -> Message {
        let info = try CommonMessageInfo.load(from: &slice)

        var stateInit: StateInit?
        if try slice.loadBit() {
            if try slice.loadBit() == false {
                stateInit = try StateInit.load(from: &slice)
            } else {
                var refSlice = try slice.loadRef().beginParse()
                stateInit = try StateInit.load(from: &refSlice)
            }
        }

        let body = try slice.loadBit() ? try slice.loadRef() : try slice.asCell()
        return Message(info: info, stateInit: stateInit, body: body)
    }

    public static func fromCell(_ cell: Cell) throws -> Message {
        var slice = cell.beginParse()
        return try load(from: &slice)
    }
}

/// A message whose source may be omitted — what an outgoing action list carries.
public struct MessageRelaxed: Hashable, Sendable {
    public var info: CommonMessageInfoRelaxed
    public var stateInit: StateInit?
    public var body: Cell

    public init(info: CommonMessageInfoRelaxed, stateInit: StateInit? = nil, body: Cell = Cell.empty) {
        self.info = info
        self.stateInit = stateInit
        self.body = body
    }

    public func store(into builder: Builder, forceRef: Bool = false) throws {
        try info.store(into: builder)

        if let stateInit {
            try builder.storeBit(true)
            let initCell = try stateInit.toCell()
            // Note the rule differs from `Message`: the relaxed form checks the state
            // init alone, not the state init plus the body. Reproduced deliberately —
            // aligning the two would change cell hashes.
            let needRef = forceRef || (builder.availableBits - 2) < initCell.bits.length
            if needRef {
                try builder.storeBit(true)
                try builder.storeRef(initCell)
            } else {
                try builder.storeBit(false)
                try builder.storeCellInline(initCell)
            }
        } else {
            try builder.storeBit(false)
        }

        // The relaxed form additionally refuses to inline an exotic body.
        let bodyFits = (builder.availableBits - 1) >= body.bits.length
            && (builder.refCount + body.refs.count) <= Cell.maxRefs
            && !body.isExotic
        let bodyNeedsRef = forceRef || !bodyFits
        if bodyNeedsRef {
            try builder.storeBit(true)
            try builder.storeRef(body)
        } else {
            try builder.storeBit(false)
            try builder.storeCellInline(body)
        }
    }

    public func toCell(forceRef: Bool = false) throws -> Cell {
        let builder = Builder()
        try store(into: builder, forceRef: forceRef)
        return try builder.endCell()
    }

    public static func load(from slice: inout Slice) throws -> MessageRelaxed {
        let info = try CommonMessageInfoRelaxed.load(from: &slice)

        var stateInit: StateInit?
        if try slice.loadBit() {
            if try slice.loadBit() == false {
                stateInit = try StateInit.load(from: &slice)
            } else {
                var refSlice = try slice.loadRef().beginParse()
                stateInit = try StateInit.load(from: &refSlice)
            }
        }

        let body = try slice.loadBit() ? try slice.loadRef() : try slice.asCell()
        return MessageRelaxed(info: info, stateInit: stateInit, body: body)
    }

    public static func fromCell(_ cell: Cell) throws -> MessageRelaxed {
        var slice = cell.beginParse()
        return try load(from: &slice)
    }
}

// MARK: - Convenience constructors

extension MessageRelaxed {
    /// Builds an internal outgoing message, mirroring `@ton/core`'s `internal()`.
    ///
    /// `bounce` defaults to true, matching the ecosystem default for transfers to
    /// bounceable addresses.
    public static func makeInternal(
        to: Address,
        value: BigUInt,
        bounce: Bool = true,
        stateInit: StateInit? = nil,
        body: Cell = Cell.empty,
        extraCurrencies: [UInt32: BigUInt] = [:]
    ) -> MessageRelaxed {
        MessageRelaxed(
            info: .internalMessage(
                .init(
                    bounce: bounce,
                    dest: to,
                    value: CurrencyCollection(coins: value, other: extraCurrencies)
                )
            ),
            stateInit: stateInit,
            body: body
        )
    }
}

extension Message {
    /// Builds an inbound external message, mirroring `@ton/core`'s `external()`.
    public static func makeExternalIn(
        to: Address,
        stateInit: StateInit? = nil,
        body: Cell = Cell.empty,
        importFee: BigUInt = 0
    ) -> Message {
        Message(
            info: .externalIn(.init(src: nil, dest: to, importFee: importFee)),
            stateInit: stateInit,
            body: body
        )
    }
}
