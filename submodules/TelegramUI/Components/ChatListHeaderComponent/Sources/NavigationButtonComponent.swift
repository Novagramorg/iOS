import Foundation
import UIKit
import ComponentFlow
import ChatListTitleView
import TelegramPresentationData
import Display
import MoreHeaderButton

public final class NavigationButtonComponentEnvironment: Equatable {
    public let theme: PresentationTheme
    
    public init(theme: PresentationTheme) {
        self.theme = theme
    }
    
    public static func ==(lhs: NavigationButtonComponentEnvironment, rhs: NavigationButtonComponentEnvironment) -> Bool {
        if lhs.theme != rhs.theme {
            return false
        }
        return true
    }
}

public final class NavigationButtonComponent: Component {
    public typealias EnvironmentType = NavigationButtonComponentEnvironment
    
    public enum Content: Equatable {
        case text(title: String, isBold: Bool)
        case more
        case icon(imageName: String)
        case systemIcon(name: String)
        case iconTinted(imageName: String, accent: Bool)
        // Fenixuz: renders a bundle PDF asset in original (untinted) colours.
        // Used for the ghost-ON state where the purple+dark-eyes fill must be preserved.
        case iconOriginal(imageName: String)
        case proxy(status: ChatTitleProxyStatus)
    }
    
    public let content: Content
    public let pressed: (UIView) -> Void
    public let contextAction: ((UIView, ContextGesture?) -> Void)?
    
    public init(
        content: Content,
        pressed: @escaping (UIView) -> Void,
        contextAction: ((UIView, ContextGesture?) -> Void)? = nil
    ) {
        self.content = content
        self.pressed = pressed
        self.contextAction = contextAction
    }
    
    public static func ==(lhs: NavigationButtonComponent, rhs: NavigationButtonComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        return true
    }
    
    public final class View: HighlightTrackingButton {
        private var textView: ImmediateTextView?
        
        private var iconView: UIImageView?
        private var iconImageName: String?
        
        private var proxyNode: ChatTitleProxyNode?
        
        private var moreButton: MoreHeaderButton?
        
