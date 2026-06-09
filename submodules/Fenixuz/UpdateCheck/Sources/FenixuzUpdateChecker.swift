import Foundation
import UIKit
import FenixuzLocalization
import TelegramPresentationData

// Hardcoded App Store bundle ID — DO NOT use Bundle.main.bundleIdentifier here.
// Dev/sim builds run as "ph.telegra.Telegraph" which returns zero App Store results.
// The live App Store listing always uses uz.fenixuz.app.
private let kAppStoreBundleId = "uz.fenixuz.app"
private let kLookupURL = "https://itunes.apple.com/lookup?bundleId=\(kAppStoreBundleId)"
private let kTimeoutSeconds: TimeInterval = 8

// Per-session flag — show alert at most once per app life.
private var sessionAlertShown = false

// MARK: - Public API

public final class FenixuzUpdateChecker {

    /// Check App Store and present an alert if a newer version is live.
    /// Safe to call multiple times — shows at most once per session.
    /// No-ops silently on network errors or empty results.
    public static func checkAndPresentIfNeeded(
        on presenter: UIViewController,
        presentationData: PresentationData
    ) {
        guard !sessionAlertShown else { return }

        Task {
            await performCheck(presenter: presenter, presentationData: presentationData)
        }
    }
}

// MARK: - Internal

private extension FenixuzUpdateChecker {

    static func performCheck(
        presenter: UIViewController,
        presentationData: PresentationData
    ) async {
        guard let url = URL(string: kLookupURL) else { return }

        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: kTimeoutSeconds)
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let results = json["results"] as? [[String: Any]],
            let first = results.first,
            let storeVersionString = first["version"] as? String,
            let trackViewUrl = first["trackViewUrl"] as? String
        else { return }

        let runningVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

        // Numeric comparison so "1.10" > "1.9" works correctly.
        let comparison = storeVersionString.compare(runningVersion, options: .numeric)
        guard comparison == .orderedDescending else { return }

        // Newer version found — present alert on main thread.
        await MainActor.run {
            presentAlert(
                storeVersion: storeVersionString,
                trackViewUrl: trackViewUrl,
                presenter: presenter,
                presentationData: presentationData
            )
        }
    }

    @MainActor
    static func presentAlert(
        storeVersion: String,
        trackViewUrl: String,
        presenter: UIViewController,
        presentationData: PresentationData
    ) {
        guard !sessionAlertShown else { return }
        sessionAlertShown = true

        let l10n = FenixuzL10n(presentationData.strings)

        let alert = UIAlertController(
            title: l10n.update_title,
            message: l10n.update_message(version: storeVersion),
            preferredStyle: .alert
        )

        let updateAction = UIAlertAction(title: l10n.update_actionUpdate, style: .default) { _ in
            guard let appUrl = URL(string: trackViewUrl) else { return }
            UIApplication.shared.open(appUrl)
        }

        let laterAction = UIAlertAction(title: l10n.update_actionLater, style: .cancel)

        alert.addAction(updateAction)
        alert.addAction(laterAction)

        presenter.present(alert, animated: true)
    }
}
