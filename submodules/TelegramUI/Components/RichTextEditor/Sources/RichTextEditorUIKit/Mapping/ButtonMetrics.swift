#if canImport(UIKit)
import UIKit

/// Pill geometry, supplied by the host so it cannot drift from the InstantPage V2 renderer's own
/// constants. Pinned equal to them by `RichTextV2ButtonParityTests` in `InstantPageUITests` — the only
/// target that can import both modules (the editor importing `InstantPageUI` would be a cycle).
///
/// Font sizes here are FIXED — the renderer does not scale them by the Instant View font-size setting
/// either, because the chat bubble's own text categories are hardcoded.
@available(iOS 13.0, *)
public struct RichTextButtonMetrics: Equatable {
    /// Label size for an inline `RichText.textButton`. Semibold regardless of the paragraph weight.
    public var inlineFontSize: CGFloat
    /// Label size for a `pageBlockButtonRow` member — one point larger than inline. Also semibold.
    public var blockFontSize: CGFloat
    /// Per-side padding between the label ink and the pill edge, inline.
    public var inlineHorizontalPadding: CGFloat
    /// Per-side horizontal padding for a block-row pill: a standalone touch target wants more room.
    public var blockHorizontalPadding: CGFloat
    /// What a block-row pill falls back to when its label does NOT fit at `blockHorizontalPadding`.
    /// Padding is a preference, not a constraint: once a label would be cut, the room is worth more as
    /// text. Applied per button, so a row's short labels keep the comfortable value.
    public var blockMinimumHorizontalPadding: CGFloat
    /// Per-side vertical padding. Shared by both pill kinds.
    public var verticalPadding: CGFloat
    /// Extra gap between two DIRECTLY ADJACENT inline pills. Without it they touch: each pill's width
    /// lives entirely on its placeholder's run delegate, which reports exactly the pill width, so two
    /// consecutive placeholders leave no advance between the fills.
    public var adjacentSpacing: CGFloat
    /// Fixed height of a block-row pill — a touch target, not a derived ink box.
    public var blockRowHeight: CGFloat
    /// Gap between two pills in a block row, and between two wrapped rows. (Distinct from
    /// `adjacentSpacing`, which is the inline-pill gap.)
    public var blockSpacing: CGFloat
    /// Horizontal room a badge-bearing pill keeps clear on EACH side so a centred label cannot run
    /// under the top-right type badge. The editor draws no badge, but it must reserve the same room or
    /// its labels would ellipsise at a different point than the sent message's.
    public var blockIconReserve: CGFloat
    /// Maximum pills laid out in one visual row before wrapping.
    public var maximumButtonsPerRow: Int

    public init(
        inlineFontSize: CGFloat,
        blockFontSize: CGFloat,
        inlineHorizontalPadding: CGFloat,
        blockHorizontalPadding: CGFloat,
        blockMinimumHorizontalPadding: CGFloat,
        verticalPadding: CGFloat,
        adjacentSpacing: CGFloat,
        blockRowHeight: CGFloat,
        blockSpacing: CGFloat,
        blockIconReserve: CGFloat,
        maximumButtonsPerRow: Int
    ) {
        self.inlineFontSize = inlineFontSize
        self.blockFontSize = blockFontSize
        self.inlineHorizontalPadding = inlineHorizontalPadding
        self.blockHorizontalPadding = blockHorizontalPadding
        self.blockMinimumHorizontalPadding = blockMinimumHorizontalPadding
        self.verticalPadding = verticalPadding
        self.adjacentSpacing = adjacentSpacing
        self.blockRowHeight = blockRowHeight
        self.blockSpacing = blockSpacing
        self.blockIconReserve = blockIconReserve
        self.maximumButtonsPerRow = maximumButtonsPerRow
    }

    /// The values `InstantPageInlineButton.swift` ships. Pinned by test.
    public static let `default` = RichTextButtonMetrics(
        inlineFontSize: 15.0,
        blockFontSize: 16.0,
        inlineHorizontalPadding: 7.0,
        blockHorizontalPadding: 19.0,
        blockMinimumHorizontalPadding: 6.0,
        verticalPadding: 1.0,
        adjacentSpacing: 3.0,
        blockRowHeight: 40.0,
        blockSpacing: 6.0,
        blockIconReserve: 18.0,
        maximumButtonsPerRow: 8
    )
}
#endif
