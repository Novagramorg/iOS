import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI
import TranslateUI
import NovagramLocalization

private final class NovagramTranslationArguments {
    let context: AccountContext
    let selectLanguage: (String) -> Void
    let downloadLanguage: (String) -> Void

    init(context: AccountContext, selectLanguage: @escaping (String) -> Void, downloadLanguage: @escaping (String) -> Void) {
        self.context = context
        self.selectLanguage = selectLanguage
        self.downloadLanguage = downloadLanguage
    }
}

private enum NovagramTranslationSection: Int32 {
    case languages
}

private enum NovagramTranslationEntry: ItemListNodeEntry {
    case language(Int32, PresentationTheme, String, String, Bool, Bool)

    var section: ItemListSectionId {
        return NovagramTranslationSection.languages.rawValue
    }

    var stableId: Int32 {
        switch self {
            case let .language(index, _, _, _, _, _):
                return index
        }
    }

    var sortId: Int {
        switch self {
            case let .language(index, _, _, _, _, _):
                return Int(index)
        }
    }

    static func == (lhs: NovagramTranslationEntry, rhs: NovagramTranslationEntry) -> Bool {
        switch (lhs, rhs) {
            case (let .language(lhsIndex, lhsTheme, lhsName, lhsCode, lhsIsSelected, lhsIsDownloaded), let .language(rhsIndex, rhsTheme, rhsName, rhsCode, rhsIsSelected, rhsIsDownloaded)):
                return lhsIndex == rhsIndex && lhsTheme === rhsTheme && lhsName == rhsName && lhsCode == rhsCode && lhsIsSelected == rhsIsSelected && lhsIsDownloaded == rhsIsDownloaded
        }
    }

    static func < (lhs: NovagramTranslationEntry, rhs: NovagramTranslationEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NovagramTranslationArguments
        switch self {
            case let .language(_, theme, name, code, isSelected, isDownloaded):
                let langCode = NovagramL10n.languageKey(for: presentationData.strings)
                let label = isDownloaded ? (isSelected ? NovagramTranslateStrings.selectedLabel(langCode: langCode) : "✅") : NovagramTranslateStrings.downloadLabel(langCode: langCode)
                return ItemListDisclosureItem(presentationData: presentationData, title: name, label: label, labelStyle: isSelected ? .badge(theme.list.itemAccentColor) : .detailText, sectionId: self.section, style: .blocks, action: {
                    if isDownloaded {
                        arguments.selectLanguage(code)
                    } else {
                        arguments.downloadLanguage(code)
                    }
                })
        }
    }
}

private struct NovagramTranslationState: Equatable {
    var downloadedLanguages: Set<String>
    var selectedLanguage: String?

    init() {
        let defaults = UserDefaults(suiteName: "pro_messager_translation")
        self.downloadedLanguages = Set(defaults?.stringArray(forKey: "downloaded_languages") ?? ["en", "ru", "uz"])
        self.selectedLanguage = defaults?.string(forKey: "selected_language") ?? "en"
    }
}

private func novagramTranslationEntries(presentationData: PresentationData, state: NovagramTranslationState) -> [NovagramTranslationEntry] {
    var entries: [NovagramTranslationEntry] = []
    let langCode = NovagramL10n.languageKey(for: presentationData.strings)

    let languageCodes = ["en", "ru", "uz", "tr", "de", "fr", "es", "it", "ar", "zh", "ja", "ko"]

    for (index, code) in languageCodes.enumerated() {
        entries.append(.language(Int32(index), presentationData.theme, NovagramTranslateStrings.languageName(code: code, langCode: langCode), code, state.selectedLanguage == code, state.downloadedLanguages.contains(code)))
    }

    return entries
}

public func novagramTranslationController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(NovagramTranslationState(), ignoreRepeated: true)
    let stateValue = Atomic(value: NovagramTranslationState())
    let updateState: ((NovagramTranslationState) -> NovagramTranslationState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    let arguments = NovagramTranslationArguments(context: context, selectLanguage: { code in
        UserDefaults(suiteName: "pro_messager_translation")?.set(code, forKey: "selected_language")
        updateState { state in
            var state = state
            state.selectedLanguage = code
            return state
        }
    }, downloadLanguage: { code in
        // Simulate download
        updateState { state in
            var state = state
            state.downloadedLanguages.insert(code)
            UserDefaults(suiteName: "pro_messager_translation")?.set(Array(state.downloadedLanguages), forKey: "downloaded_languages")
            return state
        }
    })

    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    ) |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(NovagramTranslateStrings.languagesTitle(langCode: NovagramL10n.languageKey(for: presentationData.strings))), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: novagramTranslationEntries(presentationData: presentationData, state: state), style: .blocks)
            return (controllerState, (listState, arguments))
        }

    let controller = ItemListController(context: context, state: signal)
    return controller
}
