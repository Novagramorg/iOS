import Foundation
import UIKit
import Display
import ContextUI
import TelegramPresentationData
import RichTextEditorCore
import RichTextEditorUIKit
import TelegramCore
import AsyncDisplayKit

final class TableStructuralMenuAlignmentItem: ContextMenuCustomItem {
    let initialHorizontal: TableHorizontalAlignment?
    let initialVertical: TableVerticalAlignment?
    let action: (TableHorizontalAlignment?, TableVerticalAlignment?) -> Void

    init(initialHorizontal: TableHorizontalAlignment?, initialVertical: TableVerticalAlignment?,
         action: @escaping (TableHorizontalAlignment?, TableVerticalAlignment?) -> Void) {
        self.initialHorizontal = initialHorizontal
        self.initialVertical = initialVertical
        self.action = action
    }

    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return TableStructuralMenuAlignmentItemNode(presentationData: presentationData, getController: getController, actionSelected: actionSelected, item: self)
    }
}

private let regularFont = Font.regular(15.0)
private let selectedFont = Font.semibold(15.0)

private let alignmentMenuHorizontalValues: [TableHorizontalAlignment] = [.left, .center, .right]
private let alignmentMenuHorizontalTitles = ["Left", "Center", "Right"]
private let alignmentMenuVerticalValues: [TableVerticalAlignment] = [.top, .middle, .bottom]
private let alignmentMenuVerticalTitles = ["Top", "Middle", "Bottom"]

/// One tap target inside a segmented row: a persistent background, a transient touch-highlight overlay
/// (mirrors `BrowserFontSizeContextMenuItemNode`'s button convention), and a centered title whose color/weight
/// reflects whether this segment is the row's current selection.
private final class AlignmentSegmentButtonNode: ASDisplayNode {
    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let textNode: ImmediateTextNode
    private let buttonNode: HighlightTrackingButtonNode

    var pressed: (() -> Void)?

    init(accessibilityLabel: String) {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isAccessibilityElement = false

        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isAccessibilityElement = false
        self.highlightedBackgroundNode.alpha = 0.0

        self.textNode = ImmediateTextNode()
        self.textNode.isAccessibilityElement = false
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        self.textNode.textAlignment = .center

        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.isAccessibilityElement = true
        self.buttonNode.accessibilityLabel = accessibilityLabel
        self.buttonNode.accessibilityTraits = [.button]

        super.init()

        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.buttonNode)

        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            if highlighted {
                self.highlightedBackgroundNode.alpha = 1.0
            } else {
                self.highlightedBackgroundNode.alpha = 0.0
                self.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
            }
        }
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }

    @objc private func buttonPressed() {
        self.pressed?()
    }

    func update(title: String, isSelected: Bool, backgroundColor: UIColor, highlightedBackgroundColor: UIColor, normalTextColor: UIColor, selectedTextColor: UIColor) {
        self.backgroundNode.backgroundColor = backgroundColor
        self.highlightedBackgroundNode.backgroundColor = highlightedBackgroundColor
        self.textNode.attributedText = NSAttributedString(string: title, font: isSelected ? selectedFont : regularFont, textColor: isSelected ? selectedTextColor : normalTextColor)
        self.buttonNode.accessibilityTraits = isSelected ? [.button, .selected] : [.button]
    }

    func updateLayout(size: CGSize) {
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: size)

        let textSize = self.textNode.updateLayout(size)
        self.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: floorToScreenPixels((size.height - textSize.height) / 2.0)), size: textSize)
    }
}

/// Renders the per-cell alignment control as two rows of three segmented buttons (H: Left/Center/Right,
/// V: Top/Middle/Bottom), modeled on `BrowserFontSizeContextMenuItemNode` (background + touch-highlight overlay
/// + separators per button, `updateTheme` re-applying colors, `updateLayout` returning a fixed-height control).
/// The current selection (seeded from `item.initialHorizontal`/`initialVertical`) is shown via accent color +
/// semibold weight; `nil` (mixed across the selected cells) shows no highlighted segment in that row. A tap on a
/// horizontal button reports only the horizontal axis (`item.action(h, nil)`); a vertical tap reports only the
/// vertical axis (`item.action(nil, v)`) — the other axis is left unchanged by the caller's `apply`.
private final class TableStructuralMenuAlignmentItemNode: ASDisplayNode, ContextMenuCustomNode {
    private var presentationData: PresentationData
    let item: TableStructuralMenuAlignmentItem

    let needsPadding: Bool = false

    private var currentHorizontal: TableHorizontalAlignment?
    private var currentVertical: TableVerticalAlignment?

    private let horizontalButtons: [AlignmentSegmentButtonNode]
    private let verticalButtons: [AlignmentSegmentButtonNode]
    private let rowSeparatorNode: ASDisplayNode
    private let horizontalDividerNodes: [ASDisplayNode]
    private let verticalDividerNodes: [ASDisplayNode]

    private var validLayout: (constrainedWidth: CGFloat, constrainedHeight: CGFloat, resultSize: CGSize)?

