import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import AccountContext
import ProgressNavigationButtonNode

// Simplified clone of AuthorizationSequencePasswordEntryController for logging in with a bot token.
// A token is a single plain text field, so this drops the forgot/reset/hint machinery of the
// password screen and keeps only the single-field + "Next" flow.
public final class AuthorizationSequenceBotTokenEntryController: ViewController {
    // Same transparent/glass auth nav-bar look the password screen uses. Inlined here because the
    // helper on AuthorizationSequenceController is internal to AuthorizationUI and importing that
    // module would create a dependency cycle (AuthorizationUI depends on this module).
    private static func navigationBarTheme(_ theme: PresentationTheme) -> NavigationBarTheme {
        return NavigationBarTheme(overallDarkAppearance: theme.overallDarkAppearance, buttonColor: theme.chat.inputPanel.panelControlColor, disabledButtonColor: theme.intro.disabledTextColor, primaryTextColor: theme.intro.primaryTextColor, backgroundColor: .clear, opaqueBackgroundColor: .clear, enableBackgroundBlur: false, separatorColor: .clear, badgeBackgroundColor: theme.rootController.navigationBar.badgeBackgroundColor, badgeStrokeColor: theme.rootController.navigationBar.badgeStrokeColor, badgeTextColor: theme.rootController.navigationBar.badgeTextColor, edgeEffectColor: .clear, accentButtonColor: theme.list.itemCheckColors.fillColor, accentDisabledButtonColor: theme.chat.inputPanel.panelControlDisabledColor, accentForegroundColor: theme.list.itemCheckColors.foregroundColor, style: .glass)
    }

    private var controllerNode: AuthorizationSequenceBotTokenEntryControllerNode {
        return self.displayNode as! AuthorizationSequenceBotTokenEntryControllerNode
    }

    private var validLayout: ContainerViewLayout?

    private let sharedContext: SharedAccountContext
    private let presentationData: PresentationData
    private let back: () -> Void

    public var loginWithToken: ((String) -> Void)?

    private let hapticFeedback = HapticFeedback()

    public var inProgress: Bool = false {
        didSet {
            self.updateNavigationItems()
            self.controllerNode.inProgress = self.inProgress
        }
    }

    public init(sharedContext: SharedAccountContext, presentationData: PresentationData, back: @escaping () -> Void, displayBack: Bool = true) {
        self.sharedContext = sharedContext
        self.presentationData = presentationData
        self.back = back

        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: AuthorizationSequenceBotTokenEntryController.navigationBarTheme(presentationData.theme), strings: NavigationBarStrings(presentationStrings: presentationData.strings)))

        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)

        self.hasActiveInput = true

        self.statusBar.statusBarStyle = presentationData.theme.intro.statusBarStyle.style

        self.attemptNavigation = { _ in
            return false
        }
        self.navigationBar?.backPressed = { [weak self] in
            self?.back()
        }

        if displayBack {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: self, action: #selector(self.backPressed))
        }
    }

    @objc private func backPressed() {
        self.back()
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequenceBotTokenEntryControllerNode(strings: self.presentationData.strings, theme: self.presentationData.theme)
        self.displayNodeDidLoad()

        self.controllerNode.view.disableAutomaticKeyboardHandling = [.forward, .backward]

        self.controllerNode.proceed = { [weak self] _ in
            self?.nextPressed()
        }

        self.controllerNode.updateData()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.controllerNode.activateInput()
    }

    func updateNavigationItems() {
        guard let layout = self.validLayout, layout.size.width < 360.0 else {
            return
        }

        if self.inProgress {
            let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.presentationData.theme.rootController.navigationBar.accentTextColor))
            self.navigationItem.rightBarButtonItem = item
        } else {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
        }
    }

    // Matches the password controller's public updateData(...) so the sequence controller can drive
    // this screen identically. A token screen has no dynamic hint, so this just refreshes the node.
    public func updateData() {
        if self.isNodeLoaded {
            self.controllerNode.updateData()
        }
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        let hadLayout = self.validLayout != nil
        self.validLayout = layout

        if !hadLayout {
            self.updateNavigationItems()
        }

        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }

    @objc func nextPressed() {
        if self.controllerNode.currentToken.isEmpty {
            self.hapticFeedback.error()
            self.controllerNode.animateError()
        } else {
            self.loginWithToken?(self.controllerNode.currentToken)
        }
    }
}
