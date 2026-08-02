import Foundation
import CryptoKit

/// The kind of a cell. Non-ordinary types are "exotic" and set bit 3 of the
/// refs descriptor.
public enum CellType: Int, Sendable {
    case ordinary = -1
    case prunedBranch = 1
    case library = 2
    case merkleProof = 3
    case merkleUpdate = 4
}

/// A TON cell: up to 1023 bits of payload and up to 4 references.
///
/// Reference semantics, because cells form a DAG with shared subtrees and hashing is
/// expensive — hashes and depths are computed once at construction.
public final class Cell: @unchecked Sendable {
    public static let maxBits = 1023
    public static let maxRefs = 4

    public let bits: BitString
    public let refs: [Cell]
    public let type: CellType
    public let levelMask: LevelMask

    /// Four entries, one per level, as the reference implementation stores them.
    private let hashes: [Data]
    private let depths: [Int]

    public var isExotic: Bool { type != .ordinary }

    public static let empty = try! Cell()

    public enum CellError: Error, CustomStringConvertible {
        case tooManyBits(Int)
        case tooManyRefs(Int)
        case unknownExoticType(Int)
        case prunedBranchWrongType(Int)
        case prunedBranchHasRefs(Int)
        case prunedBranchBadLevel(UInt32)
        case prunedBranchBadSize(expected: Int, actual: Int)
        case libraryBadSize(Int)
        case libraryWrongType(Int)
        case merkleProofBadSize(Int)
        case merkleProofBadRefCount(Int)
        case merkleProofWrongType(Int)
        case merkleProofHashMismatch(expected: String, actual: String)
        case merkleProofDepthMismatch(expected: Int, actual: Int)
        case merkleUpdateBadSize(Int)
        case merkleUpdateBadRefCount(Int)
        case merkleUpdateWrongType(Int)
        case merkleUpdateMismatch(String)
        case invalidHashLevel(level: Int, type: CellType)

        public var description: String {
            switch self {
            case .tooManyBits(let n): return "Cell payload of \(n) bits exceeds the 1023-bit limit"
            case .tooManyRefs(let n): return "Cell has \(n) refs, maximum is 4"
            case .unknownExoticType(let t): return "Unknown exotic cell type \(t)"
            case .prunedBranchWrongType(let t): return "Pruned branch must have type 1, got \(t)"
            case .prunedBranchHasRefs(let n): return "Pruned branch must have no refs, got \(n)"
            case .prunedBranchBadLevel(let m): return "Pruned branch level must be 1...3, got mask \(m)"
            case .prunedBranchBadSize(let e, let a): return "Pruned branch must have \(e) bits, got \(a)"
            case .libraryBadSize(let n): return "Library cell must have 264 bits, got \(n)"
            case .libraryWrongType(let t): return "Library cell must have type 2, got \(t)"
            case .merkleProofBadSize(let n): return "Merkle proof must have 280 bits, got \(n)"
            case .merkleProofBadRefCount(let n): return "Merkle proof must have exactly 1 ref, got \(n)"
            case .merkleProofWrongType(let t): return "Merkle proof must have type 3, got \(t)"
            case .merkleProofHashMismatch(let e, let a):
                return "Merkle proof ref hash must be \(e), got \(a)"
            case .merkleProofDepthMismatch(let e, let a):
                return "Merkle proof ref depth must be \(e), got \(a)"
            case .merkleUpdateBadSize(let n): return "Merkle update must have 552 bits, got \(n)"
            case .merkleUpdateBadRefCount(let n): return "Merkle update must have exactly 2 refs, got \(n)"
            case .merkleUpdateWrongType(let t): return "Merkle update must have type 4, got \(t)"
            case .merkleUpdateMismatch(let m): return "Merkle update mismatch: \(m)"
            case .invalidHashLevel(let level, let type):
                return "Invalid hash level \(level) for cell type \(type)"
            }
        }
    }

