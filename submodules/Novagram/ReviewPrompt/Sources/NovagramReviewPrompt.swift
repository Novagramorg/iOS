import Foundation
import UIKit
import SwiftSignalKit
import Display
import TelegramCore
import AccountContext
// Callers write `NovagramReviewPrompt.record(.ghostMode)` and need the SDK's feature names.
@_exported import NovagramReviewPromptCore

/// The App Store rating prompt for every user (owner's decision, 2026-10-31).
///
/// - Features call `record(_:)` in their success branch (any thread).
/// - `ChatListControllerImpl.viewDidAppear` calls `chatListDidAppear(...)`, the natural break.
/// - The SDK decides (5 successes of one feature, 3 days after the start, 14 days apart, once per app version,
///   5 new successes after every request) and asks Apple's system prompt only.
/// - The Settings "Rate Novagram" row opens the write-review page, never the prompt.
///
/// See `submodules/Novagram/HOOKS.md`, "App Store rating prompt (2026-10-31)".
public enum NovagramReviewPrompt {
    private static let logTag = "NovagramReviewPrompt"

    // Telegram's Logger writes only when the user turned logging on, so Debug builds also print, which
    // `devicectl device process launch --console` shows.
    private static func log(_ text: String) {
        Logger.shared.log(logTag, text)
        #if DEBUG
        print("[\(logTag)] \(text)")
        #endif
    }

    // One center per app: two centers on one suite would overwrite each other's counts. It uses the SDK's
    // `pro_messager` defaults (key `novagram_review_prompt_state`).
    private static let center: ReviewPromptCenter = {
        #if DEBUG
        seedForTestingIfAsked()
        #endif
        return ReviewPromptCenter()
    }()

    #if DEBUG
    /// Debug builds only: launching with NOVAGRAM_REVIEW_PROMPT_SEED=1 (e.g. `devicectl device process launch
    /// --environment-variables`) makes the next chat-list visit eligible: start 4 days ago, Ghost mode used 5 times,
    /// no request yet. The prompt can't be checked on a phone otherwise, because the SDK waits 3 days.
    private static func seedForTestingIfAsked() {
        guard ProcessInfo.processInfo.environment["NOVAGRAM_REVIEW_PROMPT_SEED"] == "1" else {
            return
        }
        let start = Date().addingTimeInterval(-4 * 24 * 60 * 60).timeIntervalSince1970
        let state: [String: Any] = ["formatVersion": 1, "startDate": start, "successCounts": ["ghostMode": 5]]
        guard let data = try? JSONSerialization.data(withJSONObject: state) else {
            return
        }
        ReviewPromptCenter.novagramDefaults().set(data, forKey: ReviewPromptCenter.stateKey)
        log("debug seed: start 4 days ago, ghostMode 5, no request")
    }
    #endif

    // Login detection (main queue only). nil until the first emission of the account records after launch.
    nonisolated(unsafe) private static var knownAccountIds: Set<AccountRecordId>?
    nonisolated(unsafe) private static var accountRecordsDisposable: Disposable?

    /// Short version + build number from the main bundle, e.g. "2.0.14 (85)". Empty when the bundle has no short
    /// version, which the SDK reports as `invalidAppVersion`.
    public static let appVersion: String = {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? ""
        let buildNumber = info?["CFBundleVersion"] as? String ?? ""
        if shortVersion.isEmpty || buildNumber.isEmpty {
            return shortVersion
        }
        return "\(shortVersion) (\(buildNumber))"
    }()

    // MARK: - Counting

    /// A Novagram feature succeeded. Any thread.
    public static func record(_ feature: ReviewPromptFeature) {
        center.recordSuccess(feature)
        let state = center.state
        let isCounted = center.policy.countedFeatures.contains(feature)
        log("recorded \(feature.rawValue): \(state.successCount(for: feature)) total, \(state.newSuccessCount(for: feature)) new, counted: \(isCounted)")
    }

    // Chats where our "forward without names" item set up a forward that is not sent yet (main queue only).
    nonisolated(unsafe) private static var pendingForwardWithoutNames = Set<EnginePeer.Id>()

    /// Our "forward without names" item put a forward into the input panel of `peerId`. It counts only when sent,
    /// so Telegram's own "Hide Sender's Names" switch is not counted.
    public static func markForwardWithoutNames(to peerId: EnginePeer.Id) {
        pendingForwardWithoutNames.insert(peerId)
    }

    /// A forward with hidden names was sent to `peerId`; counts it if our item started it.
    public static func forwardWithHiddenNamesSent(to peerId: EnginePeer.Id) {
        if pendingForwardWithoutNames.remove(peerId) != nil {
            record(.forwardWithoutNames)
        }
    }

    /// An account logged in: the 3-day start delay restarts. Counts and the last request are kept.
    public static func noteFreshStart() {
        center.noteFreshStart()
        log("fresh start after a login")
    }

