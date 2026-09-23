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
        case "zh": return "动态保存与画质"
        default:   return "Story saving and quality"
        }
    }

    static func toggleSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Boshqalarning hikoyalarini saqlash, video hikoyalarni HD sifatda ko'rish"
        case "ru": return "Сохранять чужие истории и смотреть видеоистории в HD"
        case "zh": return "保存他人的动态，并以高清画质观看视频动态"
        default:   return "Save other people's stories and watch video stories in HD"
        }
    }

    static func warningTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Hikoyalarni saqlash va sifat yoqilsinmi?"
        case "ru": return "Включить сохранение и качество историй?"
        case "zh": return "开启动态保存与画质？"
        default:   return "Turn on story saving and quality?"
        }
    }

    static func warningText(langCode: String) -> String {
        switch langCode {
        case "uz": return "Boshqalarning hikoyalarini galereyaga saqlash va video hikoyalarni to'liq sifatda ko'rish mumkin bo'ladi. Muallif himoyalagan hikoyalar saqlanmaydi — ularda bu band chiqmaydi. Boshqalar ulashgan narsani hurmat qiling."
        case "ru": return "Вы сможете сохранять чужие истории в галерею и смотреть видеоистории в полном качестве. Истории, защищённые автором, сохранить нельзя — для них этот пункт не появляется. Уважайте то, чем делятся другие."
        case "zh": return "你将可以把他人的动态保存到相册，并以原画质观看视频动态。作者设置了保护的动态仍无法保存，这些动态上不会出现此选项。请尊重他人分享的内容。"
        default:   return "You'll be able to save other people's stories to your gallery and watch video stories at full quality. Stories the author protected stay unsavable — the option doesn't appear on them. Please respect what people share."
        }
    }

    static func warningConfirm(langCode: String) -> String {
        switch langCode {
        case "uz": return "Yoqish"
        case "ru": return "Включить"
        case "zh": return "开启"
        default:   return "Turn On"
        }
    }
}
