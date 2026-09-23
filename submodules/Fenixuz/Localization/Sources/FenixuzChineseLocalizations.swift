import Foundation
import TelegramCore

/// Telegram ships no official Chinese localization, so the server's language list usually has no
/// Chinese and a Chinese user has to find a `t.me/setlanguage/...` link first. (It does list Chinese
/// on a device that has already used a Chinese pack.) These are the two Chinese packs on Telegram's
/// own translation platform, the same ones `t.me/setlanguage/zh-hans-raw` opens.
public enum FenixuzChineseLocalizations {
    static let packs: [LocalizationInfo] = [
        LocalizationInfo(
            languageCode: "zh-hans-raw",
            baseLanguageCode: nil,
            customPluralizationCode: "zh",
            title: "Chinese (Simplified)",
            localizedTitle: "简体中文",
            isOfficial: true,
            totalStringCount: 0,
            translatedStringCount: 0,
            platformUrl: "https://translations.telegram.org/zh-hans/"
        ),
        LocalizationInfo(
            languageCode: "zh-hant-raw",
            baseLanguageCode: nil,
            customPluralizationCode: "zh",
            title: "Chinese (Traditional)",
            localizedTitle: "繁體中文",
            isOfficial: true,
            totalStringCount: 0,
            translatedStringCount: 0,
            platformUrl: "https://translations.telegram.org/zh-hant/"
        )
    ]

    /// The list state with the Chinese packs slotted into the alphabetical part of the official list.
    /// The server puts English and the user's regional language (Uzbek for our users) first and
    /// sorts the rest by English name, so a pack goes to the first place where its neighbours are
    /// in order around it, and to the end if there is none. A pack is skipped when the list already
    /// has it by code or by English name, because the server's own Chinese entries (when it sends
    /// them) use other codes, and an installed pack is listed too. `isOfficial` is true only so the
    /// row can't be swiped away like an installed pack; picking it downloads the pack.
    public static func adding(to state: LocalizationListState) -> LocalizationListState {
        // An empty official list means it is still loading and the screen shows placeholders.
        if state.availableOfficialLocalizations.isEmpty {
            return state
        }
        let listed = state.availableOfficialLocalizations + state.availableSavedLocalizations
        let knownCodes = Set(listed.map { $0.languageCode })
        let knownTitles = Set(listed.map { $0.title.lowercased() })
        var official = state.availableOfficialLocalizations
        for pack in packs where !knownCodes.contains(pack.languageCode) && !knownTitles.contains(pack.title.lowercased()) {
            let index = official.indices.dropFirst().first(where: { index in
                official[index - 1].title.localizedCaseInsensitiveCompare(pack.title) == .orderedAscending &&
                official[index].title.localizedCaseInsensitiveCompare(pack.title) == .orderedDescending
            }) ?? official.count
            official.insert(pack, at: index)
        }
        var result = state
        result.availableOfficialLocalizations = official
        return result
    }
}
