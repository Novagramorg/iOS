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

// MARK: - Available Text Styles

public enum FenixTextStyle: String, CaseIterable {
    case none          = "none"
    case bold          = "bold"
    case italic        = "italic"
    case monospace     = "monospace"
    case strikethrough = "strikethrough"
    case underline     = "underline"
    case spoiler       = "spoiler"

    public func displayName(langCode: String) -> String {
        switch self {
        case .none:
            switch langCode {
            case "uz": return "Uslubsiz (Oddiy)"
            case "ru": return "Без стиля (обычный)"
            default:   return "No style (Plain)"
            }
        case .bold:
            switch langCode {
            case "uz": return "Qalin (Bold)"
            case "ru": return "Жирный (Bold)"
            default:   return "Bold"
            }
        case .italic:
            switch langCode {
            case "uz": return "Kiyshiq (Italic)"
            case "ru": return "Курсив (Italic)"
            default:   return "Italic"
            }
        case .monospace:
            switch langCode {
            case "uz": return "Monospace (Kod)"
            case "ru": return "Моноширинный (Код)"
            default:   return "Monospace (Code)"
            }
        case .strikethrough:
            switch langCode {
            case "uz": return "Chizilgan (Strikethrough)"
            case "ru": return "Зачёркнутый (Strikethrough)"
            default:   return "Strikethrough"
            }
        case .underline:
            switch langCode {
            case "uz": return "Tagiga chizilgan (Underline)"
            case "ru": return "Подчёркнутый (Underline)"
            default:   return "Underline"
            }
        case .spoiler:
            return "Spoiler"
        }
    }

    public static var current: FenixTextStyle {
        let rawValue = UserDefaults(suiteName: "pro_messager")?.string(forKey: "text_style") ?? "none"
        return FenixTextStyle(rawValue: rawValue) ?? .none
    }
}

// MARK: - Localized strings

private enum FenixTextStyleStrings {
    static func selectedBadge(langCode: String) -> String {
        switch langCode {
        case "uz": return "✓ Tanlangan"
        case "ru": return "✓ Выбрано"
        default:   return "✓ Selected"
        }
    }

    static func title(langCode: String) -> String {
        switch langCode {
        case "uz": return "Xabar uslubi"
        case "ru": return "Стиль сообщения"
        default:   return "Message style"
        }
    }
}

// MARK: - Section & Entry

private enum TextStyleSection: Int32 {
    case styles
}

private enum TextStyleEntry: ItemListNodeEntry {
    case styleItem(Int32, PresentationTheme, String, Bool, FenixTextStyle)

    var section: ItemListSectionId {
        return TextStyleSection.styles.rawValue
    }

    var stableId: Int32 {
        switch self {
        case let .styleItem(index, _, _, _, _):
            return index
        }
    }

    static func == (lhs: TextStyleEntry, rhs: TextStyleEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.styleItem(li, lt, ln, ls, lStyle), .styleItem(ri, rt, rn, rs, rStyle)):
            return li == ri && lt === rt && ln == rn && ls == rs && lStyle == rStyle
        }
    }

    static func < (lhs: TextStyleEntry, rhs: TextStyleEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! TextStyleArguments
        switch self {
        case let .styleItem(_, theme, name, isSelected, style):
            let label = isSelected ? FenixTextStyleStrings.selectedBadge(langCode: presentationData.strings.primaryComponent.languageCode) : ""
            let labelStyle: ItemListDisclosureLabelStyle = isSelected
                ? .badge(theme.list.itemAccentColor)
                : .text
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: name,
                label: label,
                labelStyle: labelStyle,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.selectStyle(style)
                }
            )
        }
    }
}

// MARK: - State

private struct TextStyleControllerState: Equatable {
    var selectedStyle: FenixTextStyle

    init() {
        self.selectedStyle = FenixTextStyle.current
    }
}

// MARK: - Arguments

private final class TextStyleArguments {
    let selectStyle: (FenixTextStyle) -> Void

    init(selectStyle: @escaping (FenixTextStyle) -> Void) {
        self.selectStyle = selectStyle
    }
}

// MARK: - Entries builder

private func textStyleEntries(
    presentationData: PresentationData,
    state: TextStyleControllerState
) -> [TextStyleEntry] {
    var entries: [TextStyleEntry] = []
    let langCode = presentationData.strings.primaryComponent.languageCode
    for (index, style) in FenixTextStyle.allCases.enumerated() {
        let isSelected = state.selectedStyle == style
        entries.append(.styleItem(
            Int32(index),
            presentationData.theme,
            style.displayName(langCode: langCode),
            isSelected,
            style
        ))
    }
    return entries
}

// MARK: - Controller factory

public func fenixTextStyleController(context: AccountContext, onStyleSelected: @escaping (String) -> Void = { _ in }) -> ViewController {
    let statePromise = ValuePromise(TextStyleControllerState(), ignoreRepeated: true)
    let stateValue  = Atomic(value: TextStyleControllerState())

    let updateState: ((TextStyleControllerState) -> TextStyleControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    let arguments = TextStyleArguments(selectStyle: { style in
        UserDefaults(suiteName: "pro_messager")?.set(style.rawValue, forKey: "text_style")
        onStyleSelected(style.rawValue)
        updateState { state in
            var state = state
            state.selectedStyle = style
            return state
        }
    })

    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(FenixTextStyleStrings.title(langCode: presentationData.strings.primaryComponent.languageCode)),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: textStyleEntries(presentationData: presentationData, state: state),
            style: .blocks
        )
        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}
