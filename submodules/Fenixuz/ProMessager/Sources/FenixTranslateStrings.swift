// Local string namespace for the translation screens (auto-translate + translation languages).
// Shared by FenixTranslateController and FenixTranslationController.
// Kept in ProMessager to avoid parallel-edit hazard on the shared Localization module.

enum FenixTranslateStrings {
    // MARK: - Language row label states

    static func selectedLabel(langCode: String) -> String {
        switch langCode {
        case "uz": return "✅ Tanlangan"
        case "ru": return "✅ Выбрано"
        default:   return "✅ Selected"
        }
    }

    static func downloadLabel(langCode: String) -> String {
        switch langCode {
        case "uz": return "Yuklash"
        case "ru": return "Загрузить"
        default:   return "Download"
        }
    }

    // MARK: - Language display names

    static func languageName(code: String, langCode: String) -> String {
        switch code {
        case "en":
            switch langCode {
            case "uz": return "Ingliz tili"
            case "ru": return "Английский"
            default:   return "English"
            }
        case "ru":
            switch langCode {
            case "uz": return "Rus tili"
            case "ru": return "Русский"
            default:   return "Russian"
            }
        case "uz":
            switch langCode {
            case "uz": return "O'zbek tili"
            case "ru": return "Узбекский"
            default:   return "Uzbek"
            }
        case "tr":
            switch langCode {
            case "uz": return "Turk tili"
            case "ru": return "Турецкий"
            default:   return "Turkish"
            }
        case "de":
            switch langCode {
            case "uz": return "Nemis tili"
            case "ru": return "Немецкий"
            default:   return "German"
            }
        case "fr":
            switch langCode {
            case "uz": return "Fransuz tili"
            case "ru": return "Французский"
            default:   return "French"
            }
        case "es":
            switch langCode {
            case "uz": return "Ispan tili"
            case "ru": return "Испанский"
            default:   return "Spanish"
            }
        case "it":
            switch langCode {
            case "uz": return "Italyan tili"
            case "ru": return "Итальянский"
            default:   return "Italian"
            }
        case "ar":
            switch langCode {
            case "uz": return "Arab tili"
            case "ru": return "Арабский"
            default:   return "Arabic"
            }
        case "zh":
            switch langCode {
            case "uz": return "Xitoy tili"
            case "ru": return "Китайский"
            default:   return "Chinese"
            }
        case "ja":
            switch langCode {
            case "uz": return "Yapon tili"
            case "ru": return "Японский"
            default:   return "Japanese"
            }
        case "ko":
            switch langCode {
            case "uz": return "Koreys tili"
            case "ru": return "Корейский"
            default:   return "Korean"
            }
        default:
            return code
        }
    }

    // MARK: - Auto-translate screen

    static func autoInfo(langCode: String) -> String {
        switch langCode {
        case "uz": return "Bu funksiya yoqilganda o'zingiz tanlagan til kodi orqali barcha yuborayotgan xabarlaringiz avtomatik ravishda shu tilga tarjima qilinadi."
        case "ru": return "Когда функция включена, все отправляемые вами сообщения автоматически переводятся на выбранный вами язык."
        default:   return "When enabled, all messages you send are automatically translated into the language you selected via its language code."
        }
    }

    static func autoToggleTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Avtomatik tarjima qilish"
        case "ru": return "Автоперевод"
        default:   return "Auto-translate"
        }
    }

    static func autoToggleSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Barcha chiqayotgan xabarlarni tarjima qilib yuborish"
        case "ru": return "Переводить все исходящие сообщения перед отправкой"
        default:   return "Translate all outgoing messages before sending"
        }
    }

    static func autoLanguagesHeader(langCode: String) -> String {
        switch langCode {
        case "uz": return "TARJIMA TILLARI (YUKLAB OLISH VA TANLASH)"
        case "ru": return "ЯЗЫКИ ПЕРЕВОДА (ЗАГРУЗКА И ВЫБОР)"
        default:   return "TRANSLATION LANGUAGES (DOWNLOAD AND SELECT)"
        }
    }

    // MARK: - Screen titles

    static func autoTitle(langCode: String) -> String {
        return autoToggleTitle(langCode: langCode)
    }

    static func languagesTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Tarjima Tillari"
        case "ru": return "Языки перевода"
        default:   return "Translation Languages"
        }
    }
}
