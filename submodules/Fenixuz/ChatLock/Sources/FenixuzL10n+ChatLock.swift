import Foundation

// Localized strings used exclusively by the ChatLock module.
// Keeping them here avoids touching the central FenixuzL10n.swift
// (owned by a separate agent) and makes the whole module self-contained.
//
// Usage: FenixuzChatLockStrings.title(.set, isDark: …)

public enum FenixuzChatLockStrings {

    // MARK: - Lock type labels

    static func pinTitle(mode: ChatLockSetupStep) -> String {
        switch mode {
        case .enterNew:    return localized(en: "Set PIN", uz: "PIN o'rnating", ru: "Установить PIN")
        case .confirmNew:  return localized(en: "Confirm PIN", uz: "PINni tasdiqlang", ru: "Подтвердите PIN")
        case .verify:      return localized(en: "Enter PIN", uz: "PIN kiriting", ru: "Введите PIN")
        case .remove:      return localized(en: "Confirm PIN", uz: "PINni tasdiqlang", ru: "Подтвердите PIN")
        }
    }

    static func pinSubtitle(mode: ChatLockSetupStep) -> String {
        switch mode {
        case .enterNew:    return localized(en: "4-digit code", uz: "4 raqamli kod", ru: "4-значный код")
        case .confirmNew:  return localized(en: "Re-enter the same code", uz: "Kodni qayta kiriting", ru: "Введите код ещё раз")
        case .verify:      return localized(en: "Chat is locked", uz: "Chat qulflangan", ru: "Чат заблокирован")
        case .remove:      return localized(en: "Enter current code to remove", uz: "O'chirish uchun amaldagi kodni kiriting", ru: "Введите текущий код для удаления")
        }
    }

    static func textTitle(mode: ChatLockSetupStep) -> String {
        switch mode {
        case .enterNew:    return localized(en: "Set Password", uz: "Parol o'rnating", ru: "Установить пароль")
        case .confirmNew:  return localized(en: "Confirm Password", uz: "Parolni tasdiqlang", ru: "Подтвердите пароль")
        case .verify:      return localized(en: "Enter Password", uz: "Parol kiriting", ru: "Введите пароль")
        case .remove:      return localized(en: "Confirm Password", uz: "Parolni tasdiqlang", ru: "Подтвердите пароль")
        }
    }

    static func textSubtitle(mode: ChatLockSetupStep) -> String {
        switch mode {
        case .enterNew:    return localized(en: "Alphanumeric password", uz: "Harfli-raqamli parol", ru: "Буквенно-цифровой пароль")
        case .confirmNew:  return localized(en: "Re-enter the same password", uz: "Parolni qayta kiriting", ru: "Введите пароль ещё раз")
        case .verify:      return localized(en: "Chat is locked", uz: "Chat qulflangan", ru: "Чат заблокирован")
        case .remove:      return localized(en: "Enter current password to remove", uz: "O'chirish uchun amaldagi parolni kiriting", ru: "Введите текущий пароль для удаления")
        }
    }

    // MARK: - Error strings

    static var mismatch: String {
        localized(en: "Codes don't match", uz: "Kod mos kelmadi", ru: "Коды не совпадают")
    }

    static var wrongCode: String {
        localized(en: "Incorrect code", uz: "Noto'g'ri kod", ru: "Неверный код")
    }

    static var wrongPassword: String {
        localized(en: "Incorrect password", uz: "Noto'g'ri parol", ru: "Неверный пароль")
    }

    static var passwordMismatch: String {
        localized(en: "Passwords don't match", uz: "Parol mos kelmadi", ru: "Пароли не совпадают")
    }

    // MARK: - Biometric toggle prompt (shown after first-time setup)

    static var biometricPromptTitle: String {
        localized(en: "Enable Biometrics?", uz: "Biometrikani yoqish?", ru: "Включить биометрию?")
    }

    static func biometricPromptSubtitle(type: ChatLockBiometricType) -> String {
        switch type {
        case .faceID:
            return localized(en: "Unlock this chat with Face ID", uz: "Chatni Face ID bilan oching", ru: "Разблокировать Face ID")
        case .touchID:
            return localized(en: "Unlock this chat with Touch ID", uz: "Chatni Touch ID bilan oching", ru: "Разблокировать Touch ID")
        }
    }

    static var biometricEnable: String {
        localized(en: "Enable", uz: "Yoqish", ru: "Включить")
    }

    static var biometricSkip: String {
        localized(en: "Skip", uz: "O'tkazib yuborish", ru: "Пропустить")
    }

    // MARK: - Type picker (shown at the START of the setup flow)

    static var chooseTypeTitle: String {
        localized(en: "Lock Type", uz: "Qulf turi", ru: "Тип блокировки")
    }

    static var chooseTypePin: String {
        localized(en: "4-digit PIN", uz: "4 raqamli PIN", ru: "4-значный PIN")
    }

    static var chooseTypeText: String {
        localized(en: "Alphanumeric Password", uz: "Harfli-raqamli parol", ru: "Буквенно-цифровой пароль")
    }

    // MARK: - Biometric reason (the system prompt shown by iOS)

    static var biometricReason: String {
        localized(
            en: "Use biometrics to unlock this chat",
            uz: "Chatni biometrika bilan oching",
            ru: "Разблокировать чат с помощью биометрии"
        )
    }

    // MARK: - Keyboard return key

    static var done: String {
        localized(en: "Done", uz: "Tayyor", ru: "Готово")
    }

    // MARK: - Context-menu titles (localized — fixes the previously hardcoded Uzbek)
    public static var menuSet: String {
        localized(en: "🔒 Set Pincode", uz: "🔒 Pincode qo'yish", ru: "🔒 Установить пин-код")
    }
    public static var menuRemove: String {
        localized(en: "🔓 Remove Pincode", uz: "🔓 Pincode o'chirish", ru: "🔓 Удалить пин-код")
    }

    // MARK: - Helpers

    private static func localized(en: String, uz: String, ru: String) -> String {
        let lang = Locale.current.languageCode ?? "en"
        switch lang {
        case "uz": return uz
        case "ru": return ru
        default:   return en
        }
    }
}

// Step used internally by ChatPincodeViewController to drive the title/subtitle.
enum ChatLockSetupStep {
    case enterNew
    case confirmNew
    case verify
    case remove
}

// Biometric type detected at runtime.
enum ChatLockBiometricType {
    case faceID
    case touchID
}