    public init(bits: BitString = .empty, refs: [Cell] = [], exotic: Bool = false) throws {
        guard bits.length <= Cell.maxBits else { throw CellError.tooManyBits(bits.length) }
        guard refs.count <= Cell.maxRefs else { throw CellError.tooManyRefs(refs.count) }

        self.bits = bits
        self.refs = refs

        let resolvedType: CellType
        if exotic {
            let reader = BitReader(bits)
            let raw = Int(try reader.preloadUInt(8))
            guard let t = CellType(rawValue: raw), t != .ordinary else {
                throw CellError.unknownExoticType(raw)
            }
            resolvedType = t
        } else {
            resolvedType = .ordinary
        }
        self.type = resolvedType

        let computed = try Cell.computeHashes(type: resolvedType, bits: bits, refs: refs)
        self.levelMask = computed.mask
        self.hashes = computed.hashes
        self.depths = computed.depths
    }

    // MARK: - Accessors

    /// Hash at `level`, clamped to the highest available — level 3 (the default)
    /// yields the representation hash for ordinary level-0 cells.
    public func hash(level: Int = 3) -> Data {
        hashes[min(hashes.count - 1, level)]
    }

    public func depth(level: Int = 3) -> Int {
        depths[min(depths.count - 1, level)]
    }

    public func level() -> Int {
        levelMask.level
    }

    // MARK: - Descriptors

    /// d1: `refCount + 8·isExotic + 32·levelMask`.
    ///
    /// Note this takes the level *mask value*, not the level.
    static func refsDescriptor(refCount: Int, levelMask: UInt32, type: CellType) -> UInt8 {
        UInt8(truncatingIfNeeded: refCount + (type != .ordinary ? 1 : 0) * 8 + Int(levelMask) * 32)
    }

    /// d2: `ceil(bits/8) + floor(bits/8)`. Odd values signal a partially filled
    /// final byte carrying a completion tag.
    static func bitsDescriptor(bitLength: Int) -> UInt8 {
        UInt8((bitLength + 7) / 8 + bitLength / 8)
    }

    /// The byte sequence that gets hashed.
    ///
    /// `originalBits` drives d2 while `currentBits` supplies the payload — at levels
    /// above 0 the payload is the previous level's hash, not the cell's own bits.
    static func representation(
        originalBits: BitString,
        currentBits: BitString,
        refs: [Cell],
        level: Int,
        levelMask: UInt32,
        type: CellType
    ) -> Data {
        var repr = Data(capacity: 2 + (currentBits.length + 7) / 8 + (2 + 32) * refs.count)
        repr.append(refsDescriptor(refCount: refs.count, levelMask: levelMask, type: type))
        repr.append(bitsDescriptor(bitLength: originalBits.length))
        repr.append(currentBits.toAugmentedData())

        // Merkle cells reach one level deeper into their children.
        let childLevel = (type == .merkleProof || type == .merkleUpdate) ? level + 1 : level

        for ref in refs {
            let d = ref.depth(level: childLevel)
            repr.append(UInt8(d / 256))
            repr.append(UInt8(d % 256))
        }
        for ref in refs {
            repr.append(ref.hash(level: childLevel))
        }
        return repr
    }

    // MARK: - Hash computation

    private struct Computed {
        let mask: LevelMask
        let hashes: [Data]
        let depths: [Int]
    }

