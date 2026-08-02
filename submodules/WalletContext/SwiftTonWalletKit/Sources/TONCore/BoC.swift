import Foundation

/// Bag-of-Cells serialization.
///
/// Three container formats exist in the wild and all three appear in real Toncenter
/// responses, so all three are parsed. Only the modern `b5ee9c72` form is written.
public enum BoC {
    /// Modern format, with flags for index and CRC-32C.
    static let magicGeneric: UInt32 = 0xb5ee_9c72
    /// Legacy indexed format.
    static let magicIndexed: UInt32 = 0x68ff_65f3
    /// Legacy indexed format with a CRC-32C trailer.
    static let magicIndexedCrc32: UInt32 = 0xacc3_a728

    public enum BoCError: Error, CustomStringConvertible {
        case invalidMagic(UInt32)
        case crcMismatch(expected: UInt32, actual: UInt32)
        case truncated
        case noRoots
        case rootIndexOutOfRange(Int, cellCount: Int)
        case refIndexOutOfRange(Int, cellCount: Int)
        case forwardReference(from: Int, to: Int)
        case tooManyCells(Int)

        public var description: String {
            switch self {
            case .invalidMagic(let m): return String(format: "Invalid BoC magic 0x%08X", m)
            case .crcMismatch(let e, let a):
                return String(format: "BoC CRC-32C mismatch: expected %08X, got %08X", e, a)
            case .truncated: return "BoC data is truncated"
            case .noRoots: return "BoC declares no roots"
            case .rootIndexOutOfRange(let i, let n): return "BoC root index \(i) exceeds cell count \(n)"
            case .refIndexOutOfRange(let i, let n): return "BoC ref index \(i) exceeds cell count \(n)"
            case .forwardReference(let from, let to):
                return "BoC cell \(from) references \(to), which is not yet resolved"
            case .tooManyCells(let n): return "BoC declares \(n) cells, which exceeds the sane limit"
            }
        }
    }

    /// Upper bound on declared cell count, so a malformed header cannot make us
    /// attempt a huge allocation.
    private static let maxCells = 1_000_000

    // MARK: - Deserialization

    /// Parses a BoC and returns its root cells.
    public static func deserialize(_ data: Data) throws -> [Cell] {
        var reader = BitReader(BitString(data))

        let magic = UInt32(try reader.loadUInt(32))
        let header: Header
        switch magic {
        case magicGeneric:
            header = try readGenericHeader(&reader)
        case magicIndexed:
            header = try readIndexedHeader(&reader, hasCrc: false)
        case magicIndexedCrc32:
            header = try readIndexedHeader(&reader, hasCrc: true)
        default:
            throw BoCError.invalidMagic(magic)
        }

        if header.hasCrc32c {
            guard data.count >= 4 else { throw BoCError.truncated }
            let body = data.prefix(data.count - 4)
            let trailer = data.suffix(4)
            var expected: UInt32 = 0
            // The trailer is little-endian.
            for (i, byte) in trailer.enumerated() { expected |= UInt32(byte) << (8 * UInt32(i)) }
            let actual = CRC.crc32c(Data(body))
            guard expected == actual else {
                throw BoCError.crcMismatch(expected: expected, actual: actual)
            }
        }

        // Read the flat cell table.
        var cellReader = BitReader(BitString(header.cellData))
        var raw: [(bits: BitString, refs: [Int], exotic: Bool)] = []
        raw.reserveCapacity(header.cellCount)
        for _ in 0..<header.cellCount {
            raw.append(try readCell(&cellReader, sizeBytes: header.sizeBytes))
        }

        // Resolve back to front: BoC ordering guarantees refs point forward, so by the
        // time we reach cell i every cell it references is already built.
        var resolved = [Cell?](repeating: nil, count: raw.count)
        for i in stride(from: raw.count - 1, through: 0, by: -1) {
            var refs: [Cell] = []
            refs.reserveCapacity(raw[i].refs.count)
            for r in raw[i].refs {
                guard r >= 0 && r < raw.count else {
                    throw BoCError.refIndexOutOfRange(r, cellCount: raw.count)
                }
                guard let child = resolved[r] else { throw BoCError.forwardReference(from: i, to: r) }
                refs.append(child)
            }
            resolved[i] = try Cell(bits: raw[i].bits, refs: refs, exotic: raw[i].exotic)
        }

        guard !header.rootIndices.isEmpty else { throw BoCError.noRoots }
        return try header.rootIndices.map { index in
            guard index >= 0 && index < resolved.count, let cell = resolved[index] else {
                throw BoCError.rootIndexOutOfRange(index, cellCount: resolved.count)
            }
            return cell
        }
    }

    /// Convenience for the common single-root case.
    public static func deserializeSingleRoot(_ data: Data) throws -> Cell {
        let roots = try deserialize(data)
        guard let first = roots.first else { throw BoCError.noRoots }
        return first
    }

    private struct Header {
        let sizeBytes: Int
        let cellCount: Int
        let rootIndices: [Int]
        let cellData: Data
        let hasCrc32c: Bool
    }

