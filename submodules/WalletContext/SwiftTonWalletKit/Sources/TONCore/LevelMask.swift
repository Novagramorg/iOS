import Foundation

/// A cell's level mask: which of the four hash levels are significant.
///
/// Ordinary cells are level 0 (mask 0) unless they reference exotic cells. Pruned
/// branches, merkle proofs and merkle updates raise the level, which changes the
/// descriptor bytes and therefore the hash — getting this wrong produces silently
/// wrong hashes, so it is modelled explicitly rather than inlined.
public struct LevelMask: Hashable, Sendable {
    public let value: UInt32

    public init(_ value: UInt32 = 0) {
        self.value = value
    }

    /// Highest significant level: 0 for mask 0, 1 for mask 1, 2 for mask 2–3, etc.
    public var level: Int {
        32 - value.leadingZeroBitCount
    }

    /// Number of higher hashes stored alongside the representation hash.
    public var hashIndex: Int {
        value.nonzeroBitCount
    }

    /// Total hashes a cell of this mask carries: the representation hash plus the
    /// higher ones.
    public var hashCount: Int {
        hashIndex + 1
    }

    /// The mask restricted to levels below `level`.
    public func apply(_ level: Int) -> LevelMask {
        precondition(level >= 0, "Level must be non-negative")
        guard level < 32 else { return self }
        return LevelMask(value & ((1 << UInt32(level)) - 1))
    }

    /// Whether `level` contributes a distinct hash. Level 0 always does.
    public func isSignificant(_ level: Int) -> Bool {
        level == 0 || (value >> UInt32(level - 1)) % 2 != 0
    }
}
