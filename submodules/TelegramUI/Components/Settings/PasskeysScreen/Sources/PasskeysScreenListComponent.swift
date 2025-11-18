import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import AccountContext
import LottieComponent
import MultilineTextComponent
import BalancedTextComponent
import ButtonComponent
import BundleIconComponent
import ListSectionComponent
import ListActionItemComponent
import TelegramCore

final class PasskeysScreenListComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let insets: UIEdgeInsets
    let passkeys: [TelegramPasskey]
    let deletePasskeyAction: (String) -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        insets: UIEdgeInsets,
        passkeys: [TelegramPasskey],
        deletePasskeyAction: @escaping (String) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.insets = insets
        self.passkeys = passkeys
        self.deletePasskeyAction = deletePasskeyAction
    }
    
    static func ==(lhs: PasskeysScreenListComponent, rhs: PasskeysScreenListComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.passkeys != rhs.passkeys {
            return false
        }
        return true
    }
    
    private final class ScrollViewImpl: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollViewImpl
        private let contentContainer: UIView

        private let icon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let listSection = ComponentView<Empty>()

        private var component: PasskeysScreenListComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.scrollView = ScrollViewImpl()
            self.contentContainer = UIView()
            self.scrollView.addSubview(self.contentContainer)

            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            self.addSubview(self.scrollView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func update(component: PasskeysScreenListComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            self.backgroundColor = component.theme.list.blocksBackgroundColor

            let sideInset: CGFloat = 16.0 + component.insets.left

            var contentHeight: CGFloat = 0.0
            contentHeight += component.insets.top
            contentHeight += 8.0

            //TODO:localize
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "TwoFactorSetupIntro"),
                    loop: false
                )),
                environment: {},
                containerSize: CGSize(width: 124.0, height: 124.0)
            )
            let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: contentHeight), size: iconSize)
            if let iconView = self.icon.view as? LottieComponent.View {
                if iconView.superview == nil {
                    self.contentContainer.addSubview(iconView)
                    iconView.playOnce()
                }
                transition.setPosition(view: iconView, position: iconFrame.center)
                iconView.bounds = CGRect(origin: CGPoint(), size: iconFrame.size)
            }
            contentHeight += iconSize.height
            contentHeight += 10.0

            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "Passkeys", font: Font.bold(27.0), textColor: component.theme.list.itemPrimaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: contentHeight), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.contentContainer.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.center)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            contentHeight += titleSize.height
            contentHeight += 10.0
            
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(string: "Log in safely and keep your account secure.", font: Font.regular(16.0), textColor: component.theme.list.itemPrimaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - subtitleSize.width) * 0.5), y: contentHeight), size: subtitleSize)
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.contentContainer.addSubview(subtitleView)
                }
                transition.setPosition(view: subtitleView, position: subtitleFrame.center)
                subtitleView.bounds = CGRect(origin: CGPoint(), size: subtitleFrame.size)
            }
            contentHeight += subtitleSize.height
            contentHeight += 32.0
            
            var listSectionItems: [AnyComponentWithIdentity<Empty>] = []
            for passkey in component.passkeys {
                if listSectionItems.contains(where: { $0.id == AnyHashable(passkey.id) }) {
                    continue
                }
                let passkeyId = passkey.id
                let dateFormatter = DateFormatter()
                dateFormatter.timeStyle = .none
                dateFormatter.dateStyle = .medium
                let dateString = dateFormatter.string(from: Date(timeIntervalSince1970: Double(passkey.date)))
                
                listSectionItems.append(AnyComponentWithIdentity(id: passkey.id, component: AnyComponent(ListActionItemComponent(
                    theme: component.theme,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: passkey.name,
                                font: Font.regular(17.0),
                                textColor: component.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))),
                        AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "created \(dateString)",
                                font: Font.regular(14.0),
                                textColor: component.theme.list.itemSecondaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        )))
                    ], alignment: .left, spacing: 2.0)),
                    leftIcon: .custom(
                        AnyComponentWithIdentity(
                            id: "icon",
                            component: AnyComponent(BundleIconComponent(name: "Settings/Menu/TwoStepAuth", tintColor: nil))
                        ),
                        false
                    ),
                    accessory: nil,
                    action: { [weak self] _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.deletePasskeyAction(passkeyId)
                    },
                    highlighting: .default
                ))))
            }
            
            //TODO:localize
            let listSectionSize = self.listSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: component.theme,
                    style: .glass,
                    header: nil,
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "Your passkeys are stored securely in your password manager.",
                            font: Font.regular(13.0),
                            textColor: component.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: listSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let listSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: listSectionSize)
            if let listSectionView = self.listSection.view as? ListSectionComponent.View {
                if listSectionView.superview == nil {
                    self.contentContainer.addSubview(listSectionView)
                    self.listSection.parentState = state
                }
                transition.setFrame(view: listSectionView, frame: listSectionFrame)
            }
            contentHeight += listSectionSize.height
            contentHeight += 8.0
            contentHeight += component.insets.bottom

            let contentContainerFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: contentHeight))
            transition.setFrame(view: self.contentContainer, frame: contentContainerFrame)

            self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            let scrollContentSize = CGSize(width: availableSize.width, height: contentContainerFrame.maxY)
            if self.scrollView.contentSize != scrollContentSize {
                self.scrollView.contentSize = scrollContentSize
            }
            let scrollInsets = UIEdgeInsets(top: component.insets.top, left: 0.0, bottom: 0.0, right: 0.0)
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
