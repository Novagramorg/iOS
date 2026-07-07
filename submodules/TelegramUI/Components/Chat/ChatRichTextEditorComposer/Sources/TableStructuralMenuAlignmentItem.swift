import Foundation
import UIKit
import Display
import ContextUI
import TelegramPresentationData
import RichTextEditorCore
import RichTextEditorUIKit
import TelegramCore
import AsyncDisplayKit
import ComponentFlow

final class TableStructuralMenuAlignmentItem: ContextMenuCustomItem {
    let action: (TableHorizontalAlignment, TableVerticalAlignment) -> Void
    
    init(action: @escaping (TableHorizontalAlignment, TableVerticalAlignment) -> Void) {
        self.action = action
    }
    
    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return TableStructuralMenuAlignmentItemNode(presentationData: presentationData, getController: getController, item: self)
    }
}

private final class TableStructuralMenuAlignmentItemNode: ASDisplayNode, ContextMenuCustomNode {
    private var presentationData: PresentationData
    let item: TableStructuralMenuAlignmentItem
    
    let needsPadding: Bool = false
    
    private var validLayout: (constrainedWidth: CGFloat, constrainedHeight: CGFloat, resultSize: CGSize)?

    init(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, item: TableStructuralMenuAlignmentItem) {
        self.presentationData = presentationData
        self.item = item
        
        super.init()
        
        self.isUserInteractionEnabled = true
    }
    
    override func didLoad() {
        super.didLoad()
    }
    
    func updateTheme(presentationData: PresentationData) {
        self.presentationData = presentationData
        if let validLayout = self.validLayout {
            let (_, apply) = self.updateLayout(constrainedWidth: validLayout.constrainedWidth, constrainedHeight: validLayout.constrainedHeight)
            apply(validLayout.resultSize, .immediate)
        }
    }
    
    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        return (CGSize(width: constrainedWidth, height: 68.0), { size, transition in
            self.validLayout = (constrainedWidth, constrainedHeight, size)
            self.backgroundColor = .blue
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
