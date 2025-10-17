import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import GlassBackgroundComponent

final class StarReactionButtonComponent: Component {
    let theme: PresentationTheme
    let count: Int
    let isFilled: Bool
    let action: () -> Void
    
    init(
        theme: PresentationTheme,
        count: Int,
        isFilled: Bool,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.count = count
        self.isFilled = isFilled
        self.action = action
    }
    
    static func ==(lhs: StarReactionButtonComponent, rhs: StarReactionButtonComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.count != rhs.count {
            return false
        }
        if lhs.isFilled != rhs.isFilled {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let backgroundView: GlassBackgroundView
        private let iconView: UIImageView
        private let button: HighlightTrackingButton
        
        private var component: StarReactionButtonComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.backgroundView = GlassBackgroundView()
            self.iconView = UIImageView()
            self.button = HighlightTrackingButton()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.backgroundView.contentView.addSubview(self.iconView)
            self.backgroundView.contentView.addSubview(self.button)
            
            self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func buttonPressed() {
        }
        
        func update(component: StarReactionButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let size = CGSize(width: 40.0, height: 40.0)
            let backgroundFrame = CGRect(origin: CGPoint(), size: size)
            self.backgroundView.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel, color: component.theme.chat.inputPanel.inputBackgroundColor.withMultipliedAlpha(0.7)), isInteractive: true, transition: transition)
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            
            if self.iconView.image == nil {
                self.iconView.image = UIImage(bundleImageName: "Premium/Stars/ButtonStar")?.withRenderingMode(.alwaysTemplate)
            }
            
            self.iconView.tintColor = component.theme.chat.inputPanel.panelControlColor
            
            if let image = self.iconView.image {
                let iconFrame = image.size.centered(in: CGRect(origin: CGPoint(), size: backgroundFrame.size))
                transition.setFrame(view: self.iconView, frame: iconFrame)
            }
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
