import Foundation
import TelegramPresentationData
import NovagramLocalization
import NovagramAds

/// In-app strings of the Novagram ads UI (uz / ru / en; any other language gets English).
struct NovagramSponsoredStrings {
    private let language: String

    init(_ strings: PresentationStrings) {
        self.language = NovagramL10n.languageKey(for: strings)
    }

    private func pick(en: String, uz: String, ru: String) -> String {
        switch self.language {
        case "uz": return uz
        case "ru": return ru
        default: return en
        }
    }

    // MARK: - Channel message button (contract §3.3: the app translates button_type)

    var viewChannel: String {
        pick(en: "View channel", uz: "Kanalni ko'rish", ru: "Перейти в канал")
    }

    var openBot: String {
        pick(en: "Open bot", uz: "Botni ochish", ru: "Открыть бота")
    }

    func buttonText(for ad: SDKSponsoredAd) -> String {
        switch ad.buttonType {
        case .some(.bot):
            return self.openBot
        case .some(.channel):
            return self.viewChannel
        default:
            // `.unknown`, a future value, or no button type: fall back to the promoted peer's type.
            if case .bot = ad.promoted.type {
                return self.openBot
            }
            return self.viewChannel
        }
    }

    // MARK: - Menu

    var aboutAd: String {
        pick(en: "About this ad", uz: "Reklama haqida", ru: "Об этой рекламе")
    }

    var reportAd: String {
        pick(en: "Report ad", uz: "Shikoyat qilish", ru: "Пожаловаться")
    }

    var aboutTitle: String {
        pick(en: "Novagram Ads", uz: "Novagram reklamasi", ru: "Реклама Novagram")
    }

    var aboutText: String {
        pick(
            en: "This ad is shown by Novagram. It is chosen by the place where it appears and by your app language and country, never by your messages, contacts or phone number.",
            uz: "Bu reklamani Novagram ko'rsatmoqda. U chiqadigan joyi, ilova tili va mamlakatingiz bo'yicha tanlanadi — xabarlaringiz, kontaktlaringiz yoki telefon raqamingiz bo'yicha hech qachon emas.",
            ru: "Эту рекламу показывает Novagram. Она подбирается по месту показа, языку приложения и стране — никогда по вашим сообщениям, контактам или номеру телефона."
        )
    }

    func aboutText(otherInfo: String?) -> String {
        guard let otherInfo, !otherInfo.isEmpty else {
            return self.aboutText
        }
        return self.aboutText + "\n\n" + otherInfo
    }

    var ok: String {
        pick(en: "OK", uz: "OK", ru: "OK")
    }

    var cancel: String {
        pick(en: "Cancel", uz: "Bekor qilish", ru: "Отмена")
    }

    // MARK: - Report (contract §6: six reasons, then always thank the user)

    var reportTitle: String {
        pick(en: "Why are you reporting this ad?", uz: "Nega bu reklamadan shikoyat qilyapsiz?", ru: "Почему вы жалуетесь на эту рекламу?")
    }

    func reason(_ reason: SDKAdReportReason) -> String {
        switch reason {
        case .spam:
            return pick(en: "Spam", uz: "Spam", ru: "Спам")
        case .violence:
            return pick(en: "Violence", uz: "Zo'ravonlik", ru: "Насилие")
        case .pornography:
            return pick(en: "Pornography", uz: "Pornografiya", ru: "Порнография")
        case .illegal:
            return pick(en: "Illegal goods or services", uz: "Noqonuniy tovar yoki xizmat", ru: "Незаконные товары или услуги")
        case .misleading:
            return pick(en: "Misleading", uz: "Aldov, chalg'ituvchi", ru: "Обман, вводит в заблуждение")
        case .other:
            return pick(en: "Other", uz: "Boshqa", ru: "Другое")
        @unknown default:
            return pick(en: "Other", uz: "Boshqa", ru: "Другое")
        }
    }

    var reportSent: String {
        pick(en: "Thanks, your report was sent", uz: "Rahmat, shikoyatingiz yuborildi", ru: "Спасибо, ваша жалоба отправлена")
    }
}
