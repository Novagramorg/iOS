import Foundation

/// An attached medium (image or video) with an editable caption. In the position model this is a
/// non-leaf node containing a media atom (size 1) followed by the caption paragraph.
public struct MediaBlock: Codable, Equatable {
    public var id: BlockID
    /// The host's opaque content key (mapped to a view via the media-view provider, and to a real
    /// `Media` at serialize time). The SAME `mediaID` may legitimately appear in more than one block.
    public var mediaID: String
    public var kind: MediaKind
    public var naturalSize: Size2D
    /// Display width in points; nil = natural width.
    public var displayWidth: Double?
    public var alignment: MediaAlignment
    public var caption: [TextRun]

    public init(
        id: BlockID,
        mediaID: String,
        kind: MediaKind = .image,
        naturalSize: Size2D,
        displayWidth: Double? = nil,
        alignment: MediaAlignment = .center,
        caption: [TextRun] = []
    ) {
        self.id = id
        self.mediaID = mediaID
        self.kind = kind
        self.naturalSize = naturalSize
        self.displayWidth = displayWidth
        self.alignment = alignment
        self.caption = caption
    }

    public var captionUTF16Count: Int { caption.reduce(0) { $0 + $1.utf16Count } }
}
