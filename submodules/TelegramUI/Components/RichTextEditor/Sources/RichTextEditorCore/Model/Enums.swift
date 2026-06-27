import Foundation

public enum TextAlignment: String, Codable, Equatable, CaseIterable {
    case left, center, right, justified
}

public enum ParagraphStyleName: String, Codable, Equatable, CaseIterable {
    // `caption` is a render-only style (media-block captions, 15pt) — it is never offered in the style
    // picker and never persists as a paragraph style (a caption serializes as the MediaBlock's runs).
    case heading1, heading2, heading3, heading4, heading5, heading6, body, caption, quote
}

public enum ListMarker: String, Codable, Equatable, CaseIterable {
    case bullet, ordered, checklist
}

public enum MediaAlignment: String, Codable, Equatable, CaseIterable {
    case left, center, right
}
