import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import Display
import TelegramPresentationData
import NovagramLocalization
import NovagramAds
import NovagramInsights
import NovagramInsightsUI

/// Entry point of the hidden admin screen (SDK `NovagramInsightsUI`).
///
/// The Settings row is not in the list by default. Holding "Novagram Settings" for `revealDuration`
/// seconds toggles it: showing it first asks for the admin login (the same gate as "Remove all ads"),
/// hiding it needs nothing. The state is persisted across launches. Everything is iOS 16+: the screen
/// needs SwiftUI and Charts, which the app links weakly, so on iOS 15 the row never appears and no SDK
/// code is touched.
public enum NovagramChannelStatsEntry {
    /// How long "Novagram Settings" must be held to toggle the row.
    public static let revealDuration: TimeInterval = 20.0

    private static let state = NovagramInsightsState()

    /// Re-emits the signal's latest value whenever row visibility changes.
    /// Folded into the Settings data signal, so the list rebuilds when the flag flips.
    public static func refreshing<T>(_ signal: Signal<T, NoError>) -> Signal<T, NoError> {
        return combineLatest(queue: Queue.mainQueue(), signal, self.state.revision.get())
        |> map { value, _ in
            return value
        }
    }

    /// True when the Settings row should be in the list: iOS 16+ and the toggle is on.
    public static func isRowVisible(context: AccountContext) -> Bool {
        guard #available(iOS 16.0, *) else {
            return false
        }
        return self.state.isRevealed
    }

    /// The long-press action for "Novagram Settings", or nil below iOS 16. Reads the state when it
    /// fires: a shown row is hidden at once, a hidden row is shown only after `authorize` (the admin
    /// login prompt: presenting controller, language code, completion) reports success.
    public static func revealAction(
        context: AccountContext,
        authorize: @escaping (UIViewController, String, @escaping (Bool) -> Void) -> Void
    ) -> (() -> Void)? {
        guard #available(iOS 16.0, *) else {
            return nil
        }
        return {
            if self.state.isRevealed {
                self.state.setRevealed(false)
                HapticFeedback().success()
                return
            }
            guard let host = self.topViewController(context: context) else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            authorize(host, langCode) { granted in
                guard granted else {
                    return
                }
                self.state.setRevealed(true)
                HapticFeedback().success()
            }
        }
    }

    /// Opens the screen full screen over the current top view controller.
    public static func present(context: AccountContext) {
        guard #available(iOS 16.0, *) else {
            return
        }
        guard let host = self.topViewController(context: context) else {
            return
        }
        let accountId = self.accountId(context)
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }

        let box = ControllerBox()
        let configuration = InsightsConfiguration(
            environment: self.environment,
            keychainKey: novagramInsightsKeychainKey(accountId: accountId),
            language: self.language(strings: presentationData.strings),
            onClose: {
                box.controller?.dismiss(animated: true)
            }
        )
        let theme = InsightsTheme(accent: presentationData.theme.list.itemAccentColor)
        let style: UIUserInterfaceStyle = presentationData.theme.overallDarkAppearance ? .dark : .light
        // The SDK's factory is main-actor isolated; this entry is called from plain UI callbacks.
        Task { @MainActor in
            let controller = InsightsUI.makeViewController(configuration: configuration, theme: theme)
            controller.modalPresentationStyle = .fullScreen
            controller.overrideUserInterfaceStyle = style
            box.controller = controller
            host.present(controller, animated: true)
        }
    }

    // MARK: - Configuration

    private static func accountId(_ context: AccountContext) -> Int64 {
        return context.account.peerId.id._internalGetInt64Value()
    }

    /// The environment compiled in from `--define=novagramAdsEnvironment`; production when the value is
    /// empty or unknown.
    private static var environment: SDKEnvironment {
        return SDKEnvironment(rawValue: NovagramChannelStatsGeneratedEnvironment.name) ?? .production
    }

    private static func language(strings: PresentationStrings) -> InsightsLanguage {
        switch NovagramL10n.languageKey(for: strings) {
        case "uz":
            return .uzbek
        case "ru":
            return .russian
        default:
            return .english
        }
    }

    private static func topViewController(context: AccountContext) -> UIViewController? {
        guard var top = context.sharedContext.mainWindow?.hostView.containerView.window?.rootViewController else {
            return nil
        }
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

private func novagramInsightsKeychainKey(accountId: Int64) -> InsightsKeychainKey {
    return InsightsKeychainKey(account: "telegram.\(accountId)")
}

/// Lets the `onClose` callback reach the controller it belongs to without a retain cycle.
/// Only touched on the main thread (UIKit and the SDK's main-actor callback).
private final class ControllerBox: @unchecked Sendable {
    weak var controller: UIViewController?
}

/// Row visibility, persisted in UserDefaults. Thread-safe: read while the Settings list lays out,
/// written from the long-press gesture.
private final class NovagramInsightsState {
    private static let revealedKey = "fenix_insights_row_revealed"

    let revision = ValuePromise<Int>(0, ignoreRepeated: true)

    private let lock = NSLock()
    private var counter = 0

    var isRevealed: Bool {
        return UserDefaults.standard.bool(forKey: Self.revealedKey)
    }

    func setRevealed(_ value: Bool) {
        guard value != self.isRevealed else {
            return
        }
        UserDefaults.standard.set(value, forKey: Self.revealedKey)
        self.lock.lock()
        self.counter += 1
        let revision = self.counter
        self.lock.unlock()
        self.revision.set(revision)
    }
}
