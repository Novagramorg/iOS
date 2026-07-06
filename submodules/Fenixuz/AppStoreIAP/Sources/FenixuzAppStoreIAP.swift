import Foundation
import UIKit
import FenixuzLocalization

// Apple Review 3.1.1 — Fenixuz does not sell digital subscriptions or Stars.
// Telegram's server does not honour StoreKit receipts issued for non-official
// client bundles, and we have no In-App Purchase products registered for
// `uz.fenixuz.app` in App Store Connect. Therefore on App Store builds every
// purchase path — bot-invoice checkout (Premium Bot card flow), StoreKit
// subscriptions (Premium Annual/Monthly), Stars top-up, gifts — must end
// before money changes hands and tell the user to use the official Telegram.
//
// The May 2026 review (submission d5a06920-6b5f-4167-b7fb-46c80b156aa8) only
// caught the bot-invoice path; the screens reached via Settings → Telegram
// Premium / My Stars / Telegram Business / Send a Gift are still capable of
// triggering StoreKit, which would also fail review.
//
// Strategy:
//   1. Bot invoices — block in BotCheckoutController call sites (currency!=XTR && subscriptionPeriod!=nil).
//   2. StoreKit IAP — block at `InAppPurchaseManager.buyProduct`, the single funnel for every IAP flow.
//   3. Both paths share `presentBlockedAlert`, which deep-links to the official Telegram on the App Store.
//
// `isAppStoreBuild` mirrors `GlobalExperimentalSettings.isAppStoreBuild`. We
// avoid that import here so this module stays Telegram-UI-free.
//
// Hook sites (see submodules/Fenixuz/HOOKS.md):
//   - submodules/TelegramUI/Sources/AppDelegate.swift              (flag propagation at launch)
//   - submodules/TelegramUI/Sources/ChatController.swift           (invoice in chat)
//   - submodules/TelegramUI/Sources/OpenResolvedUrl.swift          (t.me/$slug deep link)
//   - submodules/WebUI/Sources/WebAppController.swift              (WebApp web_app_open_invoice)
//   - submodules/InAppPurchaseManager/Sources/InAppPurchaseManager.swift (StoreKit IAP funnel)

public enum FenixuzAppStoreIAP {
    /// Mirrors `buildConfig.isAppStoreBuild`. Kept for observability / logging only — the gates below
    /// are intentionally **build-independent** because Fenixuz never honours these flows on any build:
    /// dev simulator, TestFlight, App Store release all fail StoreKit (no products registered for
    /// `uz.fenixuz.app`) and all fail Premium-Bot card payments (Telegram's server only credits the
    /// official client). Keeping the gates unconditional means the developer can verify behaviour in
    /// the simulator without flipping a build flag.
    public static var isAppStoreBuild: Bool = false

    /// Official Telegram on the App Store. iOS opens `itms-apps://` directly in the App Store app.
    private static let officialTelegramAppStoreURL = "itms-apps://apps.apple.com/app/id686449807"

    // MARK: - Bot-invoice gate

    /// Returns `true` if presenting `BotCheckoutController` for this invoice would steer the user
    /// into the Premium-Bot fiat-card flow (Apple guideline 3.1.1 violation). Stars (XTR) and
    /// one-off non-subscription bot invoices (physical goods etc.) stay allowed.
    public static func shouldBlock(currency: String, hasSubscriptionPeriod: Bool) -> Bool {
        if currency.uppercased() == "XTR" {
            return false
        }
        return hasSubscriptionPeriod
    }

    // MARK: - StoreKit IAP gate

    /// Every StoreKit purchase — Premium subscription, Stars top-up, Premium gifts, business upgrade —
    /// is routed here. We always block on this fork; the "view-only" Settings screens still render but
    /// the Subscribe / Buy buttons end at the alert.
    public static var shouldBlockIAP: Bool {
        return true
    }

    // MARK: - Alert presentation

    /// Show a localized blocking alert on an explicit presenter. Caller must be on the main thread.
    public static func presentBlockedAlert(
        on presenter: UIViewController,
        languageCode: String
    ) {
        let alert = buildAlert(languageCode: languageCode)
        presenter.present(alert, animated: true)
    }

    /// Show a localized blocking alert by auto-discovering the topmost view controller. Use when the call site
    /// has no UIViewController in scope (e.g. inside `InAppPurchaseManager`). The lookup is dispatched onto the
    /// main queue, so this is safe to call from any thread; the call returns immediately.
    public static func presentBlockedAlertOnTop(languageCode: String? = nil) {
        DispatchQueue.main.async {
            guard let presenter = topViewController() else { return }
            let resolvedLang = languageCode ?? systemLanguageCode()
            let alert = buildAlert(languageCode: resolvedLang)
            presenter.present(alert, animated: true)
        }
    }

    // MARK: - Internals

    private static func buildAlert(languageCode: String) -> UIAlertController {
        let l10n = FenixuzL10n.from(languageCode: languageCode)
        let alert = UIAlertController(
            title: l10n.iap_block_title,
            message: l10n.iap_block_message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: l10n.iap_block_open_app_store, style: .default) { _ in
            guard let url = URL(string: officialTelegramAppStoreURL) else { return }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        })
        alert.addAction(UIAlertAction(title: l10n.iap_block_cancel, style: .cancel, handler: nil))
        return alert
    }

    private static func systemLanguageCode() -> String {
        if #available(iOS 16.0, *) {
            return Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            return Locale.current.languageCode ?? "en"
        }
    }

    private static func topViewController() -> UIViewController? {
        // Walk UIScene -> keyWindow -> rootViewController -> presentedViewController chain.
        let activeScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first
        guard let window = activeScene?.windows.first(where: { $0.isKeyWindow }) ?? activeScene?.windows.first else {
            return nil
        }
        var top = window.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
