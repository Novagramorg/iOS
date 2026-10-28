import Foundation
import UIKit
import SwiftUI
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramStringFormatting
import NovagramLocalization
import NovagramServices
import NovagramServicesUI

/// The Settings row and its page. The row is shown while the hidden Developer switch
/// "Show currency rates" is on (`NovagramDeveloperFlags.isCurrencyRatesViewEnabled`).
public enum NovagramCurrencyRatesEntry {
    public static func rowTitle(langCode: String) -> String {
        return NovagramCurrencyRatesStrings.title(langCode: langCode)
    }

    /// Pushes the calculator on the root navigation controller, the one the Settings tab pushes on.
    public static func open(context: AccountContext) {
        guard let navigationController = context.sharedContext.mainWindow?.viewController as? NavigationController else {
            return
        }
        navigationController.pushViewController(NovagramCurrencyRatesController(context: context, screen: .calculator, rates: nil))
    }
}

// MARK: - Stored state

// What the user leaves on the two screens, so the next opening starts there. Plain JSON in the
// Novagram suite (the SDK views report it, they never store anything themselves).
private enum NovagramCurrencyRatesStore {
    private static let udSuite = "pro_messager"
    private static let stateKey = "novagram_currency_converter_state"
    private static let favoritesKey = "novagram_currency_favorites"

    // One client for both screens: the SDK keeps the bank's answer for the day, so the list
    // opened from the calculator does not wait for the network again.
    static let client = ServicesClient()

    static var state: CurrencyConverterState {
        get {
            guard let data = UserDefaults(suiteName: udSuite)?.data(forKey: stateKey),
                  let state = try? JSONDecoder().decode(CurrencyConverterState.self, from: data) else {
                return .default
            }
            return state
        }
        set {
            UserDefaults(suiteName: udSuite)?.set(try? JSONEncoder().encode(newValue), forKey: stateKey)
        }
    }

    static var favorites: [String] {
        get {
            return UserDefaults(suiteName: udSuite)?.stringArray(forKey: favoritesKey) ?? MultiCurrencyView.defaultFavorites
        }
        set {
            UserDefaults(suiteName: udSuite)?.set(newValue, forKey: favoritesKey)
        }
    }
}

// MARK: - Controller

/// Hosts one of the SDK's two converter screens: the calculator (with a bar button that opens the
/// list) or the list of favorite currencies.
final class NovagramCurrencyRatesController: ViewController {
    enum Screen {
        case calculator
        case list(base: String, amount: Decimal)
    }

    private let context: AccountContext
    private let screen: Screen
    private var presentationData: PresentationData
    private var rates: [CurrencyRate]?
    private var hostingController: UIHostingController<AnyView>?
    private var presentationDataDisposable: Disposable?
    private var ratesTask: Task<Void, Never>?