    /// Called once at launch (from `NovagramAnalyticsManager.start`). Watches the account records, not the live
    /// accounts: switching accounts changes the live set but adds no record, a login adds one.
    public static func observeLogins(sharedContext: SharedAccountContext) {
        if accountRecordsDisposable != nil {
            return
        }
        accountRecordsDisposable = (sharedContext.accountManager.accountRecords()
        |> map { view -> Set<AccountRecordId> in
            var ids = Set<AccountRecordId>()
            for record in view.records {
                let isLoggedOut = record.attributes.contains(where: { attribute in
                    if case .loggedOut = attribute {
                        return true
                    } else {
                        return false
                    }
                })
                if !isLoggedOut {
                    ids.insert(record.id)
                }
            }
            return ids
        }
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { ids in
            let previous = knownAccountIds
            knownAccountIds = ids
            if let previous, !ids.subtracting(previous).isEmpty {
                noteFreshStart()
            }
        })
    }

    // MARK: - The trigger

    /// The chat list appeared. The SDK checks the rules, waits 2 s, checks them and `isBusy` again, then asks.
    @MainActor
    public static func chatListDidAppear(controller: ViewController, context: AccountContext, isSecretVaultList: Bool) {
        guard let scene = controller.view.window?.windowScene else {
            log("chat list appeared without a window scene, nothing asked")
            return
        }
        let sharedContext = context.sharedContext
        let version = appVersion
        center.requestReviewIfAppropriate(appVersion: version, in: scene, isBusy: { [weak controller] in
            guard let controller else {
                log("busy: chat list released")
                return true
            }
            if let reason = busyReason(controller: controller, sharedContext: sharedContext, isSecretVaultList: isSecretVaultList) {
                log("busy: \(reason)")
                return true
            }
            return false
        }, completion: { result in
            log("request \(result), app version \(version)")
        })
    }

    /// Why the user is in the middle of something, or nil when the chat list is the calm top screen.
    @MainActor
    private static func busyReason(controller: ViewController, sharedContext: SharedAccountContext, isSecretVaultList: Bool) -> String? {
        if UIApplication.shared.applicationState != .active {
            return "app not active"
        }
        if sharedContext.callManager?.hasActiveCall == true {
            return "active call"
        }
        if isSecretVaultList {
            return "Secret Vault list"
        }
        guard let window = controller.view.window else {
            return "chat list not on screen"
        }
        if let presented = window.rootViewController?.presentedViewController {
            return "modal \(type(of: presented))"
        }
        if let presented = controller.presentationContext.controllers.first?.0 {
            return "presented over the chat list: \(type(of: presented))"
        }
        let navigationController = controller.navigationController as? NavigationController
        if let navigationController {
            // The root holds only the tab bar; anything more (a chat, the vault list, an archive, a modal) is on top.
            if navigationController.viewControllers.count > 1 {
                return "controller pushed: \(navigationController.viewControllers.count) in the stack"
            }
            if let overlay = navigationController.overlayControllers.first ?? navigationController.globalOverlayControllers.first {
                return "overlay \(type(of: overlay))"
            }
        }
        return windowPresentedController(controller: controller, rootControllers: navigationController?.viewControllers ?? [], topLevelOverlays: sharedContext.mainWindow?.topLevelOverlayControllers ?? [])
    }

    // Alerts, sheets and menus presented on the window (`present(_, in: .window(.root))`).
    @MainActor
    private static func windowPresentedController(controller: ViewController, rootControllers: [UIViewController], topLevelOverlays: [ContainableController]) -> String? {
        var found: String?
        controller.window?.forEachController { presented in
            if found != nil || presented is NavigationController {
                return
            }
            if let presented = presented as? UIViewController, rootControllers.contains(where: { $0 === presented }) {
                return
            }
            // The window's top-level overlays (AppDelegate sets the overlay media controller and the in-app
            // notification banners) stay in the window all the time. Only a video or mini player on screen counts.
            if topLevelOverlays.contains(where: { $0 === presented }) {
                if let overlayMedia = presented as? OverlayMediaController, overlayMedia.hasNodes {
                    found = "overlay media is showing"
                }
                return
            }
            found = "window controller \(type(of: presented))"
        }
        return found
    }

    // MARK: - Settings row

    /// "Rate Novagram" in the app's language (en, uz, ru, zh; anything else is English).
    public static func rateRowTitle(langCode: String) -> String {
        return ReviewPromptStrings(languageCode: langCode).rateTitle
    }

    /// The Settings row opens the App Store write-review page through the app's URL opener.
    public static func openWriteReview(context: AccountContext) {
        guard let url = ReviewPromptLinks.writeReviewURL() else {
            log("Rate Novagram: no write-review URL")
            return
        }
        log("Rate Novagram: opening \(url.absoluteString)")
        context.sharedContext.applicationBindings.openUrl(url.absoluteString)
    }
}
