import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import ContextUI
import ChatPresentationInterfaceState
import ComponentFlow
import AccountContext
import AnimatedCountLabelNode
import GlassBackgroundComponent

final class AttachmentTextInputActionButtonsNode: ASDisplayNode, ChatSendMessageActionSheetControllerSourceSendButtonNode {
    private let strings: PresentationStrings
    private let glass: Bool
    
    let sendContainerNode: ASDisplayNode
    let backgroundView: GlassBackgroundView?
    let backgroundNode: ASDisplayNode?
    let sendButton: HighlightTrackingButtonNode
    var sendButtonHasApplyIcon = false
    var animatingSendButton = false
    let textNode: ImmediateAnimatedCountLabelNode
    
    private var theme: PresentationTheme

    var sendButtonLongPressed: ((ASDisplayNode, ContextGesture) -> Void)?
    
    private var gestureRecognizer: ContextGesture?
    var sendButtonLongPressEnabled = false {
        didSet {
            self.gestureRecognizer?.isEnabled = self.sendButtonLongPressEnabled
        }
    }
    
    private var sendButtonPointerInteraction: PointerInteraction?
        
    private var validLayout: CGSize?
    
    init(presentationInterfaceState: ChatPresentationInterfaceState, glass: Bool, presentController: @escaping (ViewController) -> Void) {
        self.theme = presentationInterfaceState.theme
        self.strings = presentationInterfaceState.strings
        self.glass = glass
                 
        self.sendContainerNode = ASDisplayNode()
        self.sendContainerNode.layer.allowsGroupOpacity = true
        
        if glass {
            self.backgroundView = GlassBackgroundView()
            self.backgroundNode = nil
        } else {
            self.backgroundNode = ASDisplayNode()
            self.backgroundNode?.backgroundColor = theme.chat.inputPanel.actionControlFillColor
            self.backgroundNode?.clipsToBounds = true
            self.backgroundView = nil
        }
        
        self.sendButton = HighlightTrackingButtonNode(pointerStyle: nil)
                
        self.textNode = ImmediateAnimatedCountLabelNode()
        self.textNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = [.button, .notEnabled]
        
        self.sendButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if !strongSelf.sendButtonLongPressEnabled {
                    if highlighted {
                        strongSelf.sendContainerNode.layer.removeAnimation(forKey: "opacity")
                        strongSelf.sendContainerNode.alpha = 0.4
                    } else {
                        strongSelf.sendContainerNode.alpha = 1.0
                        strongSelf.sendContainerNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    }
                } else {
                    if highlighted {
                        let transition: ComponentTransition = .easeInOut(duration: 0.4)
                        transition.setScale(layer: strongSelf.sendContainerNode.layer, scale: 0.75)
                    } else {
                        let transition: ComponentTransition = .easeInOut(duration: 0.25)
                        transition.setScale(layer: strongSelf.sendContainerNode.layer, scale: 1.0)
                    }
                }
            }
        }
        
        self.addSubnode(self.sendContainerNode)
        if let backgroundView = self.backgroundView {
            self.sendContainerNode.view.addSubview(backgroundView)
        } else if let backgroundNode = self.backgroundNode {
            self.sendContainerNode.addSubnode(backgroundNode)
        }
        self.sendContainerNode.addSubnode(self.sendButton)
        self.sendContainerNode.addSubnode(self.textNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let gestureRecognizer = ContextGesture(target: nil, action: nil)
        gestureRecognizer.isEnabled = self.sendButtonLongPressEnabled
        self.gestureRecognizer = gestureRecognizer
        self.sendButton.view.addGestureRecognizer(gestureRecognizer)
        gestureRecognizer.activated = { [weak self] recognizer, _ in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.sendButtonHasApplyIcon {
                strongSelf.sendButtonLongPressed?(strongSelf, recognizer)
            }
        }
        
        if let backgroundNode = self.backgroundNode {
            self.sendButtonPointerInteraction = PointerInteraction(view: self.sendButton.view, customInteractionView: backgroundNode.view, style: .lift)
        }
    }
    
    func updateTheme(theme: PresentationTheme, wallpaper: TelegramWallpaper) {
        self.backgroundNode?.backgroundColor = theme.chat.inputPanel.actionControlFillColor
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        self.absoluteRect = (rect, containerSize)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition, minimized: Bool, text: String, interfaceState: ChatPresentationInterfaceState) -> CGSize {
        self.validLayout = size
        
        let width: CGFloat
        
        var titleOffset: CGFloat = 0.0
        var segments: [AnimatedCountLabelNode.Segment] = []
        var buttonInset: CGFloat = 18.0
        if text.hasPrefix("⭐️") {
            let font = Font.with(size: 17.0, design: .round, weight: .semibold, traits: .monospacedNumbers)
            let badgeString = NSMutableAttributedString(string: "⭐️ ", font: font, textColor: interfaceState.theme.chat.inputPanel.actionControlForegroundColor)
            if let range = badgeString.string.range(of: "⭐️") {
                badgeString.addAttribute(.attachment, value: PresentationResourcesChat.chatPlaceholderStarIcon(interfaceState.theme)!, range: NSRange(range, in: badgeString.string))
                badgeString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: badgeString.string))
            }
            segments.append(.text(0, badgeString))
            for char in text {
                if let intValue = Int(String(char)) {
                    segments.append(.number(intValue, NSAttributedString(string: String(char), font: font, textColor: interfaceState.theme.chat.inputPanel.actionControlForegroundColor)))
                }
            }
            titleOffset -= 2.0
            buttonInset = 14.0
        } else {
            segments.append(.text(0, NSAttributedString(string: text, font: Font.semibold(17.0), textColor: interfaceState.theme.chat.inputPanel.actionControlForegroundColor)))
        }
        self.textNode.segments = segments
        
        let textSize = self.textNode.updateLayout(size: CGSize(width: 100.0, height: 100.0), animated: transition.isAnimated)
        if minimized {
            width = 53.0
        } else {
            width = textSize.width + buttonInset * 2.0
        }
        
        let buttonSize = CGSize(width: width, height: size.height)
        
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((width - textSize.width) / 2.0) + titleOffset, y: floorToScreenPixels((buttonSize.height - textSize.height) / 2.0)), size: textSize))
        transition.updateAlpha(node: self.textNode, alpha: minimized ? 0.0 : 1.0)
        transition.updateAlpha(node: self.sendButton.imageNode, alpha: minimized ? 1.0 : 0.0)
        
        transition.updateFrame(layer: self.sendButton.layer, frame: CGRect(origin: CGPoint(), size: buttonSize))
        transition.updateFrame(node: self.sendContainerNode, frame: CGRect(origin: CGPoint(), size: buttonSize))
        
        if let backgroundView = self.backgroundView {
            let backgroundSize = CGSize(width: width - 13.0, height: 40.0)
            let backgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - backgroundSize.width) / 2.0), y: floorToScreenPixels((size.height - backgroundSize.height) / 2.0)), size: backgroundSize)
            transition.updateFrame(view: backgroundView, frame: backgroundFrame)
            backgroundView.update(size: backgroundSize, cornerRadius: backgroundSize.height * 0.5, isDark: false, tintColor: .init(kind: .custom, color: self.theme.chat.inputPanel.actionControlFillColor), transition: ComponentTransition(transition))
        } else if let backgroundNode {
            let backgroundSize = CGSize(width: width - 11.0, height: 33.0)
            transition.updateFrame(node: backgroundNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((width - backgroundSize.width) / 2.0), y: floorToScreenPixels((size.height - backgroundSize.height) / 2.0)), size: backgroundSize))
            backgroundNode.cornerRadius = backgroundSize.height / 2.0
        }
        
        return buttonSize
    }
    
    func updateAccessibility() {
        self.accessibilityTraits = .button
        self.accessibilityLabel = self.strings.MediaPicker_Send
        self.accessibilityHint = nil
    }
    
    func makeCustomContents() -> UIView? {
        if !self.textNode.alpha.isZero {
            let textView = ImmediateTextView()
            textView.attributedText = NSAttributedString(string: self.strings.MediaPicker_Send, font: Font.semibold(17.0), textColor: self.theme.chat.inputPanel.actionControlForegroundColor)
            let textSize = textView.updateLayout(CGSize(width: 100.0, height: 100.0))
            let _ = textSize
            textView.frame = self.textNode.frame
            return textView
        }
        return nil
    }
}
