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
import TelegramStringFormatting
import UndoUI

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
        private var isUpdating = false
        private let operationDisposable = MetaDisposable()
        private let backupOperationDisposable = MetaDisposable()
        private let walletStateDisposable = MetaDisposable()
        private var walletState: WalletContext.State?
        private weak var backupWordsController: ViewController?
        private var preparedBackupDisable: WalletContext.PreparedBackupDisable?

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
            self.backupOperationDisposable.dispose()
            self.walletStateDisposable.dispose()
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
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  self.walletState?.activeOperation == nil else {
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
                    TextAlertAction(type: .destructiveAction, title: disableTitle, action: { [weak self] in
                        self?.prepareDisableBackup()
                    })
                ]
            ), in: .window(.root))
        }

        private func prepareDisableBackup() {
            guard let component = self.component else {
                return
            }
            self.backupOperationDisposable.set((component.walletContext.prepareDisableBackup()
            |> deliverOnMainQueue).start(next: { [weak self] prepared in
                self?.presentUpdateSecretPhraseAlert(prepared: prepared)
            }, error: { [weak self] _ in
                self?.presentDisableBackupError(keepPhrase: false)
            }))
        }

        private func presentUpdateSecretPhraseAlert(prepared: WalletContext.PreparedBackupDisable) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let feeText = self.formattedFee(prepared.fee)
            //TODO:localize
            let text = "You'll get a new phrase to write down. Address and balance stay the same.\n\nNetwork fee: \(feeText)."
            controller.present(textAlertController(
                context: component.context,
                title: "Update Secret Phrase?",
                text: text,
                actions: [
                    TextAlertAction(type: .genericAction, title: "Not now", action: {
                    }),
                    TextAlertAction(type: .defaultAction, title: "Update", action: { [weak self] in
                        guard let self else {
                            return
                        }
                        if prepared.availableBalance < prepared.fee {
                            self.presentInsufficientBalanceAlert(prepared: prepared)
                        } else {
                            self.openReplacementPhrase(prepared: prepared)
                        }
                    })
                ]
            ), in: .window(.root))
        }

        private func presentInsufficientBalanceAlert(prepared: WalletContext.PreparedBackupDisable) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let feeText = self.formattedFee(prepared.fee)
            //TODO:localize
            let text = "You need \(feeText) to update your recovery phrase."
            controller.present(textAlertController(
                context: component.context,
                title: "Not enough Gram",
                text: text,
                actions: [
                    TextAlertAction(type: .genericAction, title: "Not now", action: {
                    }),
                    TextAlertAction(type: .defaultAction, title: "Top up", action: { [weak self] in
                        guard let self,
                              let component = self.component,
                              let controller = self.environment?.controller(),
                              let phase = self.walletState?.phase,
                              case let .wallet(info) = phase else {
                            return
                        }
                        controller.push(component.context.sharedContext.makeWalletReceiveScreen(
                            context: component.context,
                            address: info.address
                        ))
                    })
                ]
            ), in: .window(.root))
        }

        private func openReplacementPhrase(prepared: WalletContext.PreparedBackupDisable) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            self.preparedBackupDisable = prepared
            let wordsController = component.context.sharedContext.makeWalletWordsScreen(
                context: component.context,
                words: prepared.words,
                mode: .replacement,
                completion: { [weak self] in
                    self?.presentFinalDisableBackupAlert()
                }
            )
            self.backupWordsController = wordsController
            if let wordsController = wordsController as? ViewControllerComponentContainer {
                wordsController.wasDismissed = { [weak self, weak wordsController] in
                    Queue.mainQueue().justDispatch { [weak self, weak wordsController] in
                        guard let self,
                              self.preparedBackupDisable?.id == prepared.id else {
                            return
                        }
                        if let wordsController,
                           let navigationController = wordsController.navigationController,
                           navigationController.viewControllers.contains(where: { $0 === wordsController }) {
                            return
                        }
                        self.backupWordsController = nil
                        self.preparedBackupDisable = nil
                    }
                }
            }
            controller.push(wordsController)
        }

        private func presentFinalDisableBackupAlert() {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  let prepared = self.preparedBackupDisable else {
                return
            }
            let presentingController: ViewController
            if let topController = self.backupWordsController?.navigationController?.topViewController as? ViewController {
                presentingController = topController
            } else {
                presentingController = controller
            }
            presentingController.present(textAlertController(
                context: component.context,
                title: "Disable Backup?",
                text: "Telegram will delete its encrypted backup, and your recovery key will be updated. This can't be undone.",
                actions: [
                    TextAlertAction(type: .genericAction, title: "Cancel", action: { [weak self] in
                        self?.dismissBackupWordsFlow()
                    }),
                    TextAlertAction(type: .destructiveAction, title: "Disable", action: { [weak self] in
                        guard let self else {
                            return
                        }
                        component.context.sharedContext.authorizeWalletAccess(
                            context: component.context,
                            completion: { [weak self] authorized in
                                guard let self else {
                                    return
                                }
                                guard authorized else {
                                    self.dismissBackupWordsFlow()
                                    return
                                }
                                self.submitDisableBackup(prepared: prepared)
                            }
                        )
                    })
                ]
            ), in: .window(.root))
        }

        private func submitDisableBackup(prepared: WalletContext.PreparedBackupDisable) {
            guard let component = self.component else {
                return
            }
            self.backupOperationDisposable.set((component.walletContext.disableBackup(prepared)
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                guard let self else {
                    return
                }
                self.dismissBackupWordsFlow()
                self.presentBackupDisabledToast()
            }, error: { [weak self] error in
                guard let self else {
                    return
                }
                if case let .insufficientBalance(required) = error {
                    self.presentInsufficientBalanceAlert(prepared: WalletContext.PreparedBackupDisable(
                        id: prepared.id,
                        words: prepared.words,
                        fee: required,
                        availableBalance: 0,
                        expiresAt: prepared.expiresAt
                    ))
                } else {
                    self.presentDisableBackupError(keepPhrase: true)
                }
            }))
        }

        private func dismissBackupWordsFlow() {
            guard let wordsController = self.backupWordsController else {
                self.preparedBackupDisable = nil
                return
            }
            if let navigationController = wordsController.navigationController as? NavigationController,
               let index = navigationController.viewControllers.firstIndex(where: { $0 === wordsController }) {
                navigationController.setViewControllers(
                    Array(navigationController.viewControllers.prefix(upTo: index)),
                    animated: true
                )
            } else {
                wordsController.dismiss()
            }
            self.backupWordsController = nil
            self.preparedBackupDisable = nil
        }

        private func presentDisableBackupError(keepPhrase: Bool) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let text: String
            if keepPhrase {
                text = "Check the wallet balance and network connection, then try again. Keep the new recovery phrase until the wallet status is updated."
            } else {
                text = "Check the wallet balance and network connection, then try again."
            }
            controller.present(textAlertController(
                context: component.context,
                title: "Couldn't Disable Backup",
                text: text,
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {
                })]
            ), in: .window(.root))
        }

        private func formattedFee(_ fee: Int64) -> String {
            guard let component = self.component else {
                return ""
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let gramValue = formatTonAmountText(
                fee,
                dateTimeFormat: presentationData.dateTimeFormat,
                maxDecimalPositions: 9
            )
            if let walletState = self.walletState,
               let rate = walletState.fiat.selectedRate {
                let fiatValue = formatTonFiatValue(
                    fee,
                    divide: true,
                    rate: rate.unitsPerGram,
                    currencySymbol: walletState.fiat.selectedCurrency.symbol,
                    maxDecimalPositions: 4,
                    dateTimeFormat: presentationData.dateTimeFormat
                )
                return "\(gramValue) GRAM (≈\(fiatValue))"
            } else {
                return "\(gramValue) GRAM"
            }
        }

        private func presentBackupDisabledToast() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            controller.present(
                UndoOverlayController(
                    presentationData: presentationData,
                    content: .emoji(
                        name: "TwoFactorSetupRememberSuccess",
                        text: "Backup Disabled. Your recovery phrase is now the only way to restore your wallet."
                    ),
                    position: .bottom,
                    action: { _ in false }
                ),
                in: .current
            )
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
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            if self.backupWordsController == nil {
                self.preparedBackupDisable = nil
            }

            let environment = environment[EnvironmentType.self].value
            let previousWalletContext = self.component?.walletContext
            self.component = component
            self.environment = environment
            self.state = state

            if previousWalletContext !== component.walletContext {
                self.walletState = component.walletContext.stateValue
                self.walletStateDisposable.set((component.walletContext.state
                |> deliverOnMainQueue).start(next: { [weak self] walletState in
                    guard let self else {
                        return
                    }
                    self.walletState = walletState
                    if !self.isUpdating {
                        self.state?.updated(transition: .easeInOut(duration: 0.25))
                    }
                }))
            }

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
            let canDisableBackup: Bool
            if let phase = self.walletState?.phase, case let .wallet(info) = phase {
                canDisableBackup = info.canDisableBackup
            } else {
                canDisableBackup = false
            }

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

            if canDisableBackup {
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
            } else {
                self.backupSection.view?.removeFromSuperview()
            }

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
