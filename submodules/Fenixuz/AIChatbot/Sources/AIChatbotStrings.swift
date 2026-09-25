import Foundation

// Local string namespace for the AI empty-state view.
// The view has no PresentationData, so it resolves the UI language from
// Locale.current.languageCode (same pattern as the SecretVault module).

enum AIChatbotStrings {
    private static func localized(en: String, uz: String, ru: String, zh: String) -> String {
        switch Locale.current.languageCode {
        case "uz": return uz
        case "ru": return ru
        case "zh": return zh
        default:   return en
        }
    }

    static var retryButton: String {
        localized(
            en: "Retry",
            uz: "Qayta urinib ko'rish",
            ru: "Попробовать снова",
            zh: "重试"
        )
    }

    static var loadingTitle: String {
        localized(
            en: "AI Assistant",
            uz: "AI Yordamchi",
            ru: "AI-ассистент",
            zh: "AI 助手"
        )
    }

    static var loadingSubtitle: String {
        localized(
            en: "Loading…",
            uz: "Tayyorlanmoqda…",
            ru: "Загрузка…",
            zh: "加载中…"
        )
    }

    static var notAvailableTitle: String {
        localized(
            en: "AI is not available yet",
            uz: "AI hozircha mavjud emas",
            ru: "AI пока недоступен",
            zh: "AI 暂不可用"
        )
    }

    static var notAvailableSubtitle: String {
        localized(
            en: "AI assistant was not found on the server.\nTry again later.",
            uz: "AI yordamchi serverda topilmadi.\nKeyinroq qayta urinib ko'ring.",
            ru: "AI-ассистент не найден на сервере.\nПопробуйте позже.",
            zh: "服务器上未找到 AI 助手。\n请稍后再试。"
        )
    }

    static var errorTitle: String {
        localized(
            en: "Error",
            uz: "Xatolik",
            ru: "Ошибка",
            zh: "错误"
        )
    }
}
