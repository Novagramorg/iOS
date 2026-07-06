import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI

// MARK: - UserDefaults keys
private let kSuiteName    = "pro_messager"
private let kEnabled      = "auto_translate_enabled"
private let kLang         = "auto_translate_lang"
private let kDownloaded   = "auto_translate_downloaded"
private let kVoiceTranslateEnabled = "voice_translate_enabled"

// MARK: - Voice-to-text translation utility

/// Translates `text` into `targetLang` (ISO 639-1 code, e.g. "en", "ru", "uz") using the
/// Telegram MTProto translation engine.  On any failure the `completion` is called with the
/// original `text` so the caller never receives an empty string.
///
/// - Parameters:
///   - text:       The transcribed voice text to translate.
///   - targetLang: ISO 639-1 target language code.  Reads `auto_translate_lang` from
///                 UserDefaults as a fallback; falls back further to "en".
///   - context:    The active Telegram AccountContext (provides the network).
///   - completion: Called on the main thread with the translated text (or `text` on failure).
public func fenixTranslateVoiceText(
    _ text: String,
    to targetLang: String,
    context: AccountContext,
    completion: @escaping (String) -> Void
) {
    guard !text.isEmpty else {
        completion(text)
        return
    }

    // Resolve the actual target language: caller > UserDefaults > "en"
    let resolvedLang: String = {
        if !targetLang.isEmpty { return targetLang }
        let saved = UserDefaults(suiteName: kSuiteName)?.string(forKey: kLang) ?? ""
        return saved.isEmpty ? "en" : saved
    }()

    let signal: Signal<(String, [MessageTextEntity])?, TranslationError> =
        context.engine.messages.translate(text: text, toLang: resolvedLang)

    // Keep a strong reference while the signal is alive
    var disposable: Disposable?
    disposable = signal.start(
        next: { result in
            DispatchQueue.main.async {
                if let translated = result?.0, !translated.isEmpty {
                    completion(translated)
                } else {
                    // Translation returned nothing — fall back to raw transcription
                    completion(text)
                }
                disposable?.dispose()
                disposable = nil
            }
        },
        error: { _ in
            // Any network / server error — fall back to raw transcription
            DispatchQueue.main.async {
                completion(text)
                disposable?.dispose()
                disposable = nil
            }
        },
        completed: {}
    )
}

/// Returns the currently saved voice-translate-enabled flag.
public var fenixVoiceTranslateEnabled: Bool {
    return UserDefaults(suiteName: kSuiteName)?.bool(forKey: kVoiceTranslateEnabled) ?? false
}

/// Returns the currently saved voice-translate target language (ISO 639-1).
/// Falls back to the auto-translate language, then "en".
public var fenixVoiceTranslateTargetLang: String {
    let ud = UserDefaults(suiteName: kSuiteName)
    let lang = ud?.string(forKey: kLang) ?? ""
    return lang.isEmpty ? "en" : lang
}

/// Persists the voice-translate-enabled flag.
public func fenixSetVoiceTranslateEnabled(_ enabled: Bool) {
    UserDefaults(suiteName: kSuiteName)?.set(enabled, forKey: kVoiceTranslateEnabled)
}

// MARK: - Section

private enum AutoTranslateSection: Int32 {
    case info
    case settings
    case languages
}

// MARK: - Entry

private enum AutoTranslateEntry: ItemListNodeEntry {
    case infoText(PresentationTheme, String)
    case enableToggle(PresentationTheme, String, String, Bool)
    case languagesHeader(PresentationTheme, String)
    case language(Int32, PresentationTheme, String, String, Bool, Bool)

    var section: ItemListSectionId {
        switch self {
        case .infoText:         return AutoTranslateSection.info.rawValue
        case .enableToggle:     return AutoTranslateSection.settings.rawValue
        case .languagesHeader, .language: return AutoTranslateSection.languages.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .infoText:         return 0
        case .enableToggle:     return 1
        case .languagesHeader:  return 2
        case let .language(index, _, _, _, _, _): return 3 + index
        }
    }

