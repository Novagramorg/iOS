import Foundation

// Local string namespace for the Speech-to-Text error toasts.
// This module has no access to PresentationData, so it resolves the UI language
// from Locale.current.languageCode (same pattern as the SecretVault module).

enum SpeechToTextStrings {
    private static func localized(en: String, uz: String, ru: String) -> String {
        switch Locale.current.languageCode {
        case "uz": return uz
        case "ru": return ru
        default:   return en
        }
    }

    static var permissionDenied: String {
        localized(
            en: "Speech recognition permission is not granted. Enable it in Settings.",
            uz: "Ovozni aniqlash ruxsati berilmagan. Sozlamalardan yoqing.",
            ru: "Доступ к распознаванию речи не предоставлен. Включите его в Настройках."
        )
    }

    static var restricted: String {
        localized(
            en: "Speech recognition is restricted on this device.",
            uz: "Bu qurilmada ovozni aniqlash cheklangan.",
            ru: "Распознавание речи ограничено на этом устройстве."
        )
    }

    static var notDetermined: String {
        localized(
            en: "Speech recognition permission is pending.",
            uz: "Ovozni aniqlash ruxsati kutilmoqda.",
            ru: "Ожидается разрешение на распознавание речи."
        )
    }

    static func languageUnsupported(langName: String) -> String {
        localized(
            en: "«\(langName)» does not support speech-to-text. Choose a supported language (for example, Russian) in Settings → Novagram → Voice language.",
            uz: "«\(langName)» tili ovozdan-matnga aylantirishni qo'llab-quvvatlamaydi. Sozlamalar → Novagram → Ovoz tili dan qo'llab-quvvatlanadigan til (masalan, Ruscha) tanlang.",
            ru: "Язык «\(langName)» не поддерживает преобразование речи в текст. Выберите поддерживаемый язык (например, русский) в Настройки → Novagram → Язык голоса."
        )
    }

    static var serviceUnavailable: String {
        localized(
            en: "The speech-to-text service is currently unavailable. Check your internet connection and try again.",
            uz: "Ovozdan-matnga xizmati hozir mavjud emas. Internet aloqasini tekshirib, qayta urinib ko'ring.",
            ru: "Служба преобразования речи в текст сейчас недоступна. Проверьте подключение к интернету и повторите попытку."
        )
    }

    static var requestCreateFailed: String {
        localized(
            en: "Could not create the speech recognition request.",
            uz: "Ovozni aniqlash so'rovini yaratib bo'lmadi.",
            ru: "Не удалось создать запрос на распознавание речи."
        )
    }

    static func audioFormatInvalid(sampleRate: Double, channels: UInt32) -> String {
        localized(
            en: "Invalid audio format: sampleRate=\(sampleRate), channels=\(channels)",
            uz: "Audio format noto'g'ri: sampleRate=\(sampleRate), channels=\(channels)",
            ru: "Неверный аудиоформат: sampleRate=\(sampleRate), channels=\(channels)"
        )
    }

    static func audioEngineFailed(description: String) -> String {
        localized(
            en: "Failed to start the audio engine: \(description)",
            uz: "Audio engine ishga tushmadi: \(description)",
            ru: "Не удалось запустить аудиодвижок: \(description)"
        )
    }

    static func recognitionError(code: Int, description: String) -> String {
        localized(
            en: "Error \(code): \(description)",
            uz: "Xato \(code): \(description)",
            ru: "Ошибка \(code): \(description)"
        )
    }

    static var voskModelNotFound: String {
        localized(
            en: "Voice language model not found.",
            uz: "Ovoz tili modeli topilmadi.",
            ru: "Модель языка голоса не найдена."
        )
    }

    static var voskModelLoading: String {
        localized(
            en: "The «Uzbek» model is still downloading. Connect to the internet, wait a moment and try again.",
            uz: "«O'zbekcha» modeli hali yuklanmoqda. Internetga ulanib, bir oz kutib qayta urinib ko'ring.",
            ru: "Модель «Узбекский» ещё загружается. Подключитесь к интернету, немного подождите и повторите попытку."
        )
    }

    static var voskRecognizerFailed: String {
        localized(
            en: "Could not start the speech recognizer.",
            uz: "Ovoz aniqlovchini ishga tushirib bo'lmadi.",
            ru: "Не удалось запустить распознаватель речи."
        )
    }

    static var audioConversionFailed: String {
        localized(
            en: "Could not set up audio conversion.",
            uz: "Audio konversiyani sozlab bo'lmadi.",
            ru: "Не удалось настроить преобразование аудио."
        )
    }
}
