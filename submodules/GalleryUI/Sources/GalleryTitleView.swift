import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import GlassBackgroundComponent
import ComponentFlow
import ComponentDisplayAdapters
import MultilineTextComponent

private let titleFont = Font.semibold(17.0)
private let dateFont = Font.regular(12.0)

final class GalleryTitleView: UIView, NavigationBarTitleView {    
    private let authorNameNode: ASTextNode
    private let dateNode: ASTextNode
    
    private let titleBackgroundContainer: GlassBackgroundContainerView
    private let titleBackground: GlassBackgroundView
    private let title = ComponentView<Empty>()
    
    private var titleString: String?
    
    var requestUpdate: ((ContainedViewLayoutTransition) -> Void)?
    
    override init(frame: CGRect) {
        self.authorNameNode = ASTextNode()
        self.authorNameNode.displaysAsynchronously = false
        self.authorNameNode.maximumNumberOfLines = 1
        
        self.dateNode = ASTextNode()
        self.dateNode.displaysAsynchronously = false
        self.dateNode.maximumNumberOfLines = 1
        
        self.titleBackgroundContainer = GlassBackgroundContainerView()
        self.titleBackground = GlassBackgroundView()
        
        self.titleBackgroundContainer.contentView.addSubview(self.titleBackground)
        
        super.init(frame: frame)
        
        self.addSubnode(self.authorNameNode)
        self.addSubnode(self.dateNode)
        
        self.addSubview(self.titleBackgroundContainer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setMessage(_ message: Message, presentationData: PresentationData, accountPeerId: PeerId, title: String?) {
        let authorNameText = stringForFullAuthorName(message: EngineMessage(message), strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, accountPeerId: accountPeerId)[0]//.joined(separator: " → ")
        let dateText = humanReadableStringForTimestamp(strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, timestamp: message.timestamp).string
        
        self.authorNameNode.attributedText = NSAttributedString(string: authorNameText, font: titleFont, textColor: .white)
        self.dateNode.attributedText = NSAttributedString(string: dateText, font: dateFont, textColor: UIColor(white: 1.0, alpha: 0.5))
        
        self.titleString = title
    }
    
    func updateLayout(availableSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = availableSize
        
        let leftInset: CGFloat = 0.0
        let rightInset: CGFloat = 0.0
        
        let authorNameSize = self.authorNameNode.measure(CGSize(width: max(1.0, size.width - 8.0 * 2.0 - leftInset - rightInset), height: CGFloat.greatestFiniteMagnitude))
        let dateSize = self.dateNode.measure(CGSize(width: max(1.0, size.width - 8.0 * 2.0), height: CGFloat.greatestFiniteMagnitude))
        
        if authorNameSize.height.isZero {
            self.dateNode.frame = CGRect(origin: CGPoint(x: floor((size.width - dateSize.width) / 2.0), y: floor((size.height - dateSize.height) / 2.0)), size: dateSize)
        } else {
            let labelsSpacing: CGFloat = 2.0
            self.authorNameNode.frame = CGRect(origin: CGPoint(x: floor((size.width - authorNameSize.width) / 2.0), y: floor((size.height - dateSize.height - authorNameSize.height - labelsSpacing) / 2.0)), size: authorNameSize)
            self.dateNode.frame = CGRect(origin: CGPoint(x: floor((size.width - dateSize.width) / 2.0), y: floor((size.height - dateSize.height - authorNameSize.height - labelsSpacing) / 2.0) + authorNameSize.height + labelsSpacing), size: dateSize)
        }
        
        let titleSize = self.title.update(
            transition: .immediate,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: self.titleString ?? "", font: Font.semibold(12.0), textColor: .white))
            )),
            environment: {},
            containerSize: CGSize(width: 200.0, height: 100.0)
        )
        let titleInset: CGFloat = 12.0
        let titleBackgroundSize = CGSize(width: titleInset * 2.0 + titleSize.width, height: 24.0)
        let titleBackgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleBackgroundSize.width) * 0.5), y: availableSize.height + 2.0), size: titleBackgroundSize)
        let titleFrame = titleSize.centered(in: CGRect(origin: CGPoint(), size: titleBackgroundSize))
        if let titleView = self.title.view {
            if titleView.superview == nil {
                self.titleBackground.contentView.addSubview(titleView)
            }
            titleView.frame = titleFrame
        }
        
        do {
            let transition = ComponentTransition.immediate
            transition.setFrame(view: self.titleBackgroundContainer, frame: titleBackgroundFrame)
            self.titleBackgroundContainer.update(size: titleBackgroundSize, isDark: true, transition: transition)
            
            transition.setFrame(view: self.titleBackground, frame: CGRect(origin: CGPoint(), size: titleBackgroundSize))
            self.titleBackground.update(size: titleBackgroundSize, cornerRadius: titleBackgroundSize.height * 0.5, isDark: true, tintColor: .init(kind: .panel), transition: transition)
            
            self.titleBackgroundContainer.isHidden = !(self.titleString != nil && self.titleString != "")
        }
        
        return availableSize
    }
    
    func animateLayoutTransition() {
        
    }
}