    init(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void, item: TableStructuralMenuAlignmentItem) {
        self.presentationData = presentationData
        self.item = item
        self.currentHorizontal = item.initialHorizontal
        self.currentVertical = item.initialVertical

        self.horizontalButtons = alignmentMenuHorizontalTitles.map { AlignmentSegmentButtonNode(accessibilityLabel: $0) }
        self.verticalButtons = alignmentMenuVerticalTitles.map { AlignmentSegmentButtonNode(accessibilityLabel: $0) }

        self.rowSeparatorNode = ASDisplayNode()
        self.rowSeparatorNode.isAccessibilityElement = false

        self.horizontalDividerNodes = (0 ..< 2).map { _ in
            let node = ASDisplayNode()
            node.isAccessibilityElement = false
            return node
        }
        self.verticalDividerNodes = (0 ..< 2).map { _ in
            let node = ASDisplayNode()
            node.isAccessibilityElement = false
            return node
        }

        super.init()

        self.isUserInteractionEnabled = true

        self.horizontalButtons.forEach(self.addSubnode(_:))
        self.verticalButtons.forEach(self.addSubnode(_:))
        self.addSubnode(self.rowSeparatorNode)
        self.horizontalDividerNodes.forEach(self.addSubnode(_:))
        self.verticalDividerNodes.forEach(self.addSubnode(_:))

        for (index, button) in self.horizontalButtons.enumerated() {
            let value = alignmentMenuHorizontalValues[index]
            button.pressed = { [weak self] in
                guard let self else {
                    return
                }
                self.currentHorizontal = value
                self.item.action(value, nil)
                self.applyStyles()
            }
        }
        for (index, button) in self.verticalButtons.enumerated() {
            let value = alignmentMenuVerticalValues[index]
            button.pressed = { [weak self] in
                guard let self else {
                    return
                }
                self.currentVertical = value
                self.item.action(nil, value)
                self.applyStyles()
            }
        }

        self.applyStyles()
    }

    override func didLoad() {
        super.didLoad()
    }

    func updateTheme(presentationData: PresentationData) {
        self.presentationData = presentationData
        self.applyStyles()
        if let validLayout = self.validLayout {
            let (_, apply) = self.updateLayout(constrainedWidth: validLayout.constrainedWidth, constrainedHeight: validLayout.constrainedHeight)
            apply(validLayout.resultSize, .immediate)
        }
    }

    private func applyStyles() {
        let theme = self.presentationData.theme

        self.rowSeparatorNode.backgroundColor = theme.contextMenu.itemSeparatorColor
        self.horizontalDividerNodes.forEach { $0.backgroundColor = theme.contextMenu.itemSeparatorColor }
        self.verticalDividerNodes.forEach { $0.backgroundColor = theme.contextMenu.itemSeparatorColor }

        for (index, button) in self.horizontalButtons.enumerated() {
            let isSelected = self.currentHorizontal == alignmentMenuHorizontalValues[index]
            button.update(
                title: alignmentMenuHorizontalTitles[index],
                isSelected: isSelected,
                backgroundColor: theme.contextMenu.itemBackgroundColor,
                highlightedBackgroundColor: theme.contextMenu.itemHighlightedBackgroundColor,
                normalTextColor: theme.contextMenu.primaryColor,
                selectedTextColor: theme.list.itemAccentColor
            )
        }
        for (index, button) in self.verticalButtons.enumerated() {
            let isSelected = self.currentVertical == alignmentMenuVerticalValues[index]
            button.update(
                title: alignmentMenuVerticalTitles[index],
                isSelected: isSelected,
                backgroundColor: theme.contextMenu.itemBackgroundColor,
                highlightedBackgroundColor: theme.contextMenu.itemHighlightedBackgroundColor,
                normalTextColor: theme.contextMenu.primaryColor,
                selectedTextColor: theme.list.itemAccentColor
            )
        }
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let rowHeight: CGFloat = 44.0
        let totalHeight = rowHeight * 2.0 + UIScreenPixel
        let size = CGSize(width: constrainedWidth, height: totalHeight)

        return (size, { size, transition in
            self.validLayout = (constrainedWidth, constrainedHeight, size)

            let buttonWidth = floorToScreenPixels(size.width / 3.0)

            func frame(forIndex index: Int, y: CGFloat, height: CGFloat) -> CGRect {
                let x = index == 2 ? buttonWidth * 2.0 : buttonWidth * CGFloat(index)
                let width = index == 2 ? size.width - x : buttonWidth
                return CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
            }

            for (index, button) in self.horizontalButtons.enumerated() {
                let buttonFrame = frame(forIndex: index, y: 0.0, height: rowHeight)
                transition.updateFrame(node: button, frame: buttonFrame)
                button.updateLayout(size: buttonFrame.size)
            }
            for (index, divider) in self.horizontalDividerNodes.enumerated() {
                transition.updateFrame(node: divider, frame: CGRect(origin: CGPoint(x: buttonWidth * CGFloat(index + 1), y: 0.0), size: CGSize(width: UIScreenPixel, height: rowHeight)))
            }

            transition.updateFrame(node: self.rowSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: rowHeight), size: CGSize(width: size.width, height: UIScreenPixel)))

            let secondRowY = rowHeight + UIScreenPixel
            for (index, button) in self.verticalButtons.enumerated() {
                let buttonFrame = frame(forIndex: index, y: secondRowY, height: rowHeight)
                transition.updateFrame(node: button, frame: buttonFrame)
                button.updateLayout(size: buttonFrame.size)
            }
            for (index, divider) in self.verticalDividerNodes.enumerated() {
                transition.updateFrame(node: divider, frame: CGRect(origin: CGPoint(x: buttonWidth * CGFloat(index + 1), y: secondRowY), size: CGSize(width: UIScreenPixel, height: rowHeight)))
            }
        })
    }

    func canBeHighlighted() -> Bool {
        return false
    }

    func updateIsHighlighted(isHighlighted: Bool) {
    }

    func performAction() {
    }
}
