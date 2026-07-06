import Foundation

/// Strings shown in the local reminder notification itself.
///
/// These are resolved at background-schedule time where no `PresentationStrings`
/// instance is available, so they pick on the device's preferred language rather
/// than the in-app localization. Kept local to the module (settings-screen strings
/// live in `FenixuzL10n`).
enum FenixuzUnreadReminderStrings {
    private static var langCode: String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("uz") { return "uz" }
        if preferred.hasPrefix("ru") { return "ru" }
        return "en"
    }

    static func notificationTitle() -> String {
        switch langCode {
        case "uz": return "O'qilmagan xabarlar"
        case "ru": return "Непрочитанные сообщения"
        default:   return "Unread messages"
        }
    }

    static func notificationBody(count: Int) -> String {
        switch langCode {
        case "uz":
            return "Sizda \(count) ta o'qilmagan xabar bor. Ularni ko'rishni unutmang."
        case "ru":
            return "У вас \(count) непрочитанных сообщений. Не забудьте их просмотреть."
        default:
            return "You have \(count) unread messages. Don't forget to check them."
        }
    }
}
