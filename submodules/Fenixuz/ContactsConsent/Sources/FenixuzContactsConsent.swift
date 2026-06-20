import Foundation
import UIKit
import Contacts

// Fenixuz — Apple App Review 5.1.2 (Privacy — Data Use and Sharing) consent gate.
//
// Apple reject (submission d5a06920-6b5f-4167-b7fb-46c80b156aa8, 2026-05-16):
// "The app uploads the user's Contact to a server, but the app does not inform
// the user and request their consent first."
//
// NSContactsUsageDescription (Info.plist) alone is not enough — Apple wants
// an EXPLICIT in-app dialog that says "your contacts will be uploaded to a
// server" with a clear Privacy Policy reference, BEFORE iOS shows its own
// system permission alert.
//
// This module gates the existing `DeviceAccess.authorizeAccess(to: .contacts)`
// path. The hook in `DeviceAccess.swift` wraps the contacts-permission body
// in `FenixuzContactsConsent.gate`. Returning users who already authorized
// iOS Contacts pre-update are silently treated as having consented (upgrade
// path; no nag dialog on first launch after update).

public enum FenixuzContactsConsent {
    private static let consentKey = "Fenixuz.ContactsConsent.v1"
    private static let privacyPolicyURL = "https://fenixuz.uz/privacy.html"

    public static var hasGivenConsent: Bool {
        if UserDefaults.standard.bool(forKey: consentKey) {
            return true
        }
        // Upgrade path: user already authorized iOS Contacts on a previous
        // app version → silently mark consent as given so we don't nag them.
        // (.limited / partial access on iOS 18+ is treated as not-yet-consented,
        // so the dialog will surface once for those users — acceptable.)
        if CNContactStore.authorizationStatus(for: .contacts) == .authorized {
            UserDefaults.standard.set(true, forKey: consentKey)
            return true
        }
        return false
    }

    public static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: consentKey)
    }

    /// Gate any contacts-access flow. If consent was already given, runs `perform()`.
    /// Otherwise shows a consent dialog; if accepted, runs `perform()`; if declined,
    /// calls `completion(false)` and does NOT run `perform()`.
    public static func gate(
        completion: @escaping (Bool) -> Void,
        perform: @escaping () -> Void
    ) {
        if hasGivenConsent {
            perform()
            return
        }

        if Thread.isMainThread {
            presentConsentAlert(onAccept: {
                UserDefaults.standard.set(true, forKey: consentKey)
                perform()
            }, onDecline: {
                completion(false)
            })
        } else {
            DispatchQueue.main.async {
                presentConsentAlert(onAccept: {
                    UserDefaults.standard.set(true, forKey: consentKey)
                    perform()
                }, onDecline: {
                    completion(false)
                })
            }
        }
    }

    // MARK: - Internal

    private static func presentConsentAlert(
        onAccept: @escaping () -> Void,
        onDecline: @escaping () -> Void
    ) {
        guard let presenter = topViewController() else {
            // No window available yet (rare — e.g. background launch). Decline
            // by default so we never upload contacts without a visible consent UI.
            onDecline()
            return
        }

        let title = "Sync Your Contacts?"
        let message = """
        Novagram will upload your phone contacts to Telegram servers so you can find friends who already use the app. Your contacts are transmitted encrypted and you can disable Contact Sync anytime in Settings → Privacy and Security → Data Settings.

        By tapping Continue, you agree to our Privacy Policy:
        \(privacyPolicyURL)
        """

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Don't Allow", style: .cancel) { _ in
            onDecline()
        })

        alert.addAction(UIAlertAction(title: "Privacy Policy", style: .default) { _ in
            if let url = URL(string: privacyPolicyURL) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            // After opening the policy we still want to ask again — re-present.
            presentConsentAlert(onAccept: onAccept, onDecline: onDecline)
        })

        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            onAccept()
        })

        presenter.present(alert, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })

        guard var top = keyWindow?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
