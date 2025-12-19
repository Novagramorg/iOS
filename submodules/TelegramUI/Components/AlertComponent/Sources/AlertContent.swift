import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramPresentationData
import MultilineTextComponent
import Markdown
import TextFormat

private let titleFont = Font.bold(17.0)
private let defaultTextFont = Font.regular(15.0)
private let defaultBoldTextFont = Font.semibold(15.0)
private let smallTextFont = Font.regular(14.0)
private let smallBoldTextFont = Font.semibold(14.0)

public final class AlertTitleComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment
    
    let title: String
    
    public init(
        title: String
    ) {
        self.title = title
    }
    
    public static func ==(lhs: AlertTitleComponent, rhs: AlertTitleComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let title = ComponentView<Empty>()
        
        private var component: AlertTitleComponent?
        private weak var state: EmptyComponentState?
        
        func update(component: AlertTitleComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let environment = environment[AlertComponentEnvironment.self]
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.title,
                        font: titleFont,
                        textColor: environment.theme.actionSheet.primaryTextColor
                    )),
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: availableSize
            )
            let titleFrame = CGRect(origin: .zero, size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            return CGSize(width: availableSize.width, height: titleSize.height)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class AlertTextComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment
    
    public enum Content: Equatable {
        case plain(String)
        case attributed(NSAttributedString)
    }
    
    public enum Color {
        case primary
        case secondary
        case destructive
    }
    
    public enum TextSize {
        case `default`
        case small
    }
    
    let content: Content
    let color: Color
    let textSize: TextSize
    let action: ([NSAttributedString.Key: Any]) -> Void
    
    public init(
        content: Content,
        color: Color = .primary,
        textSize: TextSize = .default,
        action: @escaping ([NSAttributedString.Key: Any]) -> Void = { _ in }
    ) {
        self.content = content
        self.color = color
        self.textSize = textSize
        self.action = action
    }
    
    public static func ==(lhs: AlertTextComponent, rhs: AlertTextComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.textSize != rhs.textSize {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let text = ComponentView<Empty>()
        
        private var component: AlertTextComponent?
        private weak var state: EmptyComponentState?
        
        func update(component: AlertTextComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let environment = environment[AlertComponentEnvironment.self]
            
            let textColor: UIColor
            switch component.color {
            case .primary:
                textColor = environment.theme.actionSheet.primaryTextColor
            case .secondary:
                textColor = environment.theme.actionSheet.secondaryTextColor
            case .destructive:
                textColor = environment.theme.actionSheet.destructiveActionTextColor
            }
            let linkColor = environment.theme.actionSheet.controlAccentColor
            
            let textFont: UIFont
            let boldTextFont: UIFont
            switch component.textSize {
            case .default:
                textFont = defaultTextFont
                boldTextFont = defaultBoldTextFont
            case .small:
                textFont = smallTextFont
                boldTextFont = smallBoldTextFont
            }
            
            var finalText: NSAttributedString
            switch component.content {
            case let .plain(text):
                let markdownAttributes = MarkdownAttributes(
                    body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                    bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                    link: MarkdownAttributeSet(font: textFont, textColor: linkColor),
                    linkAttribute: { contents in
                        return (TelegramTextAttributes.URL, contents)
                    }
                )
                finalText = parseMarkdownIntoAttributedString(text, attributes: markdownAttributes)
            case let .attributed(attributedText):
                finalText = attributedText
            }
            
            let textSize = self.text.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(finalText),
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1,
                    highlightColor: linkColor.withAlphaComponent(0.2),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { attributes, _ in
                        component.action(attributes)
                    }
                )),
                environment: {},
                containerSize: availableSize
            )
            let textFrame = CGRect(origin: .zero, size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                transition.setFrame(view: textView, frame: textFrame)
            }
            return CGSize(width: availableSize.width, height: textSize.height)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
