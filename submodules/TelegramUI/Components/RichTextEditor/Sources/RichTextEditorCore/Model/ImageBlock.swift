import Foundation

/// An image with an editable caption. In the position model this is a non-leaf node
/// containing an image atom (size 1) followed by the caption paragraph.
public struct ImageBlock: Codable, Equatable {
    public var id: BlockID
    /// Filename of the backing asset inside the document package's `assets/` folder.
    public var assetID: String
    public var naturalSize: Size2D
    /// Display width in points; nil = natural width.
    public var displayWidth: Double?
    public var alignment: ImageAlignment
    public var caption: [TextRun]

    public init(
        id: BlockID,
        assetID: String,
        naturalSize: Size2D,
        displayWidth: Double? = nil,
        alignment: ImageAlignment = .center,
        caption: [TextRun] = []
    ) {
        self.id = id
        self.assetID = assetID
        self.naturalSize = naturalSize
        self.displayWidth = displayWidth
        self.alignment = alignment
        self.caption = caption
    }

    public var captionUTF16Count: Int { caption.reduce(0) { $0 + $1.utf16Count } }
}