    private static func readGenericHeader(_ reader: inout BitReader) throws -> Header {
        let hasIdx = try reader.loadBit()
        let hasCrc32c = try reader.loadBit()
        _ = try reader.loadBit() // has_cache_bits
        _ = try reader.loadUInt(2) // flags, must be 0
        let sizeBytes = Int(try reader.loadUInt(3))
        let offsetBytes = Int(try reader.loadUInt(8))

        let cellCount = Int(try reader.loadUInt(sizeBytes * 8))
        guard cellCount <= maxCells else { throw BoCError.tooManyCells(cellCount) }
        let rootCount = Int(try reader.loadUInt(sizeBytes * 8))
        _ = try reader.loadUInt(sizeBytes * 8) // absent
        let totalCellSize = Int(try reader.loadUInt(offsetBytes * 8))

        var rootIndices: [Int] = []
        for _ in 0..<rootCount { rootIndices.append(Int(try reader.loadUInt(sizeBytes * 8))) }

        if hasIdx { _ = try reader.loadBytes(cellCount * offsetBytes) }
        let cellData = try reader.loadBytes(totalCellSize)

        return Header(
            sizeBytes: sizeBytes,
            cellCount: cellCount,
            rootIndices: rootIndices,
            cellData: cellData,
            hasCrc32c: hasCrc32c
        )
    }

    private static func readIndexedHeader(_ reader: inout BitReader, hasCrc: Bool) throws -> Header {
        let sizeBytes = Int(try reader.loadUInt(8))
        let offsetBytes = Int(try reader.loadUInt(8))
        let cellCount = Int(try reader.loadUInt(sizeBytes * 8))
        guard cellCount <= maxCells else { throw BoCError.tooManyCells(cellCount) }
        _ = try reader.loadUInt(sizeBytes * 8) // roots, always 1
        _ = try reader.loadUInt(sizeBytes * 8) // absent
        let totalCellSize = Int(try reader.loadUInt(offsetBytes * 8))

        _ = try reader.loadBytes(cellCount * offsetBytes) // index, always present here
        let cellData = try reader.loadBytes(totalCellSize)

        return Header(
            sizeBytes: sizeBytes,
            cellCount: cellCount,
            rootIndices: [0],
            cellData: cellData,
            hasCrc32c: hasCrc
        )
    }

    private static func readCell(
        _ reader: inout BitReader,
        sizeBytes: Int
    ) throws -> (bits: BitString, refs: [Int], exotic: Bool) {
        let d1 = try reader.loadUInt(8)
        let refCount = Int(d1 % 8)
        let exotic = (d1 & 8) != 0
        let hasHashes = (d1 & 16) != 0
        let levelMask = UInt32(d1 >> 5)

        let d2 = try reader.loadUInt(8)
        let dataByteSize = Int((d2 + 1) / 2)
        let paddingAdded = d2 % 2 != 0

        // Cells may carry precomputed hashes and depths; we recompute, so skip them.
        if hasHashes {
            let count = hashesCount(levelMask: levelMask)
            try reader.skip(count * 32 * 8)
            try reader.skip(count * 2 * 8)
        }

        var bits = BitString.empty
        if dataByteSize > 0 {
            bits = paddingAdded
                ? try reader.loadPaddedBits(dataByteSize * 8)
                : try reader.loadBits(dataByteSize * 8)
        }

        var refs: [Int] = []
        refs.reserveCapacity(refCount)
        for _ in 0..<refCount { refs.append(Int(try reader.loadUInt(sizeBytes * 8))) }

        return (bits, refs, exotic)
    }

    /// One representation hash plus one per significant higher level.
    private static func hashesCount(levelMask: UInt32) -> Int {
        var mask = levelMask & 7
        var n = 0
        for _ in 0..<3 {
            n += Int(mask & 1)
            mask >>= 1
        }
        return n + 1
    }

    // MARK: - Serialization

    /// Serializes a cell tree in the modern `b5ee9c72` format.
    ///
    /// Defaults match `@ton/core`'s `toBoc()`: no index, CRC-32C present.
    public static func serialize(root: Cell, idx: Bool = false, crc32: Bool = true) -> Data {
        let sorted = topologicalSort(root)
        let cellCount = sorted.count

        let sizeBytes = max(byteWidth(for: UInt64(cellCount)), 1)

        var totalCellSize = 0
        var index: [Int] = []
        index.reserveCapacity(cellCount)
        for entry in sorted {
            totalCellSize += cellSize(entry.cell, sizeBytes: sizeBytes)
            index.append(totalCellSize)
        }
        let offsetBytes = max(byteWidth(for: UInt64(totalCellSize)), 1)

        var builder = BitBuilder(capacity: (32 + 8 + 8 + 3 * sizeBytes * 8 + offsetBytes * 8
            + sizeBytes * 8 + (idx ? cellCount * offsetBytes * 8 : 0)
            + totalCellSize * 8 + (crc32 ? 32 : 0)))

        builder.write(uint: UInt64(magicGeneric), bits: 32)
        builder.write(bit: idx)
        builder.write(bit: crc32)
        builder.write(bit: false) // has_cache_bits
        builder.write(uint: 0, bits: 2) // flags
        builder.write(uint: UInt64(sizeBytes), bits: 3)
        builder.write(uint: UInt64(offsetBytes), bits: 8)
        builder.write(uint: UInt64(cellCount), bits: sizeBytes * 8)
        builder.write(uint: 1, bits: sizeBytes * 8) // root count
        builder.write(uint: 0, bits: sizeBytes * 8) // absent
        builder.write(uint: UInt64(totalCellSize), bits: offsetBytes * 8)
        builder.write(uint: 0, bits: sizeBytes * 8) // root index

        if idx {
            for value in index { builder.write(uint: UInt64(value), bits: offsetBytes * 8) }
        }

        for entry in sorted {
            writeCell(entry.cell, refs: entry.refs, sizeBytes: sizeBytes, into: &builder)
        }

        var out = builder.build().toData()
        if crc32 {
            let checksum = CRC.crc32c(out)
            // Trailer is little-endian.
            for shift in stride(from: 0, to: 32, by: 8) {
                out.append(UInt8((checksum >> UInt32(shift)) & 0xff))
            }
        }
        return out
    }

