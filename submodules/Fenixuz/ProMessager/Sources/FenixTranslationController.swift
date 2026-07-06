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
import TranslateUI

private final class FenixTranslationArguments {
    let context: AccountContext
    let selectLanguage: (String) -> Void
    let downloadLanguage: (String) -> Void
    
    init(context: AccountContext, selectLanguage: @escaping (String) -> Void, downloadLanguage: @escaping (String) -> Void) {
        self.context = context
        self.selectLanguage = selectLanguage
        self.downloadLanguage = downloadLanguage
    }
}

private enum FenixTranslationSection: Int32 {
    case languages
}

private enum FenixTranslationEntry: ItemListNodeEntry {
    case language(Int32, PresentationTheme, String, String, Bool, Bool)
    
    var section: ItemListSectionId {
        return FenixTranslationSection.languages.rawValue
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
    
    static func ==(lhs: FenixTranslationEntry, rhs: FenixTranslationEntry) -> Bool {
        switch (lhs, rhs) {
            case (let .language(lhsIndex, lhsTheme, lhsName, lhsCode, lhsIsSelected, lhsIsDownloaded), let .language(rhsIndex, rhsTheme, rhsName, rhsCode, rhsIsSelected, rhsIsDownloaded)):
                return lhsIndex == rhsIndex && lhsTheme === rhsTheme && lhsName == rhsName && lhsCode == rhsCode && lhsIsSelected == rhsIsSelected && lhsIsDownloaded == rhsIsDownloaded
        }
    }
    
    static func <(lhs: FenixTranslationEntry, rhs: FenixTranslationEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! FenixTranslationArguments
        switch self {
            case let .language(_, theme, name, code, isSelected, isDownloaded):
                return ItemListDisclosureItem(presentationData: presentationData, title: name, label: isDownloaded ? (isSelected ? "✅ Tanlangan" : "✅") : "Yuklash", labelStyle: isSelected ? .badge(theme.list.itemAccentColor) : .detailText, sectionId: self.section, style: .blocks, action: {
                    if isDownloaded {
                        arguments.selectLanguage(code)
                    } else {
                        arguments.downloadLanguage(code)
                    }
                })
        }
    }
}

private struct FenixTranslationState: Equatable {
    var downloadedLanguages: Set<String>
    var selectedLanguage: String?
    
    init() {
        let defaults = UserDefaults(suiteName: "pro_messager_translation")
        self.downloadedLanguages = Set(defaults?.stringArray(forKey: "downloaded_languages") ?? ["en", "ru", "uz"])
        self.selectedLanguage = defaults?.string(forKey: "selected_language") ?? "en"
    }
}

private func fenixTranslationEntries(presentationData: PresentationData, state: FenixTranslationState) -> [FenixTranslationEntry] {
    var entries: [FenixTranslationEntry] = []
    
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
        entries.append(.language(Int32(index), presentationData.theme, lang.0, lang.1, state.selectedLanguage == lang.1, state.downloadedLanguages.contains(lang.1)))
    }
    
    return entries
}

public func fenixTranslationController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(FenixTranslationState(), ignoreRepeated: true)
    let stateValue = Atomic(value: FenixTranslationState())
    let updateState: ((FenixTranslationState) -> FenixTranslationState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let arguments = FenixTranslationArguments(context: context, selectLanguage: { code in
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
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Tarjima Tillari"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: fenixTranslationEntries(presentationData: presentationData, state: state), style: .blocks)
            return (controllerState, (listState, arguments))
        }
    
    let controller = ItemListController(context: context, state: signal)
    return controller
}
