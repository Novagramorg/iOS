// Local string namespace for the translation screens (auto-translate + translation languages).
// Shared by FenixTranslateController and FenixTranslationController.
// Kept in ProMessager to avoid parallel-edit hazard on the shared Localization module.

enum FenixTranslateStrings {
    // MARK: - Language row label states

    static func selectedLabel(langCode: String) -> String {
        switch langCode {
        case "uz": return "✅ Tanlangan"
        case "ru": return "✅ Выбрано"
        case "zh": return "✅ 已选择"
        default:   return "✅ Selected"
        }
    }

    static func downloadLabel(langCode: String) -> String {
        switch langCode {
        case "uz": return "Yuklash"
        case "ru": return "Загрузить"
        case "zh": return "下载"
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
            case "zh": return "英语"
            default:   return "English"
            }
        case "ru":
            switch langCode {
            case "uz": return "Rus tili"
            case "ru": return "Русский"
            case "zh": return "俄语"
            default:   return "Russian"
            }
        case "uz":
            switch langCode {
            case "uz": return "O'zbek tili"
            case "ru": return "Узбекский"
            case "zh": return "乌兹别克语"
            default:   return "Uzbek"
            }
        case "tr":
            switch langCode {
            case "uz": return "Turk tili"
            case "ru": return "Турецкий"
            case "zh": return "土耳其语"
            default:   return "Turkish"
            }
        case "de":
            switch langCode {
            case "uz": return "Nemis tili"
            case "ru": return "Немецкий"
            case "zh": return "德语"
            default:   return "German"
            }
        case "fr":
            switch langCode {
            case "uz": return "Fransuz tili"
            case "ru": return "Французский"
            case "zh": return "法语"
            default:   return "French"
            }
        case "es":
            switch langCode {
            case "uz": return "Ispan tili"
            case "ru": return "Испанский"
            case "zh": return "西班牙语"
            default:   return "Spanish"
            }
        case "it":
            switch langCode {
            case "uz": return "Italyan tili"
            case "ru": return "Итальянский"
            case "zh": return "意大利语"
            default:   return "Italian"
            }
        case "ar":
            switch langCode {
            case "uz": return "Arab tili"
            case "ru": return "Арабский"
            case "zh": return "阿拉伯语"
            default:   return "Arabic"
            }
        case "zh":
            switch langCode {
            case "uz": return "Xitoy tili"
            case "ru": return "Китайский"
            case "zh": return "中文"
            default:   return "Chinese"
            }
        case "ja":
            switch langCode {
            case "uz": return "Yapon tili"
            case "ru": return "Японский"
            case "zh": return "日语"
            default:   return "Japanese"
            }
        case "ko":
            switch langCode {
            case "uz": return "Koreys tili"
            case "ru": return "Корейский"
            case "zh": return "韩语"
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
        case "zh": return "开启后，你发送的所有消息都会自动翻译成你所选的语言。"
        default:   return "When enabled, all messages you send are automatically translated into the language you selected via its language code."
        }
    }

    static func autoToggleTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Avtomatik tarjima qilish"
        case "ru": return "Автоперевод"
        case "zh": return "自动翻译"
        default:   return "Auto-translate"
        }
    }

    static func autoToggleSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Barcha chiqayotgan xabarlarni tarjima qilib yuborish"
        case "ru": return "Переводить все исходящие сообщения перед отправкой"
        case "zh": return "发送前翻译所有发出的消息"
        default:   return "Translate all outgoing messages before sending"
        }
    }

    static func autoLanguagesHeader(langCode: String) -> String {
        switch langCode {
        case "uz": return "TARJIMA TILLARI (YUKLAB OLISH VA TANLASH)"
        case "ru": return "ЯЗЫКИ ПЕРЕВОДА (ЗАГРУЗКА И ВЫБОР)"
        case "zh": return "翻译语言（下载并选择）"
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
        case "zh": return "翻译语言"
        default:   return "Translation Languages"
        }
    }
}
