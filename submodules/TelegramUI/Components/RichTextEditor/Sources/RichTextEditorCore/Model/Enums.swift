import Foundation

public enum TextAlignment: String, Codable, Equatable, CaseIterable {
    case left, center, right, justified
}

public enum ParagraphStyleName: String, Codable, Equatable, CaseIterable {
    case title, heading1, heading2, heading3, body, quote
}

public enum ListMarker: String, Codable, Equatable, CaseIterable {
    case bullet, ordered
}

public enum ImageAlignment: String, Codable, Equatable, CaseIterable {
    case left, center, right
}
