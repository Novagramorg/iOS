import Foundation

public struct ChatInputRun: Equatable, Codable {
    public var text: String
    public var attributes: ChatInputInlineAttributes
    public init(text: String, attributes: ChatInputInlineAttributes = ChatInputInlineAttributes()) {
        self.text = text
        self.attributes = attributes
    }
}

public struct ChatInputInlineAttributes: Equatable, Codable {
    public var bold: Bool
    public var italic: Bool
    public var monospace: Bool
    public var strikethrough: Bool
    public var underline: Bool
    public var spoiler: Bool
    public var entity: ChatInputInlineEntity?
    public init(
        bold: Bool = false,
        italic: Bool = false,
        monospace: Bool = false,
        strikethrough: Bool = false,
        underline: Bool = false,
        spoiler: Bool = false,
        entity: ChatInputInlineEntity? = nil
    ) {
        self.bold = bold
        self.italic = italic
        self.monospace = monospace
        self.strikethrough = strikethrough
        self.underline = underline
        self.spoiler = spoiler
        self.entity = entity
    }
}

public enum ChatInputInlineEntity: Equatable, Codable {
    case mention(EnginePeer.Id)
    case url(String)
    case date(Int32)
    case customEmoji(fileId: Int64, file: TelegramMediaFile?, enableAnimation: Bool)

    public static func == (lhs: ChatInputInlineEntity, rhs: ChatInputInlineEntity) -> Bool {
        switch (lhs, rhs) {
        case let (.mention(a), .mention(b)): return a == b
        case let (.url(a), .url(b)): return a == b
        case let (.date(a), .date(b)): return a == b
        // `file` is a heavy media reference that is reconstructed from a side cache (and dropped by
        // the canonical ChatTextInputStateText form); identity is the fileId + animation flag.
        case let (.customEmoji(aId, _, aAnim), .customEmoji(bId, _, bAnim)): return aId == bId && aAnim == bAnim
        default: return false
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case peerId
        case url
        case date
        case fileId
        case enableAnimation
    }

    private enum Kind: Int32, Codable {
        case mention
        case url
        case date
        case customEmoji
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decode the discriminator as the raw `Int32` (NOT `Kind.self`): the Postbox `AdaptedPostbox*coder` does
        // not support the `singleValueContainer` that a `RawRepresentable` enum's synthesized Codable uses.
        let kindValue = try container.decode(Int32.self, forKey: .kind)
        guard let kind = Kind(rawValue: kindValue) else {
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown discriminator \(kindValue)")
        }
        switch kind {
        case .mention:
            let peerId = try container.decode(Int64.self, forKey: .peerId)
            self = .mention(EnginePeer.Id(peerId))
        case .url:
            self = .url(try container.decode(String.self, forKey: .url))
        case .date:
            self = .date(try container.decode(Int32.self, forKey: .date))
        case .customEmoji:
            let fileId = try container.decode(Int64.self, forKey: .fileId)
            let enableAnimation = try container.decode(Bool.self, forKey: .enableAnimation)
            // `file` is not persisted (reconstructed from a side cache); decode as nil.
            self = .customEmoji(fileId: fileId, file: nil, enableAnimation: enableAnimation)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .mention(peerId):
            try container.encode(Kind.mention.rawValue, forKey: .kind)
            // Deliberately a flat Int64 (not `encode(peerId)`): `EnginePeer.Id`/`PeerId` is itself Codable but wraps
            // the value in a nested `{internalValue:}` container — the flat form is the leaner persisted shape and
            // round-trips exactly (`PeerId(toInt64()) == self`). Keep flat; do not "simplify" to `encode(peerId)`.
            try container.encode(peerId.toInt64(), forKey: .peerId)
        case let .url(value):
            try container.encode(Kind.url.rawValue, forKey: .kind)
            try container.encode(value, forKey: .url)
        case let .date(value):
            try container.encode(Kind.date.rawValue, forKey: .kind)
            try container.encode(value, forKey: .date)
        case let .customEmoji(fileId, _, enableAnimation):
            try container.encode(Kind.customEmoji.rawValue, forKey: .kind)
            // `file` is intentionally not persisted; only fileId + enableAnimation are encoded.
            try container.encode(fileId, forKey: .fileId)
            try container.encode(enableAnimation, forKey: .enableAnimation)
        }
    }
}

public struct ChatInputContent: Equatable, Codable {
    public var schemaVersion: Int32
    public var blocks: [ChatInputBlock]
    public init(schemaVersion: Int32 = 1, blocks: [ChatInputBlock] = []) {
        self.schemaVersion = schemaVersion
        self.blocks = blocks
    }

