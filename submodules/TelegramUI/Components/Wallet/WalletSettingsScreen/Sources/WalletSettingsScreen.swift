import Foundation
import UIKit
import Display
import AccountContext
import WalletContext
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import ListSectionComponent
import ListActionItemComponent
import PresentationDataUtils

private final class WalletSettingsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext

    init(context: AccountContext, walletContext: WalletContext) {
        self.context = context
        self.walletContext = walletContext
    }

    static func ==(lhs: WalletSettingsScreenComponent, rhs: WalletSettingsScreenComponent) -> Bool {
        return lhs.context === rhs.context && lhs.walletContext === rhs.walletContext
    }

    final class View: UIView {
        private let scrollView: UIScrollView
        private let recoverySection = ComponentView<Empty>()
        private let backupSection = ComponentView<Empty>()
        private let deleteSection = ComponentView<Empty>()

        private var component: WalletSettingsScreenComponent?
        private var environment: EnvironmentType?
        private weak var state: EmptyComponentState?
        private let operationDisposable = MetaDisposable()

        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = true
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.alwaysBounceVertical = true

            super.init(frame: frame)

            self.addSubview(self.scrollView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.operationDisposable.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }

        private func openRecoveryPhrase() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.push(component.context.sharedContext.makeWalletInfoScreen(
                context: component.context,
                mode: .recovery,
                completion: { [weak self] in
                    guard let self, let component = self.component, let controller = self.environment?.controller() else {
                        return
                    }
                    component.context.sharedContext.authorizeWalletAccess(context: component.context, completion: { [weak self, weak controller] authorized in
                        guard authorized, let self, let controller else {
                            return
                        }
                        self.operationDisposable.set((component.walletContext.recoveryPhrase()
                        |> deliverOnMainQueue).start(next: { words in
                            controller.push(component.context.sharedContext.makeWalletWordsScreen(
                                context: component.context,
                                words: words,
                                verify: false,
                                completion: nil
                            ))
                        }, error: { [weak self] _ in
                            self?.presentRecoveryPhraseError()
                        }))
                    })
                }
            ))
        }

        private func presentRecoveryPhraseError() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.present(textAlertController(
                context: component.context,
                title: "Couldn’t Show Recovery Phrase",
                text: "Telegram couldn’t unlock the local wallet secret. Unlock the device and try again.",
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {
                })]
            ), in: .window(.root))
        }

        private func presentDisableBackupAlert() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }

            //TODO:localize
            let title = "Disable Backup?"
            //TODO:localize
            let text = "If you disable backup, you may lose access to your funds. The only way to recover your wallet will be to manually enter your recovery phrase."
            //TODO:localize
            let cancelTitle = "Cancel"
            //TODO:localize
            let disableTitle = "Disable"

            controller.present(textAlertController(
                context: component.context,
                title: title,
                text: text,
                actions: [
                    TextAlertAction(type: .genericAction, title: cancelTitle, action: {
                    }),
                    TextAlertAction(type: .destructiveAction, title: disableTitle, action: {
                    })
                ]
            ), in: .window(.root))
        }

        private func presentDeleteWalletAlert() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }

            //TODO:localize
            let title = "Delete Wallet?"
            //TODO:localize
            let text = "You'll lose access to your funds unless you've saved your 12- or 24-word recovery phrase."
            //TODO:localize
            let cancelTitle = "Cancel"
            //TODO:localize
            let deleteTitle = "Delete Anyway"

            let alertController = textAlertController(
                context: component.context,
                title: title,
                text: text,
                actions: [
                    TextAlertAction(type: .genericAction, title: cancelTitle, action: {
                    }),
                    TextAlertAction(type: .destructiveAction, title: deleteTitle, action: { [weak self] in
                        guard let self, let component = self.component, let controller = self.environment?.controller() else {
                            return
                        }
                        component.context.sharedContext.authorizeWalletAccess(context: component.context, completion: { [weak self, weak controller] authorized in
                            guard authorized, let self, let controller else {
                                return
                            }
                            self.operationDisposable.set((component.walletContext.deleteWallet()
                            |> deliverOnMainQueue).start(next: {
                                controller.dismiss()
                            }, error: { _ in
                                
                            }))
                        })
                    })
                ]
            )
            controller.present(alertController, in: .window(.root))
        }

        func update(
            component: WalletSettingsScreenComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            self.component = component
            self.environment = environment
            self.state = state

            let theme = environment.theme
            self.backgroundColor = theme.list.blocksBackgroundColor

            //TODO:localize
            let recoveryHeader = "Recovery Phrase"
            //TODO:localize
            let recoveryAction = "Show Recovery Phrase"
            //TODO:localize
            let recoveryFooter = "You can transfer your wallet to another device by copying your 12- or 24-word recovery phrase."
            //TODO:localize
            let backupHeader = "Encrypted Backup"
            //TODO:localize
            let disableBackupAction = "Disable Backup"
            //TODO:localize
            let backupFooter = "Telegram stores an encrypted backup of your keys, split across several datacenters. No Telegram employee can access them."
            //TODO:localize
            let deleteWalletAction = "Delete Wallet"

            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let headerFont = Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize)
            let footerFont = Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize)
            let actionFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)
            let sideInset = 16.0 + max(environment.safeInsets.left, environment.safeInsets.right)
            let sectionSpacing: CGFloat = 24.0
            let sectionWidth = availableSize.width - sideInset * 2.0
            var contentHeight = environment.navigationHeight + 16.0

            self.recoverySection.parentState = self.state
            let recoverySectionSize = self.recoverySection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: recoveryHeader.uppercased(),
                            font: headerFont,
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: recoveryFooter,
                            font: footerFont,
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: [
                        AnyComponentWithIdentity(id: "showRecoveryPhrase", component: AnyComponent(ListActionItemComponent(
                            theme: theme,
                            style: .glass,
                            title: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: recoveryAction,
                                    font: actionFont,
                                    textColor: theme.list.itemAccentColor
                                )),
                                maximumNumberOfLines: 0
                            )),
                            accessory: nil,
                            action: { [weak self] _ in
                                self?.openRecoveryPhrase()
                            }
                        )))
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: sectionWidth, height: 10000.0)
            )
            if let recoverySectionView = self.recoverySection.view {
                if recoverySectionView.superview == nil {
                    self.scrollView.addSubview(recoverySectionView)
                }
                transition.setFrame(
                    view: recoverySectionView,
                    frame: CGRect(
                        origin: CGPoint(x: sideInset, y: contentHeight),
                        size: recoverySectionSize
                    )
                )
            }
            contentHeight += recoverySectionSize.height
            contentHeight += sectionSpacing

            self.backupSection.parentState = self.state
            let backupSectionSize = self.backupSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: backupHeader.uppercased(),
                            font: headerFont,
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: backupFooter,
                            font: footerFont,
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: [
                        AnyComponentWithIdentity(id: "disableBackup", component: AnyComponent(ListActionItemComponent(
                            theme: theme,
                            style: .glass,
                            title: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: disableBackupAction,
                                    font: actionFont,
                                    textColor: theme.list.itemDestructiveColor
                                )),
                                maximumNumberOfLines: 0
                            )),
                            accessory: nil,
                            action: { [weak self] _ in
                                self?.presentDisableBackupAlert()
                            }
                        )))
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: sectionWidth, height: 10000.0)
            )
            if let backupSectionView = self.backupSection.view {
                if backupSectionView.superview == nil {
                    self.scrollView.addSubview(backupSectionView)
                }
                transition.setFrame(
                    view: backupSectionView,
                    frame: CGRect(
                        origin: CGPoint(x: sideInset, y: contentHeight),
                        size: backupSectionSize
                    )
                )
            }
            contentHeight += backupSectionSize.height
            contentHeight += sectionSpacing

            self.deleteSection.parentState = self.state
            let deleteSectionSize = self.deleteSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: "deleteWallet", component: AnyComponent(ListActionItemComponent(
                            theme: theme,
                            style: .glass,
                            title: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: deleteWalletAction,
                                    font: actionFont,
                                    textColor: theme.list.itemDestructiveColor
                                )),
                                maximumNumberOfLines: 0
                            )),
                            accessory: nil,
                            action: { [weak self] _ in
                                self?.presentDeleteWalletAlert()
                            }
                        )))
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: sectionWidth, height: 10000.0)
            )
            if let deleteSectionView = self.deleteSection.view {
                if deleteSectionView.superview == nil {
                    self.scrollView.addSubview(deleteSectionView)
                }
                transition.setFrame(
                    view: deleteSectionView,
                    frame: CGRect(
                        origin: CGPoint(x: sideInset, y: contentHeight),
                        size: deleteSectionSize
                    )
                )
            }
            contentHeight += deleteSectionSize.height
            contentHeight += 24.0 + environment.safeInsets.bottom

            transition.setFrame(
                view: self.scrollView,
                frame: CGRect(origin: CGPoint(), size: availableSize)
            )
            let contentSize = CGSize(
                width: availableSize.width,
                height: max(contentHeight, availableSize.height + 1.0)
            )
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(
                top: environment.navigationHeight,
                left: 0.0,
                bottom: environment.safeInsets.bottom,
                right: 0.0
            )
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<EnvironmentType>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            component: self,
            availableSize: availableSize,
            state: state,
            environment: environment,
            transition: transition
        )
    }
}

public final class WalletSettingsScreen: ViewControllerComponentContainer {
    public init(context: AccountContext, walletContext: WalletContext) {
        //TODO:localize
        let title = "Keys & Backup"

        super.init(
            context: context,
            component: WalletSettingsScreenComponent(context: context, walletContext: walletContext),
            navigationBarAppearance: .default,
            theme: .default
        )

        self.title = title
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? WalletSettingsScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
