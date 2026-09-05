import Foundation
import UIKit
import Display
import AccountContext
import WalletContext
import SwiftSignalKit
import TelegramNotices
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import ListSectionComponent
import ListActionItemComponent
import PresentationDataUtils
import TelegramStringFormatting
import AlertComponent
import UndoUI
import WalletAuthorizationUI

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
        private let replacementSection = ComponentView<Empty>()

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
        private weak var disableBackupPreparationController: AlertScreen?
        private var disableBackupPreparationProgress: ValuePromise<Bool>?
        private var isPreparingBackupDisable = false
        private weak var disableBackupConfirmationController: AlertScreen?
        private var disableBackupProgress: ValuePromise<Bool>?
        private var isDisablingBackup = false
        private weak var replacementOptionsController: AlertScreen?
        private var replacementCreationProgress: ValuePromise<Bool>?
        private var isCreatingReplacementWallet = false

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
                    let canRevealLocally: Bool
                    if let walletState = self.walletState, case let .wallet(info) = walletState.phase {
                        canRevealLocally = info.canSign
                    } else {
                        canRevealLocally = false
                    }
                    self.operationDisposable.set(performWalletAuthorizedOperation(
                        context: component.context,
                        present: { [weak controller] alert in
                            controller?.present(alert, in: .window(.root))
                        },
                        operation: { password in
                            component.walletContext.recoveryPhrase(password: password)
                        },
                        next: { words in
                            controller.push(component.context.sharedContext.makeWalletWordsScreen(
                                context: component.context,
                                words: words,
                                verify: false,
                                completion: nil
                            ))
                        },
                        failed: { [weak self] error in
                            self?.presentRecoveryPhraseError(error: error)
                        },
                        preauthorize: !canRevealLocally
                    ))
                }
            ))
        }

        private func presentRecoveryPhraseError(error: WalletContext.WalletError) {
            guard error != .authorizationCancelled else { return }
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let message = walletAuthorizationErrorMessage(error)
            controller.present(textAlertController(
                context: component.context,
                title: message?.title ?? "Couldn’t Show Recovery Phrase",
                text: message?.text ?? "Check the network connection and try again.",
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {
                })]
            ), in: .window(.root))
        }

        private func openRecoveryPhraseImport() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.push(component.context.sharedContext.makeWalletImportScreen(
                context: component.context,
                mode: .enterRecoveryPhrase,
                completion: { [weak self] in
                    self?.completeRecoveryPhraseImport()
                }
            ))
        }

        private func completeRecoveryPhraseImport() {
            guard let component = self.component,
                  let settingsController = self.environment?.controller(),
                  let navigationController = settingsController.navigationController as? NavigationController,
                  let settingsControllerIndex = navigationController.viewControllers.firstIndex(where: { $0 === settingsController }) else {
                return
            }
            let viewControllers = Array(navigationController.viewControllers.prefix(through: settingsControllerIndex))
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            navigationController.setViewControllers(viewControllers, animated: true)
            Queue.mainQueue().after(0.4) { [weak settingsController] in
                settingsController?.present(UndoOverlayController(
                    presentationData: presentationData,
                    content: .actionSucceeded(
                        title: "Wallet Imported",
                        text: "Your wallet was restored from your recovery phrase.",
                        cancel: nil,
                        destructive: false
                    ),
                    position: .bottom,
                    action: { _ in false }
                ), in: .current)
            }
        }

        private func presentDisableBackupAlert() {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  self.walletState?.activeOperation == nil,
                  !self.isPreparingBackupDisable else {
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

            let progress = ValuePromise<Bool>(false, ignoreRepeated: true)
            let actionsEnabled = progress.get() |> map { !$0 }
            let alertController = AlertScreen(
                context: component.context,
                configuration: AlertScreen.Configuration(dismissOnOutsideTap: false),
                content: [
                    AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(AlertTitleComponent(title: title))
                    ),
                    AnyComponentWithIdentity(
                        id: "text",
                        component: AnyComponent(AlertTextComponent(content: .plain(text)))
                    )
                ],
                actions: [
                    AlertScreen.Action(
                        title: cancelTitle,
                        action: {},
                        isEnabled: actionsEnabled
                    ),
                    AlertScreen.Action(
                        title: disableTitle,
                        type: .destructive,
                        action: { [weak self] in
                            self?.beginDisableBackupPreparation()
                        },
                        autoDismiss: false,
                        isEnabled: actionsEnabled,
                        progress: progress.get()
                    )
                ]
            )
            self.disableBackupPreparationController = alertController
            self.disableBackupPreparationProgress = progress
            alertController.dismissed = { [weak self, weak alertController] _ in
                guard let self, self.disableBackupPreparationController === alertController else {
                    return
                }
                self.disableBackupPreparationController = nil
                self.disableBackupPreparationProgress = nil
                self.isPreparingBackupDisable = false
            }
            controller.present(alertController, in: .window(.root))
        }

        private func beginDisableBackupPreparation() {
            guard self.walletState?.balance.currentValue != 0 else {
                let presentTopUp = { [weak self] in
                    self?.presentZeroBalanceAlert()
                }
                if let alertController = self.disableBackupPreparationController {
                    alertController.dismiss(completion: { presentTopUp() })
                } else {
                    presentTopUp()
                }
                return
            }
            self.prepareDisableBackup()
        }

        private func prepareDisableBackup() {
            guard !self.isPreparingBackupDisable,
                  let component = self.component else {
                return
            }
            self.isPreparingBackupDisable = true
            self.disableBackupPreparationProgress?.set(true)
            self.backupOperationDisposable.set((component.walletContext.prepareDisableBackup()
            |> deliverOnMainQueue).start(next: { [weak self] prepared in
                guard let self else {
                    return
                }
                self.isPreparingBackupDisable = false
                let presentNext = { [weak self] in
                    self?.presentUpdateSecretPhraseAlert(prepared: prepared)
                }
                if let alertController = self.disableBackupPreparationController {
                    alertController.dismiss(completion: { presentNext() })
                } else {
                    presentNext()
                }
            }, error: { [weak self] _ in
                guard let self else {
                    return
                }
                self.isPreparingBackupDisable = false
                self.disableBackupPreparationProgress?.set(false)
                self.presentDisableBackupError()
            }))
        }

        private func presentUpdateSecretPhraseAlert(prepared: WalletContext.PreparedBackupDisable) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            //TODO:localize
            var text = "You'll get a new phrase to write down. Address and balance stay the same."
            if let networkFeeNanograms = prepared.networkFeeNanograms {
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                let fee = formatTonAmountText(
                    networkFeeNanograms,
                    dateTimeFormat: presentationData.dateTimeFormat,
                    maxDecimalPositions: 5
                )
                var feeText = "Network fee: \(fee) Grams"
                if !"".isEmpty, let fiatRate = self.walletState?.fiat.selectedRate {
                    let fiatCurrency = self.walletState?.fiat.selectedCurrency ?? .usd
                    let fiatFee = formatTonFiatValue(
                        networkFeeNanograms,
                        rate: fiatRate.unitsPerGram,
                        currencySymbol: fiatCurrency.symbol,
                        maxDecimalPositions: 2,
                        dateTimeFormat: presentationData.dateTimeFormat
                    )
                    feeText += " (~\(fiatFee))"
                }
                text += "\n\n\(feeText)."
            }
            controller.present(textAlertController(
                context: component.context,
                title: "Update Secret Phrase?",
                text: text,
                actions: [
                    TextAlertAction(type: .genericAction, title: "Not now", action: {
                    }),
                    TextAlertAction(type: .defaultAction, title: "Update", action: { [weak self] in
                        Queue.mainQueue().after(0.2) { [weak self] in
                            self?.continueWithPreparedBackupDisable(prepared)
                        }
                    })
                ]
            ), in: .window(.root))
        }

        private func continueWithPreparedBackupDisable(_ prepared: WalletContext.PreparedBackupDisable) {
            guard let networkFeeNanograms = prepared.networkFeeNanograms else {
                self.openReplacementPhrase(prepared: prepared)
                return
            }
            guard let balance = self.walletState?.balance.currentValue else {
                self.presentDisableBackupError(error: .network)
                return
            }
            guard balance >= networkFeeNanograms else {
                self.presentInsufficientBalanceAlert(required: networkFeeNanograms)
                return
            }
            self.openReplacementPhrase(prepared: prepared)
        }

        private func presentInsufficientBalanceAlert(required: Int64) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let amount = formatTonAmountText(
                required,
                dateTimeFormat: presentationData.dateTimeFormat,
                maxDecimalPositions: 5
            )
            var amountText = "\(amount) GRAM"
            if let fiatRate = self.walletState?.fiat.selectedRate {
                let fiatCurrency = self.walletState?.fiat.selectedCurrency ?? .usd
                let fiatAmount = formatTonFiatValue(
                    required,
                    rate: fiatRate.unitsPerGram,
                    currencySymbol: fiatCurrency.symbol,
                    maxDecimalPositions: 2,
                    dateTimeFormat: presentationData.dateTimeFormat
                )
                amountText += " (~\(fiatAmount))"
            }
            controller.present(textAlertController(
                context: component.context,
                title: "Not enough Gram",
                text: "You need \(amountText) to update your recovery phrase.",
                actions: [
                    TextAlertAction(type: .genericAction, title: "Not now", action: {}),
                    TextAlertAction(type: .defaultAction, title: "Top up", action: { [weak self] in
                        Queue.mainQueue().after(0.2) { [weak self] in
                            self?.openBackupTopUp()
                        }
                    })
                ]
            ), in: .window(.root))
        }

        private func presentZeroBalanceAlert() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.present(textAlertController(
                context: component.context,
                title: "Not enough Gram",
                text: "You need to have non-zero balance to update your recovery phrase.",
                actions: [
                    TextAlertAction(type: .genericAction, title: "Not now", action: {}),
                    TextAlertAction(type: .defaultAction, title: "Top up", action: { [weak self] in
                        Queue.mainQueue().after(0.2) { [weak self] in
                            self?.openBackupTopUp()
                        }
                    })
                ]
            ), in: .window(.root))
        }

        private func openBackupTopUp() {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  let phase = self.walletState?.phase,
                  case let .wallet(info) = phase else {
                return
            }
            self.preparedBackupDisable = nil
            controller.push(component.context.sharedContext.makeWalletReceiveScreen(
                context: component.context,
                address: info.address
            ))
        }

        private func openReplacementPhrase(prepared: WalletContext.PreparedBackupDisable) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            self.preparedBackupDisable = prepared
            let wordsController = component.context.sharedContext.makeWalletWordsScreen(
                context: component.context,
                words: prepared.words,
                mode: .backupDisable,
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
                  let prepared = self.preparedBackupDisable,
                  let controller = self.backupWordsController?.navigationController?.topViewController as? ViewController
                    ?? self.environment?.controller() else {
                return
            }
            let progress = ValuePromise<Bool>(false, ignoreRepeated: true)
            let actionsEnabled = progress.get() |> map { !$0 }
            let alertController = AlertScreen(
                context: component.context,
                configuration: AlertScreen.Configuration(dismissOnOutsideTap: false),
                content: [
                    AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(AlertTitleComponent(title: "Disable Backup?"))
                    ),
                    AnyComponentWithIdentity(
                        id: "text",
                        component: AnyComponent(AlertTextComponent(content: .plain(
                            "Your wallet will switch to the new recovery phrase. After the change is confirmed, Telegram will delete the encrypted backup stored across its datacenters."
                        )))
                    )
                ],
                actions: [
                    AlertScreen.Action(title: "Cancel", action: { [weak self] in
                        self?.dismissBackupWordsFlow()
                    }),
                    AlertScreen.Action(
                        title: "Disable",
                        type: .destructive,
                        action: { [weak self] in
                            self?.submitDisableBackup(prepared: prepared)
                        },
                        autoDismiss: false,
                        isEnabled: actionsEnabled,
                        progress: progress.get()
                    )
                ]
            )
            self.disableBackupConfirmationController = alertController
            self.disableBackupProgress = progress
            alertController.dismissed = { [weak self, weak alertController] _ in
                guard let self, self.disableBackupConfirmationController === alertController else {
                    return
                }
                self.disableBackupConfirmationController = nil
                self.disableBackupProgress = nil
                self.isDisablingBackup = false
            }
            controller.present(alertController, in: .window(.root))
        }

        private func submitDisableBackup(prepared: WalletContext.PreparedBackupDisable) {
            guard !self.isDisablingBackup,
                  let component = self.component,
                  let presentingController = self.backupWordsController?.navigationController?.topViewController as? ViewController
                    ?? self.environment?.controller() else {
                return
            }
            self.isDisablingBackup = true
            self.disableBackupProgress?.set(true)
            self.backupOperationDisposable.set(performWalletAuthorizedOperation(
                context: component.context,
                present: { [weak presentingController] alert in
                    presentingController?.present(alert, in: .window(.root))
                },
                operation: { password in
                    component.walletContext.disableBackup(prepared, password: password)
                },
                next: { [weak self] _ in
                    guard let self else { return }
                    let complete: () -> Void = { [weak self] in
                        guard let self else { return }
                        self.dismissBackupWordsFlow()
                        self.presentBackupDisabledToast()
                    }
                    if let alertController = self.disableBackupConfirmationController {
                        alertController.dismiss(completion: complete)
                    } else {
                        complete()
                    }
                },
                failed: { [weak self] error in
                    guard let self else { return }
                    self.isDisablingBackup = false
                    self.disableBackupProgress?.set(false)
                    self.presentDisableBackupError(error: error)
                }
            ))
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

        private func presentDisableBackupError(error: WalletContext.WalletError? = nil) {
            guard error != .authorizationCancelled else { return }
            guard let component = self.component,
                  let controller = self.backupWordsController?.navigationController?.topViewController as? ViewController
                    ?? self.environment?.controller() else {
                return
            }
            let message = error.flatMap(walletAuthorizationErrorMessage)
            controller.present(textAlertController(
                context: component.context,
                title: message?.title ?? "Couldn't Disable Backup",
                text: message?.text ?? "The encrypted backup is still enabled. Check the network connection and try again.",
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {
                })]
            ), in: .window(.root))
        }

        private func presentBackupDisabledToast() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            controller.present(UndoOverlayController(
                presentationData: presentationData,
                content: .actionSucceeded(
                    title: "Backup Disabled",
                    text: "Your recovery phrase is now the only way to restore your wallet.",
                    cancel: nil,
                    destructive: false
                ),
                position: .bottom,
                action: { _ in false }
            ), in: .current)
        }

        private func enableBackup() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            self.backupOperationDisposable.set(performWalletAuthorizedOperation(
                context: component.context,
                present: { [weak controller] alert in
                    controller?.present(alert, in: .window(.root))
                },
                operation: { password in
                    component.walletContext.enableBackup(password: password)
                },
                next: { [weak self] _ in
                    self?.presentBackupEnabledToast()
                },
                failed: { [weak self] error in
                    self?.presentBackupOperationError(error)
                }
            ))
        }

        private func presentBackupEnabledToast() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            controller.present(UndoOverlayController(
                presentationData: presentationData,
                content: .actionSucceeded(
                    title: "Backup Enabled",
                    text: "Your keys are now stored encrypted across Telegram's datacenters.",
                    cancel: nil,
                    destructive: false
                ),
                position: .bottom,
                action: { _ in false }
            ), in: .current)
        }

        private func presentBackupOperationError(_ error: WalletContext.WalletError) {
            guard error != .authorizationCancelled else { return }
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let message = walletAuthorizationErrorMessage(error)
            controller.present(textAlertController(
                context: component.context,
                title: message?.title ?? "Couldn’t Update Backup",
                text: message?.text ?? "Check the network connection and try again.",
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]
            ), in: .window(.root))
        }

        private func presentDeleteWalletAlert() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.present(textAlertController(
                context: component.context,
                title: "Delete Wallet?",
                text: "You'll lose access to your funds unless you've saved your recovery phrase.",
                actions: [
                    TextAlertAction(type: .destructiveAction, title: "Delete Anyway", action: { [weak self] in
                        Queue.mainQueue().after(0.25) { [weak self] in
                            self?.presentWalletReplacementOptionsAlert()
                        }
                    }),
                    TextAlertAction(type: .genericAction, title: "Cancel", action: {})
                ],
                actionLayout: .vertical
            ), in: .window(.root))
        }

        private func presentWalletReplacementOptionsAlert() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let creationProgress = ValuePromise<Bool>(false, ignoreRepeated: true)
            let actionsEnabled = creationProgress.get()
            |> map { !$0 }
            let alertController = AlertScreen(
                context: component.context,
                configuration: AlertScreen.Configuration(
                    actionAlignment: .vertical,
                    dismissOnOutsideTap: true
                ),
                content: [
                    AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(AlertTitleComponent(
                            title: "How do you want to replace the old wallet?"
                        ))
                    )
                ],
                actions: [
                    AlertScreen.Action(
                        title: "Create a New Wallet",
                        action: { [weak self] in
                            self?.createReplacementWallet()
                        },
                        autoDismiss: false,
                        isEnabled: actionsEnabled,
                        progress: creationProgress.get()
                    ),
                    AlertScreen.Action(
                        title: "Import an Existing Wallet",
                        action: { [weak self] in
                            self?.openReplacementImport()
                        },
                        autoDismiss: false,
                        isEnabled: actionsEnabled
                    )
                ]
            )
            self.replacementOptionsController = alertController
            self.replacementCreationProgress = creationProgress
            alertController.dismissed = { [weak self, weak alertController] _ in
                guard let self, self.replacementOptionsController === alertController else {
                    return
                }
                self.replacementOptionsController = nil
                self.replacementCreationProgress = nil
                self.isCreatingReplacementWallet = false
            }
            controller.present(alertController, in: .window(.root))
        }

        private func openReplacementImport() {
            guard !self.isCreatingReplacementWallet,
                  let component = self.component,
                  let controller = self.environment?.controller(),
                  let alertController = self.replacementOptionsController else {
                return
            }
            alertController.dismiss { [weak self, weak controller] in
                controller?.push(component.context.sharedContext.makeWalletImportScreen(
                    context: component.context,
                    mode: .importWallet,
                    completion: { [weak self] in
                        self?.completeWalletReplacement(
                            toastTitle: "Wallet Imported",
                            toastText: "Your wallet was restored from your recovery phrase."
                        )
                    }
                ))
            }
        }

        private func completeWalletReplacement(toastTitle: String, toastText: String) {
            guard let component = self.component else {
                return
            }
            let accountManager = component.context.sharedContext.accountManager
            let _ = (ApplicationSpecificNotice.resetWalletGramTooltip(accountManager: accountManager)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] in
                guard let self,
                      let component = self.component,
                      let settingsController = self.environment?.controller(),
                      let navigationController = settingsController.navigationController as? NavigationController,
                      let settingsControllerIndex = navigationController.viewControllers.firstIndex(where: { $0 === settingsController }),
                      settingsControllerIndex > 0 else {
                    return
                }
                
                let remainingViewControllers = Array(navigationController.viewControllers.prefix(upTo: settingsControllerIndex))
                guard let walletController = remainingViewControllers.last as? ViewController else {
                    return
                }
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                
                navigationController.setViewControllers(remainingViewControllers, animated: true)
                Queue.mainQueue().after(0.4) { [weak walletController] in
                    guard let walletController else {
                        return
                    }
                    //TODO:localize
                    walletController.present(UndoOverlayController(
                        presentationData: presentationData,
                        content: .actionSucceeded(
                            title: toastTitle,
                            text: toastText,
                            cancel: nil,
                            destructive: false
                        ),
                        elevatedLayout: false,
                        animateInAsReplacement: false,
                        action: { _ in
                            return false
                        }
                    ), in: .current)
                }
            })
        }

        private func createReplacementWallet() {
            guard !self.isCreatingReplacementWallet,
                  let component = self.component,
                  let controller = self.environment?.controller(),
                  let alertController = self.replacementOptionsController,
                  let creationProgress = self.replacementCreationProgress else {
                return
            }
            self.isCreatingReplacementWallet = true
            creationProgress.set(true)
            self.operationDisposable.set(performWalletAuthorizedOperation(
                context: component.context,
                present: { [weak controller] alert in
                    controller?.present(alert, in: .window(.root))
                },
                operation: { password in
                    component.walletContext.createWallet(password: password)
                },
                next: { [weak self, weak alertController] _ in
                    let complete: () -> Void = { [weak self] in
                        self?.completeWalletReplacement(
                            toastTitle: "Wallet Created",
                            toastText: "Your new wallet is ready to use."
                        )
                    }
                    if let alertController {
                        alertController.dismiss(completion: complete)
                    } else {
                        complete()
                    }
                },
                failed: { [weak self] error in
                    guard let self else {
                        return
                    }
                    self.isCreatingReplacementWallet = false
                    self.replacementCreationProgress?.set(false)
                    self.presentReplacementError(error)
                }
            ))
        }

        private func presentReplacementError(_ error: WalletContext.WalletError) {
            guard error != .authorizationCancelled else { return }
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let message = walletAuthorizationErrorMessage(error)
            controller.present(textAlertController(
                context: component.context,
                title: message?.title ?? "Couldn’t Replace Wallet",
                text: message?.text ?? "Check the network connection and try again.",
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]
            ), in: .window(.root))
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
            //TODO:localize
            let backupHeader = "Encrypted Backup"
            //TODO:localize
            let enableBackupAction = "Enable Backup"
            //TODO:localize
            let disableBackupAction = "Disable Backup"
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
            let canEnableBackup: Bool
            let canRevealPhrase: Bool
            let canEnterRecoveryPhrase: Bool
            let backupEnabled: Bool
            if let phase = self.walletState?.phase, case let .wallet(info) = phase {
                canDisableBackup = info.canDisableBackup
                canEnableBackup = info.canEnableBackup && info.canSign
                canRevealPhrase = info.canRevealPhrase
                canEnterRecoveryPhrase = !info.canSign && !info.canExportPhrase
                backupEnabled = info.backupEnabled
            } else {
                canDisableBackup = false
                canEnableBackup = false
                canRevealPhrase = false
                canEnterRecoveryPhrase = false
                backupEnabled = false
            }
            //TODO:localize
            let recoveryAction = canEnterRecoveryPhrase ? "Enter Recovery Phrase" : "Show Recovery Phrase"
            //TODO:localize
            let recoveryFooter = canEnterRecoveryPhrase
                ? "Enter your recovery phrase to restore access to this wallet."
                : "You can transfer your wallet to another device by copying your 12- or 24-word recovery phrase."
            //TODO:localize
            let backupFooter = backupEnabled
                ? "Telegram stores an encrypted backup of your keys, split across several datacenters. No Telegram employee can access them."
                : "Telegram will store an encrypted backup of your keys, split across several datacenters. No Telegram employee will be able to access them."

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
                                if canEnterRecoveryPhrase {
                                    self?.openRecoveryPhraseImport()
                                } else {
                                    self?.openRecoveryPhrase()
                                }
                            }
                        )))
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: sectionWidth, height: 10000.0)
            )
            if canRevealPhrase || canEnterRecoveryPhrase, let recoverySectionView = self.recoverySection.view {
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
                contentHeight += recoverySectionSize.height
                contentHeight += sectionSpacing
            } else {
                self.recoverySection.view?.removeFromSuperview()
            }

            var backupItems: [AnyComponentWithIdentity<Empty>] = []
            if canEnableBackup {
                backupItems.append(AnyComponentWithIdentity(id: "enableBackup", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: enableBackupAction,
                            font: actionFont,
                            textColor: theme.list.itemAccentColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    accessory: nil,
                    action: { [weak self] _ in
                        self?.enableBackup()
                    }
                ))))
            }
            if canDisableBackup {
                backupItems.append(AnyComponentWithIdentity(id: "disableBackup", component: AnyComponent(ListActionItemComponent(
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
                ))))
            }
            if !backupItems.isEmpty {
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
                        items: backupItems
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

            self.replacementSection.parentState = self.state
            let replacementSectionSize = self.replacementSection.update(
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
            if let replacementSectionView = self.replacementSection.view {
                if replacementSectionView.superview == nil {
                    self.scrollView.addSubview(replacementSectionView)
                }
                transition.setFrame(
                    view: replacementSectionView,
                    frame: CGRect(
                        origin: CGPoint(x: sideInset, y: contentHeight),
                        size: replacementSectionSize
                    )
                )
            }
            contentHeight += replacementSectionSize.height
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
