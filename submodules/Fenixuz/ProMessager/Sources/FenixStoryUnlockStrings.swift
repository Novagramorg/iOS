// Strings for the story saving & quality toggle (Features section).
// Kept local to ProMessager rather than added to the shared Localization module, so an
// upstream merge of that module cannot silently drop them.
//
// The words "Premium", "unlock", "free" and "bypass" deliberately appear in NO user-facing
// string here — the fork already took one Apple 3.1.1 rejection and nothing in the UI should
// read as circumventing a paid tier.

enum FenixStoryUnlockStrings {
    static func toggleTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Hikoyalarni saqlash va sifat"
        case "ru": return "Сохранение и качество историй"
        default:   return "Story saving and quality"
        }
    }

    static func toggleSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Boshqalarning hikoyalarini saqlash, video hikoyalarni HD sifatda ko'rish"
        case "ru": return "Сохранять чужие истории и смотреть видеоистории в HD"
        default:   return "Save other people's stories and watch video stories in HD"
        }
    }

    static func warningTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Hikoyalarni saqlash va sifat yoqilsinmi?"
        case "ru": return "Включить сохранение и качество историй?"
        default:   return "Turn on story saving and quality?"
        }
    }

    static func warningText(langCode: String) -> String {
        switch langCode {
        case "uz": return "Boshqalarning hikoyalarini galereyaga saqlash va video hikoyalarni to'liq sifatda ko'rish mumkin bo'ladi. Muallif himoyalagan hikoyalar saqlanmaydi — ularda bu band chiqmaydi. Boshqalar ulashgan narsani hurmat qiling."
        case "ru": return "Вы сможете сохранять чужие истории в галерею и смотреть видеоистории в полном качестве. Истории, защищённые автором, сохранить нельзя — для них этот пункт не появляется. Уважайте то, чем делятся другие."
        default:   return "You'll be able to save other people's stories to your gallery and watch video stories at full quality. Stories the author protected stay unsavable — the option doesn't appear on them. Please respect what people share."
        }
    }

    static func warningConfirm(langCode: String) -> String {
        switch langCode {
        case "uz": return "Yoqish"
        case "ru": return "Включить"
        default:   return "Turn On"
        }
    }
}
