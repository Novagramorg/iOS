import Foundation

/// What an attached `MediaBlock` is — drives the converter's `.image` vs `.video` InstantPage block
/// and lets a demo/host label its placeholder. The editor itself renders both identically (a hosted
/// view sized from `naturalSize`); only serialization and the host care about the distinction.
public enum MediaKind: String, Codable, Equatable, CaseIterable {
    case image
    case video
}
