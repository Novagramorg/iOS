import Foundation
import UIKit
import CommonCrypto

// MARK: - Feature #6: developer check for the hidden Developer section
// A 10-tap Easter-egg used to reveal the "Show ads" toggle to anyone. Ads are now shown to every
// user (Premium included), so only a developer may reveal the section: after the 20 s hold on the
// Settings version line (NovagramDeveloperSection) the app asks for the developer login + password
// and reveals the section only when they match.
//
// Only a PBKDF2-HMAC-SHA256 digest of "<login>|<password>" (random salt, 600k rounds) ships in the
// binary — never the credentials themselves. The rounds make an offline guess from the binary
// expensive; the UI also throttles: 5 wrong tries lock the prompt for 5 minutes.
//
// Each login has its own digest and role (`NovagramDeveloperRole`): the developer's and the
// director's. `submodules/Novagram/scripts/novagram-developer-digest.py` makes a digest for a new
// login or password.
enum NovagramAdsAdminAuth {
    private static let saltHex = "6ced8c7f8279470c768f8739196a445b"
    private static let rounds: UInt32 = 600_000
    private static let credentials: [(digest: String, role: NovagramDeveloperRole)] = [
        ("bf0445f7b4c37604336598ba977f8065c2e90da61c1bbd933d64d018077203eb", .developer),
        ("17ca3795cd21c510e781c68eec2df12e1038f8e599cc80751f626a736d7d6fca", .director)
    ]

    private static let maxFailedAttempts = 5
    private static let lockoutDuration: TimeInterval = 5 * 60

    private static let udSuite = "pro_messager"
    private static let failedAttemptsKey = "fenix_ads_admin_failed_attempts"
    private static let lockedUntilKey = "fenix_ads_admin_locked_until"
    private static let legacyMigrationKey = "fenix_ads_admin_migrated_v1"
    private static let sectionRevealedKey = "fenix_ads_section_revealed"
    private static let showAdsKey = "fenix_show_ads"

    // MARK: Verification

    /// The role whose login (case-insensitive, trimmed) and exact password match, or nil.
    /// Slow on purpose (~0.3–0.6 s on a phone) — call it off the main thread.
    static func verify(login: String, password: String) -> NovagramDeveloperRole? {
        let normalizedLogin = login.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let digest = derive(secret: "\(normalizedLogin)|\(password)") else { return nil }
        var matched: NovagramDeveloperRole?
        // Compare with every digest, so the time taken does not tell which login was close.
        for credential in credentials where constantTimeEquals(digest, credential.digest) {
            matched = credential.role
        }
        return matched
    }

