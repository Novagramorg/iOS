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
        case .enterNew:    return localized(en: "Set PIN", uz: "PIN o'rnating", ru: "Установить PIN", zh: "设置 PIN 码")
        case .confirmNew:  return localized(en: "Confirm PIN", uz: "PINni tasdiqlang", ru: "Подтвердите PIN", zh: "确认 PIN 码")
        case .verify:      return localized(en: "Enter PIN", uz: "PIN kiriting", ru: "Введите PIN", zh: "输入 PIN 码")
        case .verifyMaster: return localized(en: "Enter master pincode", uz: "Asosiy pinkodni kiriting", ru: "Введите главный пин-код", zh: "输入主密码")
        case .remove:      return localized(en: "Confirm PIN", uz: "PINni tasdiqlang", ru: "Подтвердите PIN", zh: "确认 PIN 码")
        }
    }

    static func pinSubtitle(mode: ChatLockSetupStep) -> String {
        switch mode {
        case .enterNew:    return localized(en: "4-digit code", uz: "4 raqamli kod", ru: "4-значный код", zh: "4 位数字密码")
        case .confirmNew:  return localized(en: "Re-enter the same code", uz: "Kodni qayta kiriting", ru: "Введите код ещё раз", zh: "再次输入相同的密码")
        case .verify:      return localized(en: "Chat is locked", uz: "Chat qulflangan", ru: "Чат заблокирован", zh: "聊天已锁定")
        case .verifyMaster: return localized(en: "Unlocks this chat and removes its pincode", uz: "Chatni ochadi va pinkodini o'chiradi", ru: "Откроет чат и удалит его пин-код", zh: "将解锁此聊天并移除其密码")
        case .remove:      return localized(en: "Enter current code to remove", uz: "O'chirish uchun amaldagi kodni kiriting", ru: "Введите текущий код для удаления", zh: "输入当前密码以移除")
        }
    }

    static func textTitle(mode: ChatLockSetupStep) -> String {
        switch mode {
        case .enterNew:    return localized(en: "Set Password", uz: "Parol o'rnating", ru: "Установить пароль", zh: "设置密码")
        case .confirmNew:  return localized(en: "Confirm Password", uz: "Parolni tasdiqlang", ru: "Подтвердите пароль", zh: "确认密码")
        case .verify:      return localized(en: "Enter Password", uz: "Parol kiriting", ru: "Введите пароль", zh: "输入密码")
        case .verifyMaster: return localized(en: "Enter master password", uz: "Asosiy parolni kiriting", ru: "Введите главный пароль", zh: "输入主密码")
        case .remove:      return localized(en: "Confirm Password", uz: "Parolni tasdiqlang", ru: "Подтвердите пароль", zh: "确认密码")
        }
    }

    static func textSubtitle(mode: ChatLockSetupStep) -> String {
        switch mode {
        case .enterNew:    return localized(en: "Alphanumeric password", uz: "Harfli-raqamli parol", ru: "Буквенно-цифровой пароль", zh: "字母数字密码")
        case .confirmNew:  return localized(en: "Re-enter the same password", uz: "Parolni qayta kiriting", ru: "Введите пароль ещё раз", zh: "再次输入相同的密码")
        case .verify:      return localized(en: "Chat is locked", uz: "Chat qulflangan", ru: "Чат заблокирован", zh: "聊天已锁定")
        case .verifyMaster: return localized(en: "Unlocks this chat and removes its pincode", uz: "Chatni ochadi va pinkodini o'chiradi", ru: "Откроет чат и удалит его пин-код", zh: "将解锁此聊天并移除其密码")
        case .remove:      return localized(en: "Enter current password to remove", uz: "O'chirish uchun amaldagi parolni kiriting", ru: "Введите текущий пароль для удаления", zh: "输入当前密码以移除")
        }
    }

    // MARK: - Error strings

    static var mismatch: String {
        localized(en: "Codes don't match", uz: "Kod mos kelmadi", ru: "Коды не совпадают", zh: "密码不一致")
    }

    static var wrongCode: String {
        localized(en: "Incorrect code", uz: "Noto'g'ri kod", ru: "Неверный код", zh: "密码错误")
    }

    static var wrongPassword: String {
        localized(en: "Incorrect password", uz: "Noto'g'ri parol", ru: "Неверный пароль", zh: "密码错误")
    }

    static var passwordMismatch: String {
        localized(en: "Passwords don't match", uz: "Parol mos kelmadi", ru: "Пароли не совпадают", zh: "密码不一致")
    }

    // MARK: - Biometric toggle prompt (shown after first-time setup)

    static var biometricPromptTitle: String {
        localized(en: "Enable Biometrics?", uz: "Biometrikani yoqish?", ru: "Включить биометрию?", zh: "开启生物识别？")
    }

    static func biometricPromptSubtitle(type: ChatLockBiometricType) -> String {
        switch type {
        case .faceID:
            return localized(en: "Unlock this chat with Face ID", uz: "Chatni Face ID bilan oching", ru: "Разблокировать Face ID", zh: "使用 Face ID 解锁此聊天")
        case .touchID:
            return localized(en: "Unlock this chat with Touch ID", uz: "Chatni Touch ID bilan oching", ru: "Разблокировать Touch ID", zh: "使用 Touch ID 解锁此聊天")
        }
    }

    static var biometricEnable: String {
        localized(en: "Enable", uz: "Yoqish", ru: "Включить", zh: "开启")
    }

    static var biometricSkip: String {
        localized(en: "Skip", uz: "O'tkazib yuborish", ru: "Пропустить", zh: "跳过")
    }

    // MARK: - Type picker (shown at the START of the setup flow)

    static var chooseTypeTitle: String {
        localized(en: "Lock Type", uz: "Qulf turi", ru: "Тип блокировки", zh: "锁定方式")
    }

    static var chooseTypePin: String {
        localized(en: "4-digit PIN", uz: "4 raqamli PIN", ru: "4-значный PIN", zh: "4 位数字 PIN 码")
    }

    static var chooseTypeText: String {
        localized(en: "Alphanumeric Password", uz: "Harfli-raqamli parol", ru: "Буквенно-цифровой пароль", zh: "字母数字密码")
    }

    // MARK: - Biometric reason (the system prompt shown by iOS)

    static var biometricReason: String {
        localized(
            en: "Use biometrics to unlock this chat",
            uz: "Chatni biometrika bilan oching",
            ru: "Разблокировать чат с помощью биометрии",
            zh: "使用生物识别解锁此聊天"
        )
    }

    // MARK: - Keyboard return key

    static var done: String {
        localized(en: "Done", uz: "Tayyor", ru: "Готово", zh: "完成")
    }

    // MARK: - Forgot pincode (master-pincode recovery)

    static var forgotPincode: String {
        localized(en: "Forgot pincode?", uz: "Pinkodni unutdingizmi?", ru: "Забыли пин-код?", zh: "忘记密码？")
    }

    // MARK: - Context-menu titles (localized — fixes the previously hardcoded Uzbek)
    public static var menuSet: String {
        localized(en: "Set Pincode", uz: "Pincode qo'yish", ru: "Установить пин-код", zh: "设置密码")
    }
    public static var menuRemove: String {
        localized(en: "Remove Pincode", uz: "Pincode o'chirish", ru: "Удалить пин-код", zh: "移除密码")
    }

    // MARK: - Master reset (device-owner recovery when the master pincode itself is forgotten)

    static var resetButtonTitle: String {
        localized(en: "Reset Chat Lock", uz: "Chat Lock'ni reset qilish", ru: "Сбросить Chat Lock", zh: "重置聊天锁")
    }
    static var resetConfirmTitle: String {
        localized(en: "Reset Chat Lock?", uz: "Chat Lock reset qilinsinmi?", ru: "Сбросить Chat Lock?", zh: "重置聊天锁？")
    }
    static var resetConfirmMessage: String {
        // Say the passcode works up front. Someone whose Face ID is broken or switched off will
        // otherwise assume the reset is closed to them and stay locked out of their own chat.
        localized(
            en: "Confirm with Face ID, Touch ID or your iPhone passcode — any of them works.\n\nThis removes the master pincode and unlocks every chat. Your messages are not deleted.",
            uz: "Face ID, Touch ID yoki iPhone parolingiz bilan tasdiqlang — har qaysisi ishlaydi.\n\nBu asosiy pinkodni o'chiradi va barcha chatlarni ochadi. Xabarlaringiz o'chmaydi.",
            ru: "Подтвердите с помощью Face ID, Touch ID или код-пароля iPhone — подойдёт любой.\n\nЭто удалит главный пин-код и разблокирует все чаты. Сообщения не удаляются.",
            zh: "请使用 Face ID、Touch ID 或 iPhone 密码进行确认，任选其一即可。\n\n此操作将移除主密码并解锁所有聊天。你的消息不会被删除。"
        )
    }
    static var resetConfirmAction: String {
        localized(en: "Reset", uz: "Reset", ru: "Сбросить", zh: "重置")
    }
    static var cancel: String {
        localized(en: "Cancel", uz: "Bekor qilish", ru: "Отмена", zh: "取消")
    }
    static var resetReason: String {
        localized(en: "Confirm your identity to reset Chat Lock", uz: "Chat Lock'ni reset qilish uchun shaxsingizni tasdiqlang", ru: "Подтвердите личность для сброса Chat Lock", zh: "验证身份以重置聊天锁")
    }
    static var resetUsePasscode: String {
        localized(en: "Use iPhone Passcode", uz: "iPhone parolidan foydalanish", ru: "Ввести код-пароль", zh: "使用 iPhone 密码")
    }
    static var resetFailedTitle: String {
        localized(en: "Not Confirmed", uz: "Tasdiqlanmadi", ru: "Не подтверждено", zh: "未通过验证")
    }
    static var resetFailedMessage: String {
        localized(en: "Chat Lock was not reset. Confirm with Face ID, Touch ID or your iPhone passcode to continue.", uz: "Chat Lock reset qilinmadi. Davom etish uchun Face ID, Touch ID yoki iPhone parolingiz bilan tasdiqlang.", ru: "Chat Lock не сброшен. Подтвердите с помощью Face ID, Touch ID или код-пароля iPhone.", zh: "聊天锁未重置。请使用 Face ID、Touch ID 或 iPhone 密码确认后继续。")
    }
    static var resetRetry: String {
        localized(en: "Try Again", uz: "Qayta urinish", ru: "Повторить", zh: "重试")
    }
    static var recoveryHint: String {
        localized(en: "Forgot it? Use the option below.", uz: "Unutdingizmi? Pastdagi variantdan foydalaning.", ru: "Забыли? Используйте вариант ниже.", zh: "忘记了？请使用下方的选项。")
    }

    // MARK: - Helpers

    private static func localized(en: String, uz: String, ru: String, zh: String) -> String {
        let lang = Locale.current.languageCode ?? "en"
        switch lang {
        case "uz": return uz
        case "ru": return ru
        case "zh": return zh
        default:   return en
        }
    }
}

// Step used internally by ChatPincodeViewController to drive the title/subtitle.
enum ChatLockSetupStep {
    case enterNew
    case confirmNew
    case verify
    case verifyMaster
    case remove
}

// Biometric type detected at runtime.
enum ChatLockBiometricType {
    case faceID
    case touchID
}
