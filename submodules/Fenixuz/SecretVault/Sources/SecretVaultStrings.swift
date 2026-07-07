import Foundation

/// Localized strings for the Secret Vault feature (settings entry, chat-list bulk
/// action, undo toast and the vault screen). Self-contained en/uz/ru so the module
/// never has to touch the central FenixuzL10n.
public enum SecretVaultStrings {

    // MARK: - Vault screen

    public static var screenTitle: String {
        localized(en: "Secret Vault", uz: "Maxfiy seyf", ru: "Секретное хранилище")
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

    public static var settingsTitle: String {
        localized(en: "Secret Vault", uz: "Maxfiy seyf", ru: "Секретное хранилище")
    }

    public static var settingsSubtitle: String {
        localized(en: "Hide chats behind a PIN", uz: "Chatlarni PIN ostida yashirish", ru: "Скрыть чаты за PIN-кодом")
    }

    public static var settingsHeader: String {
        localized(en: "SECRET VAULT", uz: "MAXFIY SEYF", ru: "СЕКРЕТНОЕ ХРАНИЛИЩЕ")
    }

    public static var settingsFooter: String {
        localized(
            en: "Hidden chats disappear from the main list and are muted. To open the vault, long-press the “Chats” title or tap it 10 times, then enter your vault PIN.",
            uz: "Berkitilgan chatlar asosiy ro'yxatdan yo'qoladi va ovozsiz qilinadi. Seyfni ochish uchun “Chats” sarlavhasini bosib turing yoki 10 marta bosing, so'ng seyf PIN'ini kiriting.",
            ru: "Скрытые чаты исчезают из основного списка и отключают уведомления. Чтобы открыть хранилище, зажмите заголовок «Chats» или нажмите на него 10 раз, затем введите PIN хранилища."
        )
    }

    public static var settingsChangePin: String {
        localized(en: "Change Vault PIN", uz: "Seyf PIN'ini o'zgartirish", ru: "Изменить PIN хранилища")
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
            en: "Use Face ID or Touch ID to open the vault. Your PIN still works if biometrics fail.",
            uz: "Seyfni ochish uchun Face ID yoki Touch ID'dan foydalaning. Biometrika ishlamasa, PIN baribir ishlaydi.",
            ru: "Используйте Face ID или Touch ID для открытия хранилища. Если биометрия не сработает, PIN по-прежнему доступен."
        )
    }

    public static var biometricReason: String {
        localized(
            en: "Confirm to unlock the Secret Vault with biometrics",
            uz: "Maxfiy seyfni biometrika bilan ochishni tasdiqlang",
            ru: "Подтвердите разблокировку секретного хранилища по биометрии"
        )
    }

    // MARK: - Disable confirmation

    public static var disableConfirmTitle: String {
        localized(en: "Turn off Secret Vault?", uz: "Maxfiy seyf o'chirilsinmi?", ru: "Отключить секретное хранилище?")
    }

    public static var disableConfirmText: String {
        localized(
            en: "All hidden chats will return to the main list and be unmuted, and the vault PIN will be removed.",
            uz: "Barcha yashirin chatlar asosiy ro'yxatga qaytadi, ovozi yoqiladi va seyf PIN'i o'chiriladi.",
            ru: "Все скрытые чаты вернутся в основной список, звук включится, а PIN хранилища будет удалён."
        )
    }

    public static var disableConfirmAction: String {
        localized(en: "Turn Off", uz: "O'chirish", ru: "Отключить")
    }

    public static var cancel: String {
        localized(en: "Cancel", uz: "Bekor qilish", ru: "Отмена")
    }

    // MARK: - Verify prompt (shown when opening the vault from the title)

    public static var verifyTitle: String {
        localized(en: "Secret Vault", uz: "Maxfiy seyf", ru: "Секретное хранилище")
    }

    public static var verifySubtitle: String {
        localized(en: "Enter your vault PIN", uz: "Seyf PIN'ini kiriting", ru: "Введите PIN хранилища")
    }

    // MARK: - Forgot-PIN recovery (Face ID / passcode) + unhide

    public static var recoveryReason: String {
        localized(
            en: "Confirm your identity to open the Secret Vault",
            uz: "Maxfiy seyfni ochish uchun shaxsingizni tasdiqlang",
            ru: "Подтвердите личность, чтобы открыть секретное хранилище"
        )
    }

    public static var unhideMenu: String {
        localized(en: "Unhide from Vault", uz: "Seyfdan chiqarish", ru: "Убрать из хранилища")
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
}
