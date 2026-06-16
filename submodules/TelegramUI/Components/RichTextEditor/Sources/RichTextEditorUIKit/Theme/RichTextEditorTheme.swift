#if canImport(UIKit)
import UIKit

/// Host-settable colors for the editor. Set via `RichTextEditorView.theme`; applied at render time only and
/// never written into the `Document` model. `default` reproduces the editor's prior hardcoded colors, so the
/// look is unchanged until a host assigns a theme.
@available(iOS 17.0, *)
public struct RichTextEditorTheme {
    /// Default foreground for runs without an explicit color (and for list markers' conceptual text color).
    public var primaryText: UIColor
    /// Default foreground for `.caption`-style runs. Defaults to the same value as `primaryText` until a
    /// host assigns a distinct color.
    public var secondaryText: UIColor
    /// Empty-paragraph, marked-text, and media placeholder ("ghost") text.
    public var placeholder: UIColor
    /// Accent color. Drives link-text foreground, the blockquote bar + fill, the caret, and the selection
    /// highlight (these render sites are wired to read this across the theme feature's tasks).
    public var accent: UIColor
    /// Table grid lines.
    public var tableBorder: UIColor
    /// Table header-row background fill.
    public var tableHeaderBackground: UIColor

    public init(
        primaryText: UIColor,
        secondaryText: UIColor,
        placeholder: UIColor,
        accent: UIColor,
        tableBorder: UIColor,
        tableHeaderBackground: UIColor
    ) {
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.placeholder = placeholder
        self.accent = accent
        self.tableBorder = tableBorder
        self.tableHeaderBackground = tableHeaderBackground
    }

    /// Reproduces the editor's prior hardcoded colors exactly (see the design doc's site inventory).
    public static let `default` = RichTextEditorTheme(
        primaryText: .black,
        secondaryText: .black,
        placeholder: .placeholderText,
        accent: .link,
        // Prior `TableBlockBox.gridColor` (dynamic light #E0E0E0 / dark white 0.27).
        tableBorder: UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(white: 0.27, alpha: 1) : UIColor(white: 0.88, alpha: 1)
        },
        // Prior `TableBlockBox.headerRowBackground`.
        tableHeaderBackground: UIColor(white: 0.5, alpha: 0.1)
    )
}
#endif
