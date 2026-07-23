import Foundation
import UIKit
import Display
import AccountContext
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import ButtonComponent
import WalletContext
import SwiftSignalKit

private final class WalletSetupScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let walletContext: WalletContext
    let routeToWallet: (ViewController) -> Bool

    init(
        context: AccountContext,
        walletContext: WalletContext,
        routeToWallet: @escaping (ViewController) -> Bool
    ) {
        self.context = context
        self.walletContext = walletContext
        self.routeToWallet = routeToWallet
    }

    static func ==(lhs: WalletSetupScreenComponent, rhs: WalletSetupScreenComponent) -> Bool {
        return lhs.context === rhs.context && lhs.walletContext === rhs.walletContext
    }

    final class View: UIView {
        private let createButton = ComponentView<Empty>()
        private let importButton = ComponentView<Empty>()

        private var component: WalletSetupScreenComponent?
        private var environment: EnvironmentType?
        private var componentState: EmptyComponentState?

        private weak var subscribedWalletContext: WalletContext?
        private var walletState: WalletContext.State?
        private var walletStateDisposable: Disposable?
        private let operationDisposable = MetaDisposable()
        private var isUpdating = false

        private var isCreateFlowActive = false
        private var isImportFlowActive = false
        private var isCreating = false
        private var backupConfirmationSubmitted = false
        private var presentedBackupAddress: String?
        private var isRouteToWalletScheduled = false
        private var didRouteToWallet = false

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.walletStateDisposable?.dispose()
            self.operationDisposable.dispose()
        }

        private func subscribeToWalletStateIfNeeded(component: WalletSetupScreenComponent) {
            guard self.subscribedWalletContext !== component.walletContext else {
                return
            }

            self.walletStateDisposable?.dispose()
            self.subscribedWalletContext = component.walletContext
            self.walletStateDisposable = (component.walletContext.state
            |> deliverOnMainQueue).start(next: { [weak self] walletState in
                guard let self else {
                    return
                }
                self.walletState = walletState
                if !self.isUpdating {
                    self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                }
                self.routeToWalletIfNeeded()
            })
        }

        fileprivate func routeToWalletIfNeeded() {
            guard !self.didRouteToWallet,
                  !self.isRouteToWalletScheduled,
                  !self.isCreateFlowActive,
                  let walletState = self.walletState else {
                return
            }

            switch walletState.phase {
            case .restoring, .wallet, .failed:
                break
            case .empty:
                return
            }

            self.isRouteToWalletScheduled = true
            Queue.mainQueue().justDispatch { [weak self] in
                guard let self else {
                    return
                }
                self.isRouteToWalletScheduled = false
                self.performRouteToWalletIfNeeded()
            }
        }

        private func performRouteToWalletIfNeeded() {
            guard !self.didRouteToWallet,
                  !self.isCreateFlowActive,
                  let component = self.component,
                  let controller = self.environment?.controller(),
                  let walletState = self.walletState else {
                return
            }

            switch walletState.phase {
            case .restoring, .wallet, .failed:
                break
            case .empty:
                return
            }

            self.didRouteToWallet = component.routeToWallet(controller)
        }

        private func openImport() {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  self.canStartSetupOperation else {
                return
            }

            self.isImportFlowActive = true
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))

            let importController = component.context.sharedContext.makeWalletImportScreen(context: component.context, mode: .importWallet, completion: nil)
            if let importController = importController as? ViewControllerComponentContainer {
                importController.wasDismissed = { [weak self] in
                    guard let self else {
                        return
                    }
                    self.isImportFlowActive = false
                    self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                }
            }
            controller.push(importController)
        }

        private var canStartSetupOperation: Bool {
            guard !self.isCreateFlowActive,
                  !self.isImportFlowActive,
                  self.walletState?.activeOperation == nil,
                  let walletState = self.walletState else {
                return false
            }
            if case .empty = walletState.phase {
                return true
            }
            return false
        }

        private func createWallet() {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  self.canStartSetupOperation else {
                return
            }

            self.isCreateFlowActive = true
            self.isCreating = true
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))

            self.operationDisposable.set((component.walletContext.createWallet()
            |> deliverOnMainQueue).start(next: { [weak self, weak controller] createdWallet in
                guard let self, let controller else {
                    return
                }
                self.isCreating = false
                self.presentedBackupAddress = createdWallet.info.address
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                self.presentBackup(
                    words: createdWallet.words,
                    address: createdWallet.info.address,
                    component: component,
                    controller: controller
                )
            }, error: { [weak self] _ in
                guard let self else {
                    return
                }
                self.isCreating = false
                self.isCreateFlowActive = false
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                self.presentWalletError(
                    title: "Couldn’t Create Wallet",
                    text: "Wallet setup didn’t finish. No transfer was sent. Unlock the device, check the network connection and try again."
                )
                self.routeToWalletIfNeeded()
            }))
        }

        private func presentBackup(
            words: [String],
            address: String,
            component: WalletSetupScreenComponent,
            controller: ViewController
        ) {
            self.backupConfirmationSubmitted = false
            let backupController = component.context.sharedContext.makeWalletWordsScreen(
                context: component.context,
                words: words,
                verify: true,
                completion: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.backupConfirmationSubmitted = true
                    self.finishCreateFlow()
                }
            )
            if let backupController = backupController as? ViewControllerComponentContainer {
                backupController.wasDismissed = { [weak self] in
                    guard let self,
                          !self.backupConfirmationSubmitted,
                          self.presentedBackupAddress == address else {
                        return
                    }
                    self.finishCreateFlow()
                }
            }
            controller.push(backupController)
        }

        private func finishCreateFlow() {
            self.isCreating = false
            self.isCreateFlowActive = false
            self.backupConfirmationSubmitted = false
            self.presentedBackupAddress = nil
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            self.routeToWalletIfNeeded()
        }

        private func presentWalletError(title: String, text: String, completion: (() -> Void)? = nil) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                completion?()
                return
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            controller.present(standardTextAlertController(
                theme: AlertControllerTheme(presentationData: presentationData),
                title: title,
                text: text,
                actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {
                    completion?()
                })]
            ), in: .window(.root))
        }

        func update(
            component: WalletSetupScreenComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            let environment = environment[EnvironmentType.self].value
            self.component = component
            self.environment = environment
            self.componentState = state
            self.subscribeToWalletStateIfNeeded(component: component)

            transition.setBackgroundColor(view: self, color: environment.theme.list.plainBackgroundColor)

            let horizontalInset: CGFloat = 16.0
            let buttonSpacing: CGFloat = 10.0
            let bottomInset = max(environment.safeInsets.bottom, 16.0)
            let buttonWidth = max(
                0.0,
                availableSize.width
                    - environment.safeInsets.left
                    - environment.safeInsets.right
                    - horizontalInset * 2.0
            )
            let buttonHeight: CGFloat = 52.0
            let buttonX = environment.safeInsets.left + horizontalInset
            let importButtonY = max(
                environment.navigationHeight,
                availableSize.height - bottomInset - buttonHeight
            )
            let createButtonY = max(
                environment.navigationHeight,
                importButtonY - buttonSpacing - buttonHeight
            )

            let accentColor = environment.theme.list.itemCheckColors.fillColor
            let primaryForegroundColor = environment.theme.list.itemCheckColors.foregroundColor
            let canStartSetupOperation = self.canStartSetupOperation
            let displaysSetupControls: Bool
            if let walletState = self.walletState, case .empty = walletState.phase {
                displaysSetupControls = true
            } else {
                displaysSetupControls = self.isCreateFlowActive
            }
            let isRestoring: Bool
            if let walletState = self.walletState, case .restoring = walletState.phase {
                isRestoring = true
            } else {
                isRestoring = self.walletState == nil
            }

            self.createButton.parentState = state
            let createButtonSize = self.createButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: accentColor,
                        foreground: primaryForegroundColor,
                        pressedColor: accentColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: "createWallet",
                        component: AnyComponent(Text(
                            text: "Create Wallet",
                            font: Font.semibold(17.0),
                            color: primaryForegroundColor
                        ))
                    ),
                    isEnabled: canStartSetupOperation,
                    displaysProgress: self.isCreating || isRestoring,
                    action: { [weak self] in
                        self?.createWallet()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: buttonWidth, height: buttonHeight)
            )
            if let createButtonView = self.createButton.view {
                if createButtonView.superview == nil {
                    self.addSubview(createButtonView)
                }
                transition.setFrame(
                    view: createButtonView,
                    frame: CGRect(
                        origin: CGPoint(x: buttonX, y: createButtonY),
                        size: createButtonSize
                    )
                )
                transition.setAlpha(view: createButtonView, alpha: displaysSetupControls ? 1.0 : 0.0)
            }

            let secondaryBackgroundColor = accentColor.withAlphaComponent(0.1)
            self.importButton.parentState = state
            let importButtonSize = self.importButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: secondaryBackgroundColor,
                        foreground: accentColor,
                        pressedColor: accentColor.withAlphaComponent(0.18)
                    ),
                    content: AnyComponentWithIdentity(
                        id: "importWallet",
                        component: AnyComponent(Text(
                            text: "Import Wallet",
                            font: Font.semibold(17.0),
                            color: accentColor
                        ))
                    ),
                    isEnabled: canStartSetupOperation,
                    action: { [weak self] in
                        self?.openImport()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: buttonWidth, height: buttonHeight)
            )
            if let importButtonView = self.importButton.view {
                if importButtonView.superview == nil {
                    self.addSubview(importButtonView)
                }
                transition.setFrame(
                    view: importButtonView,
                    frame: CGRect(
                        origin: CGPoint(x: buttonX, y: importButtonY),
                        size: importButtonSize
                    )
                )
                transition.setAlpha(view: importButtonView, alpha: displaysSetupControls ? 1.0 : 0.0)
            }

            self.routeToWalletIfNeeded()

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

public final class WalletSetupScreen: ViewControllerComponentContainer {
    public init(
        context: AccountContext,
        walletContext: WalletContext,
        routeToWallet: @escaping (ViewController) -> Bool
    ) {
        super.init(
            context: context,
            component: WalletSetupScreenComponent(
                context: context,
                walletContext: walletContext,
                routeToWallet: routeToWallet
            ),
            navigationBarAppearance: .default,
            statusBarStyle: .default,
            theme: .default
        )

        self.title = "Wallet"
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let componentView = self.node.hostView.componentView as? WalletSetupScreenComponent.View else {
            return
        }
        componentView.routeToWalletIfNeeded()
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