    /// The flat plain text, identical to `attributedString(from: self).string`: blocks joined by a single
    /// "\n", a paragraph/code block contributing its runs' text and a `collapsedQuote` contributing one " "
    /// placeholder. (Quote coalescing in the conversion changes only the block *attribute*, not the text, so a
    /// per-block "\n" join reproduces it exactly.) Lets `inputText`-string readers move to the model — a
    /// round-trip-parity test guards the equivalence.
    public var plainText: String {
        var result = ""
        var isFirst = true
        for block in self.blocks {
            if !isFirst {
                result.append("\n")
            }
            isFirst = false
            switch block {
            case let .paragraph(paragraph):
                result.append(paragraph.text)
            case let .code(code):
                result.append(code.text)
            case .collapsedQuote:
                result.append(" ")
            }
        }
        return result
    }

    /// The UTF-16 length, identical to `attributedString(from: self).length` (a custom emoji is one U+FFFC unit).
    public var length: Int {
        return (self.plainText as NSString).length
    }

    /// Whether the composer text is empty — identical to `plainText.isEmpty` / `length == 0`, but **without
    /// building the string** (so it's cheap on hot paths, unlike reading the derived `inputText`). Empty iff
    /// there are no blocks, or exactly one block whose text is empty (2+ blocks always carry an inter-block
    /// "\n"; a `collapsedQuote` is a non-empty placeholder).
    public var isEmpty: Bool {
        guard self.blocks.count <= 1 else {
            return false
        }
        guard let block = self.blocks.first else {
            return true
        }
        switch block {
        case let .paragraph(paragraph):
            return paragraph.text.isEmpty
        case let .code(code):
            return code.text.isEmpty
        case .collapsedQuote:
            return false
        }
    }

    /// Whether this content can be represented as plain text + message entities (the `.textEntities`
    /// branch) rather than requiring a structured `InstantPage` (the `.instantPage` branch). True for
    /// every block today; the deliberate switch with no `default` forces a compile decision the day a
    /// non-entity-expressible block type is introduced.
    public var isEntityExpressible: Bool {
        return self.blocks.allSatisfy { block in
            switch block {
            case .paragraph: return true
            case .code: return true
            case let .collapsedQuote(content): return content.isEntityExpressible
            }
        }
    }
}

public enum ChatInputBlock: Equatable, Codable {
    case paragraph(ChatInputParagraph)
    case code(ChatInputCode)
    /// A collapsed blockquote: a single placeholder in the flat text whose folded content is carried
    /// recursively. Mirrors `ChatTextInputStateText.collapsedQuote` / the `.collapsedBlock` attribute.
    case collapsedQuote(ChatInputContent)

    private enum CodingKeys: String, CodingKey {
        case kind
        case paragraph
        case code
        case collapsedQuote
    }

    private enum Kind: Int32, Codable {
        case paragraph
        case code
        case collapsedQuote
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decode the discriminator as the raw `Int32` (NOT `Kind.self`): the Postbox `AdaptedPostbox*coder` does
        // not support the `singleValueContainer` that a `RawRepresentable` enum's synthesized Codable uses.
        let kindValue = try container.decode(Int32.self, forKey: .kind)
        guard let kind = Kind(rawValue: kindValue) else {
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown discriminator \(kindValue)")
        }
        switch kind {
        case .paragraph:
            self = .paragraph(try container.decode(ChatInputParagraph.self, forKey: .paragraph))
        case .code:
            self = .code(try container.decode(ChatInputCode.self, forKey: .code))
        case .collapsedQuote:
            self = .collapsedQuote(try container.decode(ChatInputContent.self, forKey: .collapsedQuote))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .paragraph(paragraph):
            try container.encode(Kind.paragraph.rawValue, forKey: .kind)
            try container.encode(paragraph, forKey: .paragraph)
        case let .code(code):
            try container.encode(Kind.code.rawValue, forKey: .kind)
            try container.encode(code, forKey: .code)
        case let .collapsedQuote(content):
            try container.encode(Kind.collapsedQuote.rawValue, forKey: .kind)
            try container.encode(content, forKey: .collapsedQuote)
        }
    }
}

public struct ChatInputParagraph: Equatable, Codable {
    public var style: ChatInputParagraphStyle
    public var runs: [ChatInputRun]
    public init(style: ChatInputParagraphStyle = .body, runs: [ChatInputRun] = []) {
        self.style = style
        self.runs = runs
    }
    public var text: String { runs.map(\.text).joined() }
}

public enum ChatInputParagraphStyle: Equatable, Codable {
    case body
    case quote(isCollapsed: Bool)

    private enum CodingKeys: String, CodingKey {
        case kind
        case isCollapsed
    }