    /// Port of `@ton/core`'s `wonderCalculator`. Deliberately kept structurally close
    /// to the reference: this is the code where a subtle divergence produces valid-looking
    /// but wrong hashes, which would only surface as rejected signatures much later.
    private static func computeHashes(
        type: CellType,
        bits: BitString,
        refs: [Cell]
    ) throws -> Computed {
        var levelMask: LevelMask
        var pruned: PrunedBranch?

        switch type {
        case .ordinary:
            var mask: UInt32 = 0
            for ref in refs { mask |= ref.levelMask.value }
            levelMask = LevelMask(mask)
            pruned = nil
        case .prunedBranch:
            let p = try parsePrunedBranch(bits: bits, refs: refs)
            levelMask = LevelMask(p.mask)
            pruned = p
        case .merkleProof:
            try validateMerkleProof(bits: bits, refs: refs)
            levelMask = LevelMask(refs[0].levelMask.value >> 1)
            pruned = nil
        case .merkleUpdate:
            try validateMerkleUpdate(bits: bits, refs: refs)
            levelMask = LevelMask((refs[0].levelMask.value | refs[1].levelMask.value) >> 1)
            pruned = nil
        case .library:
            try validateLibrary(bits: bits, refs: refs)
            levelMask = LevelMask()
            pruned = nil
        }

        var computedHashes: [Data] = []
        var computedDepths: [Int] = []

        // A pruned branch stores only its own representation hash; the higher ones
        // come from its payload.
        let hashCount = type == .prunedBranch ? 1 : levelMask.hashCount
        let totalHashCount = levelMask.hashCount
        let hashIOffset = totalHashCount - hashCount

        var hashI = 0
        for levelI in 0...max(levelMask.level, 0) {
            guard levelMask.isSignificant(levelI) else { continue }
            if hashI < hashIOffset {
                hashI += 1
                continue
            }

            let currentBits: BitString
            if hashI == hashIOffset {
                guard levelI == 0 || type == .prunedBranch else {
                    throw CellError.invalidHashLevel(level: levelI, type: type)
                }
                currentBits = bits
            } else {
                guard levelI != 0 && type != .prunedBranch else {
                    throw CellError.invalidHashLevel(level: levelI, type: type)
                }
                // Higher levels hash the previous level's hash as their payload.
                currentBits = BitString(computedHashes[hashI - hashIOffset - 1])
            }

            let childLevel = (type == .merkleProof || type == .merkleUpdate) ? levelI + 1 : levelI
            var currentDepth = 0
            for ref in refs {
                currentDepth = max(currentDepth, ref.depth(level: childLevel))
            }
            if !refs.isEmpty { currentDepth += 1 }

            let repr = representation(
                originalBits: bits,
                currentBits: currentBits,
                refs: refs,
                level: levelI,
                levelMask: levelMask.apply(levelI).value,
                type: type
            )
            let hash = Data(SHA256.hash(data: repr))

            let destI = hashI - hashIOffset
            if computedDepths.count <= destI {
                computedDepths.append(contentsOf: Array(repeating: 0, count: destI - computedDepths.count + 1))
                computedHashes.append(contentsOf: Array(repeating: Data(), count: destI - computedHashes.count + 1))
            }
            computedDepths[destI] = currentDepth
            computedHashes[destI] = hash
            hashI += 1
        }

        // Expand to four levels so hash(level:) is a plain lookup.
        var resolvedHashes: [Data] = []
        var resolvedDepths: [Int] = []
        if let pruned {
            for i in 0..<4 {
                let hashIndex = levelMask.apply(i).hashIndex
                if hashIndex != levelMask.hashIndex {
                    resolvedHashes.append(pruned.entries[hashIndex].hash)
                    resolvedDepths.append(pruned.entries[hashIndex].depth)
                } else {
                    resolvedHashes.append(computedHashes[0])
                    resolvedDepths.append(computedDepths[0])
                }
            }
        } else {
            for i in 0..<4 {
                let index = levelMask.apply(i).hashIndex
                resolvedHashes.append(computedHashes[index])
                resolvedDepths.append(computedDepths[index])
            }
        }

        return Computed(mask: levelMask, hashes: resolvedHashes, depths: resolvedDepths)
    }

    // MARK: - Exotic parsing

    struct PrunedBranch {
        struct Entry {
            let depth: Int
            let hash: Data
        }
        let mask: UInt32
        let entries: [Entry]
    }