    private static func writeCell(_ cell: Cell, refs: [Int], sizeBytes: Int, into builder: inout BitBuilder) {
        builder.write(
            uint: UInt64(
                Cell.refsDescriptor(
                    refCount: cell.refs.count,
                    levelMask: cell.levelMask.value,
                    type: cell.type
                )
            ),
            bits: 8
        )
        builder.write(uint: UInt64(Cell.bitsDescriptor(bitLength: cell.bits.length)), bits: 8)
        builder.write(bytes: cell.bits.toAugmentedData())
        for r in refs { builder.write(uint: UInt64(r), bits: sizeBytes * 8) }
    }

    private static func cellSize(_ cell: Cell, sizeBytes: Int) -> Int {
        2 + (cell.bits.length + 7) / 8 + cell.refs.count * sizeBytes
    }

    private static func byteWidth(for value: UInt64) -> Int {
        guard value > 0 else { return 0 }
        let bits = 64 - value.leadingZeroBitCount
        return (bits + 7) / 8
    }

    // MARK: - Topological sort

    struct SortedCell {
        let cell: Cell
        let refs: [Int]
    }

    /// Orders cells so that every cell precedes the cells it references, deduplicating
    /// by representation hash — a shared subtree is written once.
    static func topologicalSort(_ root: Cell) -> [SortedCell] {
        // Collect the distinct cells first, keyed by hash.
        var all: [Data: (cell: Cell, refs: [Data])] = [:]
        var order: [Data] = []
        var pending: [Cell] = [root]

        while !pending.isEmpty {
            let batch = pending
            pending = []
            for cell in batch {
                let key = cell.hash()
                if all[key] != nil { continue }
                all[key] = (cell, cell.refs.map { $0.hash() })
                order.append(key)
                pending.append(contentsOf: cell.refs)
            }
        }

        // Depth-first post-order, visiting refs in reverse so the emitted order matches
        // the reference implementation byte-for-byte.
        var sorted: [Data] = []
        var visited = Set<Data>()
        var inProgress = Set<Data>()

        func visit(_ key: Data) {
            if visited.contains(key) { return }
            // A cycle is impossible in a well-formed cell DAG (hashes would have to be
            // self-referential), so treat it as a hard stop rather than looping.
            if inProgress.contains(key) { return }
            inProgress.insert(key)
            if let refs = all[key]?.refs {
                for r in refs.reversed() { visit(r) }
            }
            inProgress.remove(key)
            visited.insert(key)
            sorted.append(key)
        }

        for key in order { visit(key) }

        // Reverse so parents precede children, then map hashes to indices.
        let emitted = Array(sorted.reversed())
        var indices: [Data: Int] = [:]
        for (i, key) in emitted.enumerated() { indices[key] = i }

        return emitted.map { key in
            let entry = all[key]!
            return SortedCell(cell: entry.cell, refs: entry.refs.map { indices[$0]! })
        }
    }
}

// MARK: - Cell conveniences

extension Cell {
    /// Parses a single-root BoC.
    public static func fromBoc(_ data: Data) throws -> Cell {
        try BoC.deserializeSingleRoot(data)
    }

    /// Parses a base64-encoded single-root BoC, accepting either base64 alphabet.
    public static func fromBase64(_ string: String) throws -> Cell {
        guard let data = Data(anyBase64: string) else { throw Address.ParseError.invalidBase64 }
        return try fromBoc(data)
    }

    /// Parses a hex-encoded single-root BoC.
    public static func fromHex(_ string: String) throws -> Cell {
        guard let data = Data(hexString: string) else { throw Address.ParseError.invalidHexDigits }
        return try fromBoc(data)
    }

    public func toBoc(idx: Bool = false, crc32: Bool = true) -> Data {
        BoC.serialize(root: self, idx: idx, crc32: crc32)
    }

    public func toBocBase64(idx: Bool = false, crc32: Bool = true) -> String {
        toBoc(idx: idx, crc32: crc32).base64EncodedString()
    }
}
