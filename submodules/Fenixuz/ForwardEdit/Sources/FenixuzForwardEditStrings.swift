import Foundation
import TelegramPresentationData

/// Strings for "Edit and Send". They live in this module instead of FenixuzL10n so the feature
/// has no dependency on (and no merge conflicts with) the other Fenixuz modules.
struct FenixuzForwardEditStrings {
    private let languageKey: String

    init(_ strings: PresentationStrings) {
        self.languageKey = FenixuzForwardEditStrings.languageKey(for: strings)
    }

    private static func languageKey(for strings: PresentationStrings) -> String {
        let codes: [String] = [
            strings.primaryComponent.languageCode,
            strings.secondaryComponent?.languageCode,
            strings.primaryComponent.pluralizationRulesCode
        ].compactMap { $0?.lowercased() }

        // Chinese community packs use arbitrary codes ("zhcncc", "taiwan"), only their base
        // language or plural rules say "zh".
        if codes.contains(where: { $0.hasPrefix("zh") || $0.contains("-zh") || $0.contains("_zh") }) {
            return "zh"
        }
        for code in codes {
            if code.hasPrefix("uz") {
                return "uz"
            }
            if code.hasPrefix("ru") {
                return "ru"
            }
        }
        return "en"
    }

    private func pick(en: String, uz: String, ru: String, zh: String) -> String {
        switch self.languageKey {
        case "uz":
            return uz
        case "ru":
            return ru
        case "zh":
            return zh
        default:
            return en
        }
    }

    var menuTitle: String {
        return self.pick(en: "Edit and Send", uz: "Tahrirlab yuborish", ru: "Изменить и отправить", zh: "编辑后发送")
    }

    var screenTitle: String {
        return self.pick(en: "Edit Post", uz: "Postni tahrirlash", ru: "Редактирование", zh: "编辑帖子")
    }

    var captionPlaceholder: String {
        return self.pick(en: "Add a caption…", uz: "Izoh qo'shing…", ru: "Добавьте подпись…", zh: "添加说明…")
    }

    var textPlaceholder: String {
        return self.pick(en: "Post text", uz: "Post matni", ru: "Текст поста", zh: "帖子内容")
    }

    var footerNote: String {
        return self.pick(
            en: "Sent as a new post: the original sender is not shown and there is no “edited” label.",
            uz: "Yangi post sifatida yuboriladi: asl yuboruvchi ko'rinmaydi va «tahrirlangan» belgisi chiqmaydi.",
            ru: "Отправится как новый пост: без исходного отправителя и без метки «изменено».",
            zh: "将作为新帖子发送：不显示原发送者，也没有“已编辑”标记。"
        )
    }

    var buttonsNotCopied: String {
        return self.pick(
            en: "Buttons under the post are not copied.",
            uz: "Post ostidagi tugmalar ko'chirilmaydi.",
            ru: "Кнопки под постом не копируются.",
            zh: "帖子下方的按钮不会被复制。"
        )
    }

    func tooLong(limit: Int) -> String {
        return self.pick(
            en: "Too long: at most \(limit) characters.",
            uz: "Matn juda uzun: ko'pi bilan \(limit) ta belgi.",
            ru: "Слишком длинно: не больше \(limit) символов.",
            zh: "内容过长：最多 \(limit) 个字符。"
        )
    }
}