    static func == (lhs: AutoTranslateEntry, rhs: AutoTranslateEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.infoText(lt, la), .infoText(rt, ra)):
            return lt === rt && la == ra
        case let (.enableToggle(lt, lti, ltx, lv), .enableToggle(rt, rti, rtx, rv)):
            return lt === rt && lti == rti && ltx == rtx && lv == rv
        case let (.languagesHeader(lt, la), .languagesHeader(rt, ra)):
            return lt === rt && la == ra
        case let (.language(li, lt, ln, lc, ls, ld), .language(ri, rt, rn, rc, rs, rd)):
            return li == ri && lt === rt && ln == rn && lc == rc && ls == rs && ld == rd
        default:
            return false
        }
    }

    static func < (lhs: AutoTranslateEntry, rhs: AutoTranslateEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! AutoTranslateArguments
        switch self {
        case let .infoText(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section, style: .blocks)

        case let .enableToggle(_, title, desc, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, text: desc, value: value, sectionId: self.section, style: .blocks, updated: { val in
                args.updateEnabled(val)
            })

        case let .languagesHeader(_, title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)

        case let .language(_, theme, name, code, isSelected, isDownloaded):
            return ItemListDisclosureItem(presentationData: presentationData, title: name, label: isDownloaded ? (isSelected ? "✅ Tanlangan" : "✅") : "Yuklash", labelStyle: isSelected ? .badge(theme.list.itemAccentColor) : .detailText, sectionId: self.section, style: .blocks, action: {
                if isDownloaded {
                    args.updateLang(code)
                } else {
                    args.downloadLang(code)
                }
            })
        }
    }
}

// MARK: - State

private struct AutoTranslateState: Equatable {
    var isEnabled: Bool
    var lang: String
    var downloadedLanguages: Set<String>

    init() {
        let ud = UserDefaults(suiteName: kSuiteName)
        self.isEnabled = ud?.bool(forKey: kEnabled) ?? false
        self.lang      = ud?.string(forKey: kLang) ?? ""
        self.downloadedLanguages = Set(ud?.stringArray(forKey: kDownloaded) ?? ["en", "ru", "uz"])
    }
}

// MARK: - Arguments

private final class AutoTranslateArguments {
    let updateEnabled: (Bool) -> Void
    let updateLang: (String) -> Void
    let downloadLang: (String) -> Void

    init(updateEnabled: @escaping (Bool) -> Void,
         updateLang: @escaping (String) -> Void,
         downloadLang: @escaping (String) -> Void) {
        self.updateEnabled = updateEnabled
        self.updateLang = updateLang
        self.downloadLang = downloadLang
    }
}

// MARK: - Entries builder

private func autoTranslateEntries(presentationData: PresentationData, state: AutoTranslateState) -> [AutoTranslateEntry] {
    var entries: [AutoTranslateEntry] = []

    entries.append(.infoText(presentationData.theme,
        "Bu funksiya yoqilganda o'zingiz tanlagan til kodi orqali barcha yuborayotgan xabarlaringiz avtomatik ravishda shu tilga tarjima qilinadi."))

    entries.append(.enableToggle(presentationData.theme,
        "Avtomatik tarjima qilish",
        "Barcha chiqayotgan xabarlarni tarjima qilib yuborish",
        state.isEnabled))

    entries.append(.languagesHeader(presentationData.theme, "TARJIMA TILLARI (YUKLAB OLISH VA TANLASH)"))

    let languages = [
        ("Ingliz tili", "en"),
        ("Rus tili", "ru"),
        ("O'zbek tili", "uz"),
        ("Turk tili", "tr"),
        ("Nemis tili", "de"),
        ("Fransuz tili", "fr"),
        ("Ispan tili", "es"),
        ("Ital yan tili", "it"),
        ("Arab tili", "ar"),
        ("Xitoy tili", "zh"),
        ("Yapon tili", "ja"),
        ("Koreys tili", "ko")
    ]

    for (index, lang) in languages.enumerated() {
        let isSelected = state.lang == lang.1
        let isDownloaded = state.downloadedLanguages.contains(lang.1)
        entries.append(.language(Int32(index), presentationData.theme, lang.0, lang.1, isSelected, isDownloaded))
    }

    return entries
}

// MARK: - Controller factory

public func fenixTranslateAutoController(context: AccountContext, onEnabledSelected: ((Bool) -> Void)? = nil) -> ViewController {
    let statePromise = ValuePromise(AutoTranslateState(), ignoreRepeated: true)
    let stateValue   = Atomic(value: AutoTranslateState())

    let updateState: ((AutoTranslateState) -> AutoTranslateState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    let ud = UserDefaults(suiteName: kSuiteName)

    let arguments = AutoTranslateArguments(
        updateEnabled: { val in
            ud?.set(val, forKey: kEnabled)
            updateState { s in var s = s; s.isEnabled = val; return s }
            onEnabledSelected?(val)
        },
        updateLang: { text in
            ud?.set(text, forKey: kLang)
            updateState { s in var s = s; s.lang = text; return s }
        },
        downloadLang: { code in
            updateState { s in
                var s = s
                s.downloadedLanguages.insert(code)
                ud?.set(Array(s.downloadedLanguages), forKey: kDownloaded)
                return s
            }
        }
    )

    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Avtomatik tarjima qilish"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: autoTranslateEntries(presentationData: presentationData, state: state),
            style: .blocks
        )
        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}