    init(context: AccountContext, screen: Screen, rates: [CurrencyRate]?) {
        self.context = context
        self.screen = screen
        self.rates = rates
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: novagramCurrencyRatesNavigationBarData(self.presentationData))

        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.updateTitleAndButtons()

        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let self else {
                return
            }
            self.presentationData = presentationData
            self.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
            self.navigationBar?.updatePresentationData(novagramCurrencyRatesNavigationBarData(presentationData), transition: .immediate)
            self.updateTitleAndButtons()
            self.updateContent()
        })

        self.loadRates()
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.presentationDataDisposable?.dispose()
        self.ratesTask?.cancel()
    }

    private var langCode: String {
        return NovagramL10n.languageKey(for: self.presentationData.strings)
    }

    private func updateTitleAndButtons() {
        switch self.screen {
        case .calculator:
            self.title = NovagramCurrencyRatesStrings.title(langCode: self.langCode)
            let icon = UIImage(systemName: "list.bullet", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18.0, weight: .semibold))?
                .withTintColor(self.presentationData.theme.rootController.navigationBar.buttonColor, renderingMode: .alwaysOriginal)
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: icon, style: .plain, target: self, action: #selector(self.openListPressed))
        case .list:
            self.title = NovagramCurrencyRatesStrings.listTitle(langCode: self.langCode)
        }
    }

    // The rates come from the SDK's day cache after the first call; nil (loading or failed) makes
    // the views show their placeholders.
    private func loadRates() {
        self.ratesTask = Task { [weak self] in
            let rates = try? await NovagramCurrencyRatesStore.client.currencyRates.latest()
            await MainActor.run {
                guard let self, let rates else {
                    return
                }
                self.rates = rates
                self.updateContent()
            }
        }
    }

    @objc private func openListPressed() {
        let state = NovagramCurrencyRatesStore.state
        self.push(NovagramCurrencyRatesController(context: self.context, screen: .list(base: state.from, amount: state.amount), rates: self.rates))
    }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor

        let hostingController = UIHostingController(rootView: self.makeContent())
        hostingController.view.backgroundColor = .clear
        self.addChild(hostingController)
        self.displayNode.view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        self.hostingController = hostingController

        self.displayNodeDidLoad()
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let navigationBarHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        let contentFrame = CGRect(x: 0.0, y: navigationBarHeight, width: layout.size.width, height: max(0.0, layout.size.height - navigationBarHeight))
        if let view = self.hostingController?.view {
            transition.updateFrame(view: view, frame: contentFrame)
        }
    }

    // The SDK's currency picker sheet is presented by this controller: Telegram's navigation does not
    // make a pushed controller a UIKit child, so it is the top of the hosting controller's parent
    // chain. UIKit and SwiftUI close a sheet (close button, row, swipe down) by calling dismiss on its
    // presenter, and Display's ViewController.dismiss pops the screen instead: the sheet stayed and
    // the screen under it was gone. While a sheet is up, run UIViewController's own dismiss.
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        let selector = #selector(UIViewController.dismiss(animated:completion:))
        guard self.presentedViewController != nil, let method = class_getInstanceMethod(UIViewController.self, selector) else {
            super.dismiss(animated: flag, completion: completion)
            return
        }
        typealias UIKitDismiss = @convention(c) (UIViewController, Selector, Bool, (@convention(block) () -> Void)?) -> Void
        var completionBlock: (@convention(block) () -> Void)?
        if let completion {
            completionBlock = { completion() }
        }
        let uikitDismiss = unsafeBitCast(method_getImplementation(method), to: UIKitDismiss.self)
        uikitDismiss(self, selector, flag, completionBlock)
    }

    private func updateContent() {
        guard self.isNodeLoaded else {
            return
        }
        self.displayNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        // The same view type stays at the root, so SwiftUI keeps what the user typed.
        self.hostingController?.rootView = self.makeContent()
    }

    private func makeContent() -> AnyView {
        let theme = ServicesUITheme(self.presentationData.theme)
        let locale = localeWithStrings(self.presentationData.strings)
        let strings = NovagramCurrencyRatesStrings.converter(langCode: self.langCode, ratesDate: self.rates?.first?.date)
        switch self.screen {
        case .calculator:
            return AnyView(CurrencyCalculatorView(
                rates: self.rates,
                state: NovagramCurrencyRatesStore.state,
                strings: strings,
                theme: theme,
                locale: locale,
                onStateChange: { state in
                    NovagramCurrencyRatesStore.state = state
                }
            ))
        case let .list(base, amount):
            return AnyView(MultiCurrencyView(
                rates: self.rates,
                base: base,
                amount: amount,
                favorites: NovagramCurrencyRatesStore.favorites,
                strings: strings,
                theme: theme,
                locale: locale,
                onFavoritesChange: { favorites in
                    NovagramCurrencyRatesStore.favorites = favorites
                }
            ))
        }
    }
}

// The glass bar the Settings screens use (as in ItemListController).
private func novagramCurrencyRatesNavigationBarData(_ presentationData: PresentationData) -> NavigationBarPresentationData {
    return NavigationBarPresentationData(
        theme: NavigationBarTheme(rootControllerTheme: presentationData.theme, hideBackground: false, hideSeparator: false, edgeEffectColor: presentationData.theme.list.blocksBackgroundColor, style: .glass),
        strings: NavigationBarStrings(presentationStrings: presentationData.strings)
    )
}

// MARK: - Theme

// The SDK's color tokens from the Telegram theme (the mapping in the SDK's docs/UI.md).
private extension ServicesUITheme {
    init(_ theme: PresentationTheme) {
        self.init(
            cardBackground: Color(theme.list.itemBlocksBackgroundColor),
            separator: Color(theme.list.itemBlocksSeparatorColor),
            primaryText: Color(theme.list.itemPrimaryTextColor),
            secondaryText: Color(theme.list.itemSecondaryTextColor),
            accent: Color(theme.list.itemAccentColor),
            positive: Color(theme.list.freeTextSuccessColor),
            negative: Color(theme.list.itemDestructiveColor),
            isDark: theme.overallDarkAppearance
        )
    }
}
