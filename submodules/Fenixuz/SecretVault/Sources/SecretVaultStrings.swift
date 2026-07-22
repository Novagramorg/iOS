import Foundation

/// Localized strings for the Hidden Chats feature (SecretVault module — settings
/// entry, chat-list bulk action, undo toast and the vault screen). Self-contained
/// en/uz/ru so the module never has to touch the central FenixuzL10n.
public enum SecretVaultStrings {

    // MARK: - Vault screen

    public static var screenTitle: String {
        localized(en: "Hidden Chats", uz: "Yashirin chatlar", ru: "Скрытые чаты")
    }

    public static var emptyTitle: String {
        localized(en: "No hidden chats", uz: "Yashirin chatlar yo'q", ru: "Нет скрытых чатов")
    }

    public static var emptyText: String {
        localized(
            en: "Chats you hide will appear here and stay out of your main list.",
            uz: "Berkitgan chatlaringiz shu yerda ko'rinadi va asosiy ro'yxatda chiqmaydi.",
            ru: "Скрытые чаты появятся здесь и не будут показываться в основном списке."
        )
    }

    // MARK: - Chat-list bulk action + context menu

    /// Short label for the selection toolbar button.
    public static var hideAction: String {
        localized(en: "Hide", uz: "Berkitish", ru: "Скрыть")
    }

    public static var removeFromVaultAction: String {
        localized(en: "Unhide", uz: "Ochish", ru: "Показать")
    }

    // MARK: - Undo toast

    public static func movedToVault(count: Int) -> String {
        if count <= 1 {
            return localized(en: "Chat hidden", uz: "Chat berkitildi", ru: "Чат скрыт")
        }
        return localized(
            en: "\(count) chats hidden",
            uz: "\(count) ta chat berkitildi",
            ru: "\(count) чатов скрыто"
        )
    }

    public static func removedFromVault(count: Int) -> String {
        if count <= 1 {
            return localized(en: "Chat unhidden", uz: "Chat ochildi", ru: "Чат показан")
        }
        return localized(
            en: "\(count) chats unhidden",
            uz: "\(count) ta chat ochildi",
            ru: "\(count) чатов показано"
        )
    }

    public static var undo: String {
        localized(en: "Undo", uz: "Bekor qilish", ru: "Отменить")
    }

    // MARK: - Settings entry

    public static func settingsTitle(langCode: String) -> String {
        localized(lang: langCode, en: "Hidden Chats", uz: "Yashirin chatlar", ru: "Скрытые чаты")
    }

    public static func settingsSubtitle(langCode: String) -> String {
        localized(lang: langCode, en: "Hide chats behind a passcode", uz: "Chatlarni kod-parol ostida yashirish", ru: "Скрыть чаты за код-паролем")
    }

    public static var settingsHeader: String {
        localized(en: "HIDDEN CHATS", uz: "YASHIRIN CHATLAR", ru: "СКРЫТЫЕ ЧАТЫ")
    }

    public static func settingsFooter(langCode: String) -> String {
        localized(
            lang: langCode,
            en: "Hidden chats disappear from your main list and are muted. To open them, long-press the “Chats” title, then enter your passcode.",
            uz: "Yashirin chatlar asosiy ro'yxatdan yo'qoladi va ovozsiz bo'ladi. Ularni ochish uchun “Chats” sarlavhasini bosib turing, so'ng kod-parolni kiriting.",
            ru: "Скрытые чаты исчезают из основного списка и отключают уведомления. Чтобы открыть их, зажмите заголовок «Chats» и введите код-пароль."
        )
    }

    public static var settingsChangePin: String {
        localized(en: "Change Passcode", uz: "Kod-parolni o'zgartirish", ru: "Изменить код-пароль")
    }

    public static func settingsHiddenCount(_ count: Int) -> String {
        localized(
            en: "\(count) hidden",
            uz: "\(count) ta berkitilgan",
            ru: "\(count) скрыто"
        )
    }

    // MARK: - Biometric unlock toggle

    /// Toggle title, adapted to the device's biometric hardware.
    public static func biometricToggleTitle(faceID: Bool) -> String {
        if faceID {
            return localized(en: "Unlock with Face ID", uz: "Face ID bilan ochish", ru: "Открывать с Face ID")
        }
        return localized(en: "Unlock with Touch ID", uz: "Touch ID bilan ochish", ru: "Открывать с Touch ID")
    }

    public static var biometricFooter: String {
        localized(
            en: "Use Face ID or Touch ID to open your hidden chats. Your passcode still works if biometrics fail.",
            uz: "Yashirin chatlarni ochish uchun Face ID yoki Touch ID'dan foydalaning. Biometrika ishlamasa, kod-parol baribir ishlaydi.",
            ru: "Используйте Face ID или Touch ID, чтобы открыть скрытые чаты. Если биометрия не сработает, код-пароль по-прежнему доступен."
        )
    }

    public static var biometricReason: String {
        localized(
            en: "Confirm to open your hidden chats with biometrics",
            uz: "Yashirin chatlarni biometrika bilan ochishni tasdiqlang",
            ru: "Подтвердите открытие скрытых чатов по биометрии"
        )
    }

    // MARK: - Disable confirmation

    public static var disableConfirmTitle: String {
        localized(en: "Turn off Hidden Chats?", uz: "Yashirin chatlar o'chirilsinmi?", ru: "Отключить скрытые чаты?")
    }

    public static var disableConfirmText: String {
        localized(
            en: "All hidden chats will return to the main list and be unmuted, and the passcode will be removed.",
            uz: "Barcha yashirin chatlar asosiy ro'yxatga qaytadi, ovozi yoqiladi va kod-parol o'chiriladi.",
            ru: "Все скрытые чаты вернутся в основной список, звук включится, а код-пароль будет удалён."
        )
    }

    public static var disableConfirmAction: String {
        localized(en: "Turn Off", uz: "O'chirish", ru: "Отключить")
    }

    public static var cancel: String {
        localized(en: "Cancel", uz: "Bekor qilish", ru: "Отмена")
    }

    // MARK: - Verify prompt (shown when opening hidden chats from the title)

    public static var verifyTitle: String {
        localized(en: "Hidden Chats", uz: "Yashirin chatlar", ru: "Скрытые чаты")
    }

    public static var verifySubtitle: String {
        localized(en: "Enter your passcode", uz: "Kod-parolni kiriting", ru: "Введите код-пароль")
    }

    // MARK: - Forgot-passcode recovery (Face ID / passcode) + unhide

    public static var recoveryReason: String {
        localized(
            en: "Confirm your identity to open your hidden chats",
            uz: "Yashirin chatlarni ochish uchun shaxsingizni tasdiqlang",
            ru: "Подтвердите личность, чтобы открыть скрытые чаты"
        )
    }

    public static var unhideMenu: String {
        localized(en: "Unhide", uz: "Ochish", ru: "Показать")
    }

    // MARK: - Helper

    private static func localized(en: String, uz: String, ru: String) -> String {
        let lang = Locale.current.languageCode ?? "en"
        switch lang {
        case "uz": return uz
        case "ru": return ru
        default:   return en
        }
    }

    // Language-aware overload: resolves from the app's selected language (langCode) instead of
    // the device system language, so these strings follow the in-app language like every sibling provider.
    private static func localized(lang: String, en: String, uz: String, ru: String) -> String {
        switch lang {
        case "uz": return uz
        case "ru": return ru
        default:   return en
        }
    }
}
