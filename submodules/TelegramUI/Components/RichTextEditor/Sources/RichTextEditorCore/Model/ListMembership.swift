import Foundation

public struct ListMembership: Codable, Equatable {
    public var marker: ListMarker
    /// 0-based nesting level.
    public var level: Int

    public init(marker: ListMarker, level: Int = 0) {
        self.marker = marker
        self.level = level
    }
}