    private enum Kind: Int32, Codable {
        case body
        case quote
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decode the discriminator as the raw `Int32` (NOT `Kind.self`): the Postbox `AdaptedPostbox*coder` does
        // not support the `singleValueContainer` that a `RawRepresentable` enum's synthesized Codable uses.
        let kindValue = try container.decode(Int32.self, forKey: .kind)
        guard let kind = Kind(rawValue: kindValue) else {
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown discriminator \(kindValue)")
        }
        switch kind {
        case .body:
            self = .body
        case .quote:
            self = .quote(isCollapsed: try container.decode(Bool.self, forKey: .isCollapsed))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .body:
            try container.encode(Kind.body.rawValue, forKey: .kind)
        case let .quote(isCollapsed):
            try container.encode(Kind.quote.rawValue, forKey: .kind)
            try container.encode(isCollapsed, forKey: .isCollapsed)
        }
    }
}

public struct ChatInputCode: Equatable, Codable {
    public var language: String?
    public var runs: [ChatInputRun]
    public init(language: String? = nil, runs: [ChatInputRun] = []) {
        self.language = language
        self.runs = runs
    }
    public var text: String { runs.map(\.text).joined() }
}

/// One step descending the block tree: pick a block at this level, then which of its nested-content slots to
/// descend into. `slot` is unused at the LEAF step (a text block has no nested content) — 0 by convention.
public struct ChatInputPathStep: Equatable {
    public var blockIndex: Int
    public var slot: Int
    public init(blockIndex: Int, slot: Int = 0) {
        self.blockIndex = blockIndex
        self.slot = slot
    }
}

/// A caret position: a non-empty path of `(blockIndex, slot)` steps through the (possibly nested) block tree to
/// a UTF-16 `offset` within the addressed text-leaf block. Today the editor produces only depth-1 paths (the
/// flat string contains only top-level, unfolded content); deeper paths are reserved for future nested editing.
public struct ChatInputPosition: Equatable {
    public var path: [ChatInputPathStep]
    public var offset: Int
    public init(path: [ChatInputPathStep], offset: Int) {
        self.path = path
        self.offset = offset
    }
}

public struct ChatInputSelection: Equatable {
    public var start: ChatInputPosition
    public var end: ChatInputPosition
    public init(start: ChatInputPosition, end: ChatInputPosition) {
        self.start = start
        self.end = end
    }
    public var isCollapsed: Bool { start == end }
}

public extension ChatInputContent {
    /// Flat (caret) extent of a top-level block in `plainText`: a paragraph/code block contributes its text
    /// length; a `collapsedQuote` contributes 1 (its folded " " placeholder; its nested content is off-string).
    private func blockFlatLength(_ block: ChatInputBlock) -> Int {
        switch block {
        case let .paragraph(paragraph):
            return (paragraph.text as NSString).length
        case let .code(code):
            return (code.text as NSString).length
        case .collapsedQuote:
            return 1
        }
    }

    /// Map a structural position to a flat UTF-16 offset into `plainText`. Only depth-1 positions (the editing
    /// surface today) round-trip exactly; a deeper path (into not-yet-unfolded nested content, which has no flat
    /// representation) clamps to the addressed top-level block's start.
    func flatOffset(for position: ChatInputPosition) -> Int {
        guard let first = position.path.first else {
            return 0
        }
        let count = self.blocks.count
        if count == 0 {
            return 0
        }
        let blockIndex = min(max(first.blockIndex, 0), count - 1)
        var base = 0
        for i in 0 ..< blockIndex {
            base += blockFlatLength(self.blocks[i]) + 1 // + inter-block "\n"
        }
        if position.path.count == 1 {
            let leafLength = blockFlatLength(self.blocks[blockIndex])
            return base + min(max(position.offset, 0), leafLength)
        }
        return base
    }

    /// Map a flat UTF-16 offset (into `plainText`) to a structural position. Always a depth-1 path — the flat
    /// string only contains top-level, unfolded content. Offsets straddling an inter-block "\n" resolve cleanly
    /// (the "\n" is its own index: `endOfBlockI` and `startOfBlockI+1` are distinct consecutive offsets).
    func position(forFlatOffset rawOffset: Int) -> ChatInputPosition {
        let total = (self.plainText as NSString).length
        let offset = min(max(rawOffset, 0), total)
        var cursor = 0
        for (i, block) in self.blocks.enumerated() {
            let length = blockFlatLength(block)
            if offset <= cursor + length {
                return ChatInputPosition(path: [ChatInputPathStep(blockIndex: i)], offset: offset - cursor)
            }
            cursor += length + 1
        }
        let lastIndex = max(self.blocks.count - 1, 0)
        let lastLength = self.blocks.isEmpty ? 0 : blockFlatLength(self.blocks[lastIndex])
        return ChatInputPosition(path: [ChatInputPathStep(blockIndex: lastIndex)], offset: lastLength)
    }
}

public extension ChatInputSelection {
    /// The ordered flat `NSRange` (into `content.plainText`) for this selection.
    func nsRange(in content: ChatInputContent) -> NSRange {
        let a = content.flatOffset(for: self.start)
        let b = content.flatOffset(for: self.end)
        let lo = min(a, b)
        let hi = max(a, b)
        return NSRange(location: lo, length: hi - lo)
    }

    /// Build a selection from a flat `NSRange` (into `content.plainText`).
    init(nsRange: NSRange, in content: ChatInputContent) {
        self.init(
            start: content.position(forFlatOffset: nsRange.location),
            end: content.position(forFlatOffset: nsRange.location + nsRange.length)
        )
    }
}