        private var component: NavigationButtonComponent?
        private var theme: PresentationTheme?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if highlighted {
                    self.textView?.alpha = 0.6
                    self.proxyNode?.alpha = 0.6
                    self.iconView?.alpha = 0.6
                } else {
                    self.textView?.alpha = 1.0
                    self.textView?.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
                    
                    self.proxyNode?.alpha = 1.0
                    self.proxyNode?.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
                    
                    self.iconView?.alpha = 1.0
                    self.iconView?.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
                }
            }
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            // Fenixuz: light haptic for Fenixuz-added icon button types (iconOriginal, iconTinted, systemIcon).
            switch self.component?.content {
            case .iconOriginal, .iconTinted, .systemIcon:
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            default:
                break
            }
            self.component?.pressed(self)
        }
        
        func update(component: NavigationButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<NavigationButtonComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let theme = environment[NavigationButtonComponentEnvironment.self].value.theme
            var themeUpdated = false
            if self.theme !== theme {
                self.theme = theme
                themeUpdated = true
            }
            
            var textString: NSAttributedString?
            var imageName: String?
            var systemIconName: String?
            var iconAccent: Bool = false
            var iconOriginal: Bool = false
            var proxyStatus: ChatTitleProxyStatus?
            var isMore: Bool = false

            switch component.content {
            case let .text(title, isBold):
                textString = NSAttributedString(string: title, font: isBold ? Font.bold(17.0) : Font.medium(17.0), textColor: theme.chat.inputPanel.panelControlColor)
            case .more:
                isMore = true
            case let .icon(imageNameValue):
                imageName = imageNameValue
            case let .systemIcon(name):
                systemIconName = name
            case let .iconTinted(imageNameValue, accent):
                imageName = imageNameValue
                iconAccent = accent
            case let .iconOriginal(imageNameValue):
                // Fenixuz: render asset with .alwaysOriginal so multicolor PDFs keep their colours.
                imageName = imageNameValue
                iconOriginal = true
            case let .proxy(status):
                proxyStatus = status
            }
            
            var size = CGSize(width: 0.0, height: availableSize.height)
            
            if let textString = textString {
                let textView: ImmediateTextView
                if let current = self.textView {
                    textView = current
                } else {
                    textView = ImmediateTextView()
                    textView.isUserInteractionEnabled = false
                    self.textView = textView
                    self.addSubview(textView)
                }
                
                textView.attributedText = textString
                let textSize = textView.updateLayout(availableSize)
                let textInset: CGFloat = 12.0
                size.width = max(44.0, textSize.width + textInset * 2.0)
                
                textView.frame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: floor((availableSize.height - textSize.height) / 2.0)), size: textSize)
            } else if let textView = self.textView {
                self.textView = nil
                textView.removeFromSuperview()
            }
            
            if imageName != nil || systemIconName != nil {
                let iconView: UIImageView
                if let current = self.iconView {
                    iconView = current
                } else {
                    iconView = UIImageView()
                    iconView.isUserInteractionEnabled = false
                    self.iconView = iconView
                    self.addSubview(iconView)
                }
                // Accent tint marks an "active" toggle state (e.g. ghost mode ON); otherwise the
                // normal nav-bar control colour.
                let iconTintColor = iconAccent ? theme.list.itemAccentColor : theme.chat.inputPanel.panelControlColor
                // Cache key distinguishes bundle assets / SF Symbols / accent state / original flag so toggling re-renders.
                let cacheKey: String
                if iconOriginal {
                    cacheKey = (imageName ?? "") + ":original"
                } else {
                    cacheKey = (imageName ?? ("sys:" + (systemIconName ?? ""))) + (iconAccent ? ":accent" : "")
                }
                if self.iconImageName != cacheKey || themeUpdated {
                    self.iconImageName = cacheKey
                    if iconOriginal, let imageName = imageName {
                        // Fenixuz: preserve multicolor PDF colours (ghost-ON purple fill).
                        iconView.image = UIImage(bundleImageName: imageName)?.withRenderingMode(.alwaysOriginal)
                    } else if let imageName = imageName {
                        iconView.image = generateTintedImage(image: UIImage(bundleImageName: imageName), color: iconTintColor)
                    } else if let systemIconName = systemIconName {
                        let config = UIImage.SymbolConfiguration(pointSize: 20.0, weight: .medium)
                        iconView.image = UIImage(systemName: systemIconName, withConfiguration: config)?.withTintColor(iconTintColor, renderingMode: .alwaysOriginal)
                    }
                }

                if var iconSize = iconView.image?.size {
                    size.width = 44.0
                    // Fenixuz: clamp oversized PDF assets (e.g. FenixGhostActive/Inactive vector PDFs
                    // have a large native artboard). Only scale DOWN; small PNG icons are unaffected.
                    let maxIconDimension: CGFloat = 28.0
                    if max(iconSize.width, iconSize.height) > maxIconDimension {
                        let scale = maxIconDimension / max(iconSize.width, iconSize.height)
                        iconSize = CGSize(width: floor(iconSize.width * scale), height: floor(iconSize.height * scale))
                    }
                    iconView.contentMode = .scaleAspectFit
                    iconView.frame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: floor((availableSize.height - iconSize.height) / 2.0)), size: iconSize)
                }
            } else if let iconView = self.iconView {
                self.iconView = nil
                iconView.removeFromSuperview()
                self.iconImageName = nil
            }
            
            if let proxyStatus = proxyStatus {
                let proxyNode: ChatTitleProxyNode
                if let current = self.proxyNode {
                    proxyNode = current
                } else {
                    proxyNode = ChatTitleProxyNode(theme: theme)
                    proxyNode.isUserInteractionEnabled = false
                    self.proxyNode = proxyNode
                    self.addSubnode(proxyNode)
                }
                
                let proxySize = CGSize(width: 30.0, height: 30.0)
                size.width = 44.0
                
                proxyNode.theme = theme
                proxyNode.status = proxyStatus
                
                proxyNode.frame = CGRect(origin: CGPoint(x: floor((size.width - proxySize.width) / 2.0), y: floor((availableSize.height - proxySize.height) / 2.0)), size: proxySize)
            } else if let proxyNode = self.proxyNode {
                self.proxyNode = nil
                proxyNode.removeFromSupernode()
            }
            
            if isMore {
                let moreButton: MoreHeaderButton
                if let current = self.moreButton, !themeUpdated {
                    moreButton = current
                } else {
                    if let moreButton = self.moreButton {
                        moreButton.removeFromSupernode()
                        self.moreButton = nil
                    }
                    
                    moreButton = MoreHeaderButton(color: theme.chat.inputPanel.panelControlColor)
                    moreButton.isUserInteractionEnabled = true
                    moreButton.setContent(.more(MoreHeaderButton.optionsCircleImage(color: theme.chat.inputPanel.panelControlColor)))
                    moreButton.onPressed = { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        self.moreButton?.play()
                        component.pressed(self)
                    }
                    moreButton.contextAction = { [weak self] sourceNode, gesture in
                        guard let self, let component = self.component else {
                            return
                        }
                        self.moreButton?.play()
                        component.contextAction?(self, gesture)
                    }
                    self.moreButton = moreButton
                    self.addSubnode(moreButton)
                }
                
                let buttonSize = CGSize(width: 44.0, height: 44.0)
                size.width = 44.0
                
                moreButton.setContent(.more(MoreHeaderButton.optionsCircleImage(color: theme.rootController.navigationBar.buttonColor)))
                
                moreButton.frame = CGRect(origin: CGPoint(x: floor((size.width - buttonSize.width) / 2.0), y: floor((size.height - buttonSize.height) / 2.0)), size: buttonSize)
            } else if let moreButton = self.moreButton {
                self.moreButton = nil
                moreButton.removeFromSupernode()
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<NavigationButtonComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
