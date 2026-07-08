import Foundation

/// One medium (image or video) inside a `MediaBlock` container. The container holds one or more of these
/// plus a single shared caption. `mediaID` is the host's opaque content key (mapped to a view via the
/// media-view provider and to a real `Media` at serialize time); the SAME `mediaID` may appear more than
/// once (in one container or across blocks).
public struct MediaItem: Codable, Equatable {
    public var mediaID: String
    public var kind: MediaKind
    public var naturalSize: Size2D

    public init(mediaID: String, kind: MediaKind = .image, naturalSize: Size2D) {
        self.mediaID = mediaID
        self.kind = kind
        self.naturalSize = naturalSize
    }
}