    private static func derive(secret: String) -> String? {
        let salt = hexBytes(saltHex)
        var derived = [UInt8](repeating: 0, count: 32)
        // The String bridges to the C `const char *` password parameter (UTF-8).
        let status = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            secret, secret.utf8.count,
            salt, salt.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            rounds,
            &derived, derived.count
        )
        guard Int(status) == kCCSuccess else { return nil }
        return derived.map { String(format: "%02x", $0) }.joined()
    }

    private static func hexBytes(_ hex: String) -> [UInt8] {
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex, let next = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) {
            if let byte = UInt8(hex[index ..< next], radix: 16) {
                bytes.append(byte)
            }
            index = next
        }
        return bytes
    }

    private static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let lhsBytes = Array(lhs.utf8)
        let rhsBytes = Array(rhs.utf8)
        guard lhsBytes.count == rhsBytes.count else { return false }
        var difference: UInt8 = 0
        for index in 0 ..< lhsBytes.count {
            difference |= lhsBytes[index] ^ rhsBytes[index]
        }
        return difference == 0
    }

    // MARK: Throttling

    /// When the prompt unlocks again, or nil if it is not locked.
    static var lockedUntil: Date? {
        guard let timestamp = UserDefaults(suiteName: udSuite)?.object(forKey: lockedUntilKey) as? Double else { return nil }
        let date = Date(timeIntervalSince1970: timestamp)
        return date > Date() ? date : nil
    }

    private static func registerFailure() {
        let defaults = UserDefaults(suiteName: udSuite)
        let failures = (defaults?.integer(forKey: failedAttemptsKey) ?? 0) + 1
        if failures >= maxFailedAttempts {
            defaults?.set(Date().addingTimeInterval(lockoutDuration).timeIntervalSince1970, forKey: lockedUntilKey)
            defaults?.set(0, forKey: failedAttemptsKey)
        } else {
            defaults?.set(failures, forKey: failedAttemptsKey)
        }
    }

    private static func registerSuccess() {
        let defaults = UserDefaults(suiteName: udSuite)
        defaults?.removeObject(forKey: failedAttemptsKey)
        defaults?.removeObject(forKey: lockedUntilKey)
    }

    // MARK: Legacy state

    /// Before the admin check, anyone could reveal the section and switch ads off. Run once: hide a
    /// section revealed that way and switch ads back on, so only an admin can hide ads from now on.
    static func migrateLegacyRevealIfNeeded() {
        guard let defaults = UserDefaults(suiteName: udSuite) else { return }
        guard !defaults.bool(forKey: legacyMigrationKey) else { return }
        defaults.set(true, forKey: legacyMigrationKey)
        let wasRevealed = defaults.object(forKey: sectionRevealedKey) as? Bool ?? false
        let adsWereOff = (defaults.object(forKey: showAdsKey) as? Bool) == false
        guard wasRevealed || adsWereOff else { return }
        defaults.set(false, forKey: sectionRevealedKey)
        defaults.set(true, forKey: showAdsKey)
        NotificationCenter.default.post(name: .novagramShowAdsChanged, object: nil)
    }

    // MARK: Prompt

    /// Ask for the admin login + password. `completion(role)` only on a match; cancel, a wrong
    /// entry and an active lockout all end in `completion(nil)` (after explaining why).
    static func presentPrompt(from viewController: UIViewController, langCode: String, completion: @escaping (NovagramDeveloperRole?) -> Void) {
        guard let presenter = topPresenter(from: viewController) else {
            completion(nil)
            return
        }
        if let lockedUntil {
            let minutes = max(1, Int((lockedUntil.timeIntervalSinceNow / 60).rounded(.up)))
            presentMessage(NovagramAdsAdminStrings.locked(minutes: minutes, langCode: langCode), from: presenter, langCode: langCode)
            completion(nil)
            return
        }

        let alert = UIAlertController(
            title: NovagramAdsAdminStrings.title(langCode: langCode),
            message: NovagramAdsAdminStrings.message(langCode: langCode),
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = NovagramAdsAdminStrings.loginPlaceholder(langCode: langCode)
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.spellCheckingType = .no
            field.textContentType = .username
        }
        alert.addTextField { field in
            field.placeholder = NovagramAdsAdminStrings.passwordPlaceholder(langCode: langCode)
            field.isSecureTextEntry = true
            field.textContentType = .password
        }
        alert.addAction(UIAlertAction(title: NovagramAdsAdminStrings.cancel(langCode: langCode), style: .cancel) { _ in
            completion(nil)
        })
        alert.addAction(UIAlertAction(title: NovagramAdsAdminStrings.confirm(langCode: langCode), style: .default) { [weak alert] _ in
            let login = alert?.textFields?.first?.text ?? ""
            let password = alert?.textFields?.last?.text ?? ""
            // The key derivation is deliberately slow; keep it off the main thread.
            DispatchQueue.global(qos: .userInitiated).async {
                let role = verify(login: login, password: password)
                DispatchQueue.main.async {
                    if let role {
                        registerSuccess()
                        completion(role)
                    } else {
                        registerFailure()
                        let text = lockedUntil != nil
                            ? NovagramAdsAdminStrings.locked(minutes: Int(lockoutDuration / 60), langCode: langCode)
                            : NovagramAdsAdminStrings.wrongCredentials(langCode: langCode)
                        presentMessage(text, from: presenter, langCode: langCode)
                        completion(nil)
                    }
                }
            }
        })
        presenter.present(alert, animated: true)
    }

    private static func presentMessage(_ text: String, from presenter: UIViewController, langCode: String) {
        let alert = UIAlertController(title: nil, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(alert, animated: true)
    }

    /// The view controller currently on top of the window, so the alert is never presented
    /// under (or blocked by) another modal.
    private static func topPresenter(from viewController: UIViewController) -> UIViewController? {
        var top = viewController.view.window?.rootViewController ?? viewController
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

/// Public entry to the admin check for other Novagram modules (the hidden "Ads Analytics" row asks for
/// the same logins as the Developer section). `completion(true)` on a match with any role.
public enum NovagramAdsAdminGate {
    public static func requestAccess(from viewController: UIViewController, langCode: String, completion: @escaping (Bool) -> Void) {
        NovagramAdsAdminAuth.presentPrompt(from: viewController, langCode: langCode, completion: { role in
            completion(role != nil)
        })
    }
}

// MARK: - Local strings (Feature #6 — admin check)

private enum NovagramAdsAdminStrings {
    static func title(langCode: String) -> String {
        switch langCode {
        case "uz": return "Dasturchini tasdiqlash"
        case "ru": return "Подтверждение разработчика"
        case "zh": return "开发者验证"
        default:   return "Developer verification"
        }
    }

    static func message(langCode: String) -> String {
        switch langCode {
        case "uz": return "Davom etish uchun dasturchi login va parolini kiriting"
        case "ru": return "Введите логин и пароль разработчика, чтобы продолжить"
        case "zh": return "输入开发者账号和密码以继续"
        default:   return "Enter the developer login and password to continue"
        }
    }

    static func loginPlaceholder(langCode: String) -> String {
        switch langCode {
        case "uz": return "Login"
        case "ru": return "Логин"
        case "zh": return "账号"
        default:   return "Login"
        }
    }

    static func passwordPlaceholder(langCode: String) -> String {
        switch langCode {
        case "uz": return "Parol"
        case "ru": return "Пароль"
        case "zh": return "密码"
        default:   return "Password"
        }
    }

    static func confirm(langCode: String) -> String {
        switch langCode {
        case "uz": return "Tasdiqlash"
        case "ru": return "Подтвердить"
        case "zh": return "确认"
        default:   return "Confirm"
        }
    }

    static func cancel(langCode: String) -> String {
        switch langCode {
        case "uz": return "Bekor qilish"
        case "ru": return "Отмена"
        case "zh": return "取消"
        default:   return "Cancel"
        }
    }

    static func wrongCredentials(langCode: String) -> String {
        switch langCode {
        case "uz": return "Login yoki parol noto'g'ri"
        case "ru": return "Неверный логин или пароль"
        case "zh": return "账号或密码错误"
        default:   return "Wrong login or password"
        }
    }

    static func locked(minutes: Int, langCode: String) -> String {
        switch langCode {
        case "uz": return "Juda ko'p noto'g'ri urinish. \(minutes) daqiqadan keyin qayta urinib ko'ring"
        case "ru": return "Слишком много неверных попыток. Повторите через \(minutes) мин."
        case "zh": return "错误次数过多，请 \(minutes) 分钟后再试"
        default:   return "Too many wrong attempts. Try again in \(minutes) min"
        }
    }
}