    static func parsePrunedBranch(bits: BitString, refs: [Cell]) throws -> PrunedBranch {
        var reader = BitReader(bits)
        let type = Int(try reader.loadUInt(8))
        guard type == 1 else { throw CellError.prunedBranchWrongType(type) }
        guard refs.isEmpty else { throw CellError.prunedBranchHasRefs(refs.count) }

        let mask: LevelMask
        if bits.length == 280 {
            // Legacy single-level form carries no explicit mask byte.
            mask = LevelMask(1)
        } else {
            mask = LevelMask(UInt32(try reader.loadUInt(8)))
            guard mask.level >= 1 && mask.level <= 3 else {
                throw CellError.prunedBranchBadLevel(mask.value)
            }
            let expected = 8 + 8 + mask.apply(mask.level - 1).hashCount * (256 + 16)
            guard bits.length == expected else {
                throw CellError.prunedBranchBadSize(expected: expected, actual: bits.length)
            }
        }

        var hashes: [Data] = []
        for _ in 0..<mask.level { hashes.append(try reader.loadBytes(32)) }
        var depths: [Int] = []
        for _ in 0..<mask.level { depths.append(Int(try reader.loadUInt(16))) }

        return PrunedBranch(
            mask: mask.value,
            entries: (0..<mask.level).map { PrunedBranch.Entry(depth: depths[$0], hash: hashes[$0]) }
        )
    }

    static func validateLibrary(bits: BitString, refs: [Cell]) throws {
        guard bits.length == 8 + 256 else { throw CellError.libraryBadSize(bits.length) }
        var reader = BitReader(bits)
        let type = Int(try reader.loadUInt(8))
        guard type == 2 else { throw CellError.libraryWrongType(type) }
    }

    static func validateMerkleProof(bits: BitString, refs: [Cell]) throws {
        guard bits.length == 8 + 256 + 16 else { throw CellError.merkleProofBadSize(bits.length) }
        guard refs.count == 1 else { throw CellError.merkleProofBadRefCount(refs.count) }

        var reader = BitReader(bits)
        let type = Int(try reader.loadUInt(8))
        guard type == 3 else { throw CellError.merkleProofWrongType(type) }

        let proofHash = try reader.loadBytes(32)
        let proofDepth = Int(try reader.loadUInt(16))
        let refHash = refs[0].hash(level: 0)
        let refDepth = refs[0].depth(level: 0)

        guard proofDepth == refDepth else {
            throw CellError.merkleProofDepthMismatch(expected: proofDepth, actual: refDepth)
        }
        guard proofHash == refHash else {
            throw CellError.merkleProofHashMismatch(
                expected: proofHash.hexString,
                actual: refHash.hexString
            )
        }
    }

    static func validateMerkleUpdate(bits: BitString, refs: [Cell]) throws {
        guard bits.length == 8 + 2 * (256 + 16) else { throw CellError.merkleUpdateBadSize(bits.length) }
        guard refs.count == 2 else { throw CellError.merkleUpdateBadRefCount(refs.count) }

        var reader = BitReader(bits)
        let type = Int(try reader.loadUInt(8))
        guard type == 4 else { throw CellError.merkleUpdateWrongType(type) }

        let hash1 = try reader.loadBytes(32)
        let hash2 = try reader.loadBytes(32)
        let depth1 = Int(try reader.loadUInt(16))
        let depth2 = Int(try reader.loadUInt(16))

        guard depth1 == refs[0].depth(level: 0) else {
            throw CellError.merkleUpdateMismatch("ref 0 depth \(refs[0].depth(level: 0)) != \(depth1)")
        }
        guard hash1 == refs[0].hash(level: 0) else {
            throw CellError.merkleUpdateMismatch("ref 0 hash mismatch")
        }
        guard depth2 == refs[1].depth(level: 0) else {
            throw CellError.merkleUpdateMismatch("ref 1 depth \(refs[1].depth(level: 0)) != \(depth2)")
        }
        guard hash2 == refs[1].hash(level: 0) else {
            throw CellError.merkleUpdateMismatch("ref 1 hash mismatch")
        }
    }
}

// MARK: - Equality

extension Cell: Hashable {
    /// Cells are equal when their representation hashes match — the DAG-aware
    /// definition, and what deduplication during serialization relies on.
    public static func == (lhs: Cell, rhs: Cell) -> Bool {
        lhs === rhs || lhs.hash() == rhs.hash()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(hash())
    }
}

extension Cell: CustomStringConvertible {
    public var description: String {
        var out = "x{\(bits.description)}"
        if isExotic { out = "\(type) \(out)" }
        if !refs.isEmpty { out += " -> \(refs.count) ref(s)" }
        return out
    }
}
