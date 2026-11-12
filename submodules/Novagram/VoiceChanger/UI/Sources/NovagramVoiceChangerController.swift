import Foundation
import UIKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI
import NovagramLocalization
import NovagramVoiceChanger

// The voice changer's list of effects (HOOKS.md, "Voice changer"), one page for voice messages and one for calls,
// opened from the rows under the Voice changer switch in the Developer section. The same effects, in the same order,
// as the Android app. "Record speed" asks for one of four speeds; Modulation, Echo and Noise show their settings
// under the name and get a Settings block with one row per value while chosen. Calls have no speed row, as a live
// voice can't be played faster or slower.

private final class NovagramVoiceChangerArguments {
    let select: (Int) -> Void
    let editValue: (NovagramVoiceChangerValue) -> Void

    init(select: @escaping (Int) -> Void, editValue: @escaping (NovagramVoiceChangerValue) -> Void) {
        self.select = select
        self.editValue = editValue
    }
}

private enum NovagramVoiceChangerValue: Int {
    case tone
    case echoDelay
    case echoVolume
    case noiseVolume
}

private enum NovagramVoiceChangerSection: Int32 {
    case effects
    case settings
}

private enum NovagramVoiceChangerEntry: ItemListNodeEntry {
    case header(String)
    case effect(index: Int, id: Int, title: String, subtitle: String?, checked: Bool)
    case footer(String)
    case settingsHeader(String)
    case value(NovagramVoiceChangerValue, String, String)

    var section: ItemListSectionId {
        switch self {
        case .header, .effect, .footer:
            return NovagramVoiceChangerSection.effects.rawValue
        case .settingsHeader, .value:
            return NovagramVoiceChangerSection.settings.rawValue
        }
    }

    var stableId: Int {
        switch self {
        case .header:
            return 0
        case let .effect(index, _, _, _, _):
            return 1 + index
        case .footer:
            return 100
        case .settingsHeader:
            return 200
        case let .value(value, _, _):
            return 201 + value.rawValue
        }
    }

    static func == (lhs: NovagramVoiceChangerEntry, rhs: NovagramVoiceChangerEntry) -> Bool {
        switch lhs {
        case let .header(text):
            if case .header(text) = rhs { return true } else { return false }
        case let .effect(index, id, title, subtitle, checked):
            if case .effect(index, id, title, subtitle, checked) = rhs { return true } else { return false }
        case let .footer(text):
            if case .footer(text) = rhs { return true } else { return false }
        case let .settingsHeader(text):
            if case .settingsHeader(text) = rhs { return true } else { return false }
        case let .value(value, title, label):
            if case .value(value, title, label) = rhs { return true } else { return false }
        }
    }

    static func < (lhs: NovagramVoiceChangerEntry, rhs: NovagramVoiceChangerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NovagramVoiceChangerArguments
        switch self {
        case let .header(text), let .settingsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .effect(_, id, title, subtitle, checked):
            // The row draws its icon from the bitmap, which ignores a symbol's tint, so the colour is baked in.
            let symbol = UIImage(systemName: NovagramVoiceChangerStrings.symbol(id), withConfiguration: UIImage.SymbolConfiguration(pointSize: 20.0, weight: .regular))
            let icon = generateTintedImage(image: symbol, color: presentationData.theme.list.itemAccentColor)
            return ItemListCheckboxItem(presentationData: presentationData, icon: icon, iconSize: CGSize(width: 24.0, height: 24.0), title: title, subtitle: subtitle, style: .right, checked: checked, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.select(id)
            })
        case let .footer(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .value(value, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.editValue(value)
            })
        }
    }
}

private struct NovagramVoiceChangerState: Equatable {
    var presetId: Int
    var params: NovagramVoiceParams
}

private func novagramVoiceChangerEntries(state: NovagramVoiceChangerState, forCall: Bool, langCode: String) -> [NovagramVoiceChangerEntry] {
    var entries: [NovagramVoiceChangerEntry] = []
    entries.append(.header(forCall ? NovagramVoiceChangerStrings.calls(langCode) : NovagramVoiceChangerStrings.voiceMessages(langCode)))
    var index = 0
    for id in NovagramVoicePreset.rows {
        if forCall && id == NovagramVoicePreset.speedRow {
            continue
        }
        let checked: Bool
        var subtitle: String?
        if id == NovagramVoicePreset.speedRow {
            checked = NovagramVoicePreset.isSpeed(state.presetId)
            if checked {
                subtitle = NovagramVoiceChangerStrings.presetName(state.presetId, langCode)
            }
        } else {
            checked = id == state.presetId
            subtitle = NovagramVoiceChangerStrings.settingsText(id, state.params, langCode)
        }
        entries.append(.effect(index: index, id: id, title: NovagramVoiceChangerStrings.presetName(id, langCode), subtitle: subtitle, checked: checked))
        index += 1
    }
    entries.append(.footer(forCall ? NovagramVoiceChangerStrings.callsFooter(langCode) : NovagramVoiceChangerStrings.voiceMessagesFooter(langCode)))

    if NovagramVoicePreset.hasSettings(state.presetId) {
        entries.append(.settingsHeader(NovagramVoiceChangerStrings.presetName(state.presetId, langCode)))
        let params = state.params
        switch state.presetId {
        case NovagramVoicePreset.modulation:
            entries.append(.value(.tone, NovagramVoiceChangerStrings.tone(langCode), NovagramVoiceChangerStrings.toneText(params.tone)))
        case NovagramVoicePreset.echo:
            entries.append(.value(.echoDelay, NovagramVoiceChangerStrings.delay(langCode), NovagramVoiceChangerStrings.secondsText(params.echoDelay, langCode)))
            entries.append(.value(.echoVolume, NovagramVoiceChangerStrings.volume(langCode), NovagramVoiceChangerStrings.percentText(params.echoVolume)))
        default:
            entries.append(.value(.noiseVolume, NovagramVoiceChangerStrings.volume(langCode), NovagramVoiceChangerStrings.percentText(params.noiseVolume)))
        }
    }
    return entries
}

/// The effects page for voice messages (`forCall` false) or calls. `asSheet`: opened over a chat or a call rather
/// than pushed in Settings, so it gets a close button instead of Back.
public func novagramVoiceChangerController(context: AccountContext, forCall: Bool, asSheet: Bool = false) -> ViewController {
    let choice = forCall ? NovagramVoiceChanger.calls : NovagramVoiceChanger.messages
    let statePromise = ValuePromise(NovagramVoiceChangerState(presetId: choice.presetId, params: choice.params), ignoreRepeated: true)
    let refreshState: () -> Void = {
        statePromise.set(NovagramVoiceChangerState(presetId: choice.presetId, params: choice.params))
    }
    var presentControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?

    // A small sheet of choices, the current one ticked.
    let presentChoices: (String, [(String, Bool, () -> Void)]) -> Void = { title, options in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationData: presentationData)
        let dismiss: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        var items: [ActionSheetItem] = [ActionSheetTextItem(title: title)]
        for (label, isCurrent, action) in options {
            items.append(ActionSheetCheckboxItem(title: label, label: "", value: isCurrent, action: { _ in
                dismiss()
                action()
                refreshState()
            }))
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: dismiss)])
        ])
        presentControllerImpl?(controller)
    }

    let arguments = NovagramVoiceChangerArguments(select: { id in
        let langCode = NovagramL10n.languageKey(for: context.sharedContext.currentPresentationData.with { $0 }.strings)
        if id == NovagramVoicePreset.speedRow {
            let current = choice.presetId
            presentChoices(NovagramVoiceChangerStrings.presetName(NovagramVoicePreset.speedRow, langCode), NovagramVoicePreset.speeds.map { speed in
                (NovagramVoiceChangerStrings.presetName(speed, langCode), speed == current, { choice.presetId = speed })
            })
            return
        }
        choice.presetId = id
        refreshState()
    }, editValue: { value in
        let langCode = NovagramL10n.languageKey(for: context.sharedContext.currentPresentationData.with { $0 }.strings)
        let params = choice.params
        let title: String
        let range: ClosedRange<Int>
        let current: Int
        let text: (Int) -> String
        let apply: (Int) -> Void
        switch value {
        case .tone:
            title = NovagramVoiceChangerStrings.toneHint(langCode)
            range = NovagramVoiceParams.toneRange
            current = params.tone
            text = { NovagramVoiceChangerStrings.toneText($0) }
            apply = { var p = choice.params; p.tone = $0; choice.params = p }
        case .echoDelay:
            title = NovagramVoiceChangerStrings.delay(langCode)
            range = NovagramVoiceParams.stepRange
            current = params.echoDelay
            text = { NovagramVoiceChangerStrings.secondsText($0, langCode) }
            apply = { var p = choice.params; p.echoDelay = $0; choice.params = p }
        case .echoVolume:
            title = NovagramVoiceChangerStrings.volume(langCode)
            range = NovagramVoiceParams.stepRange
            current = params.echoVolume
            text = { NovagramVoiceChangerStrings.percentText($0) }
            apply = { var p = choice.params; p.echoVolume = $0; choice.params = p }
        case .noiseVolume:
            title = NovagramVoiceChangerStrings.volume(langCode)
            range = NovagramVoiceParams.stepRange
            current = params.noiseVolume
            text = { NovagramVoiceChangerStrings.percentText($0) }
            apply = { var p = choice.params; p.noiseVolume = $0; choice.params = p }
        }
        presentChoices(title, range.reversed().map { step in
            (text(step), step == current, { apply(step) })
        })
    })

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
        |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(NovagramVoiceChangerStrings.title(langCode)), leftNavigationButton: asSheet ? ItemListNavigationButton(content: .icon(.close), style: .regular, enabled: true, action: { dismissImpl?() }) : nil, rightNavigationButton: nil, backNavigationButton: asSheet ? nil : ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: novagramVoiceChangerEntries(state: state, forCall: forCall, langCode: langCode), style: .blocks)
            return (controllerState, (listState, arguments))
        }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    return controller
}

// MARK: - Strings

/// The voice changer's texts, the Android app's wording (LanguageCode 467–495) plus Chinese.
public enum NovagramVoiceChangerStrings {
    private static func pick(_ langCode: String, en: String, uz: String, ru: String, zh: String) -> String {
        switch langCode {
        case "uz": return uz
        case "ru": return ru
        case "zh": return zh
        default:   return en
        }
    }

    public static func title(_ l: String) -> String {
        return pick(l, en: "Voice changer", uz: "Ovoz o'zgartirgich", ru: "Изменение голоса", zh: "变声器")
    }

    public static func voiceMessages(_ l: String) -> String {
        return pick(l, en: "Voice messages", uz: "Ovozli xabarlar", ru: "Голосовые сообщения", zh: "语音消息")
    }

    public static func calls(_ l: String) -> String {
        return pick(l, en: "Calls", uz: "Qo'ng'iroqlar", ru: "Звонки", zh: "通话")
    }

    public static func switchTip(_ l: String) -> String {
        return pick(l,
            en: "Record voice messages and speak in calls in another voice: robot, woman, child and more. Choose the effects below.",
            uz: "Ovozli xabarni boshqa ovozda yozing va qo'ng'iroqda boshqa ovozda gapiring: robot, ayol, bola va boshqalar. Effektlarni pastda tanlang.",
            ru: "Записывайте голосовые и говорите в звонках другим голосом: робот, женщина, ребёнок и другие. Эффекты выбираются ниже.",
            zh: "用另一种声音录制语音消息和通话：机器人、女声、童声等。在下方选择效果。")
    }

    static func voiceMessagesFooter(_ l: String) -> String {
        return pick(l,
            en: "Record voice messages in another voice: robot, woman, child and more.",
            uz: "Ovozli xabarni boshqa ovozda yozing: robot, ayol, bola va boshqalar.",
            ru: "Записывайте голосовые другим голосом: робот, женщина, ребёнок и другие.",
            zh: "用另一种声音录制语音消息：机器人、女声、童声等。")
    }

    static func callsFooter(_ l: String) -> String {
        return pick(l,
            en: "Speak in another voice in calls and group calls. A change applies at once, also during a call.",
            uz: "Qo'ng'iroq va guruh qo'ng'iroqlarida boshqa ovozda gapiring. O'zgarish darhol, qo'ng'iroq paytida ham ishlaydi.",
            ru: "Говорите другим голосом в звонках и групповых звонках. Изменение действует сразу, и во время звонка.",
            zh: "在通话和群组通话中用另一种声音说话。更改立即生效，通话中也一样。")
    }

    static func delay(_ l: String) -> String {
        return pick(l, en: "Delay", uz: "Kechikish", ru: "Задержка", zh: "延迟")
    }

    static func volume(_ l: String) -> String {
        return pick(l, en: "Volume", uz: "Balandlik", ru: "Громкость", zh: "音量")
    }

    static func tone(_ l: String) -> String {
        return pick(l, en: "Tone", uz: "Ton", ru: "Тон", zh: "音调")
    }

    static func toneHint(_ l: String) -> String {
        return pick(l,
            en: "In semitones: + makes the voice higher, - lower.",
            uz: "Yarim tonlarda: + ovozni ingichka, - yo'g'on qiladi.",
            ru: "В полутонах: + делает голос выше, - ниже.",
            zh: "以半音为单位：+ 提高音调，- 降低音调。")
    }

    static func toneText(_ tone: Int) -> String {
        return tone > 0 ? "+\(tone)" : "\(tone)"
    }

    static func percentText(_ step: Int) -> String {
        return "\(step * 10)%"
    }

    static func secondsText(_ step: Int, _ l: String) -> String {
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), Double(step) / 10.0) + " " + pick(l, en: "sec", uz: "soniya", ru: "сек", zh: "秒")
    }

    /// A preset's settings as its row shows them under the name: "+5", "70%, 0.5 sec", "70%".
    static func settingsText(_ id: Int, _ params: NovagramVoiceParams, _ l: String) -> String? {
        switch id {
        case NovagramVoicePreset.modulation:
            return toneText(params.tone)
        case NovagramVoicePreset.echo:
            return percentText(params.echoVolume) + ", " + secondsText(params.echoDelay, l)
        case NovagramVoicePreset.noise:
            return percentText(params.noiseVolume)
        default:
            return nil
        }
    }

    /// The name of a preset, a speed, or the "Record speed" row.
    public static func presetName(_ id: Int, _ l: String) -> String {
        switch id {
        case NovagramVoicePreset.off: return pick(l, en: "Off", uz: "O'chiq", ru: "Выключено", zh: "关闭")
        case NovagramVoicePreset.speedRow: return pick(l, en: "Record speed (thick or thin)", uz: "Yozish tezligi (yo'g'on yoki ingichka)", ru: "Скорость записи (толще или тоньше)", zh: "录制速度（低沉或尖细）")
        case NovagramVoicePreset.robot: return pick(l, en: "Robotic", uz: "Robot", ru: "Робот", zh: "机器人")
        case NovagramVoicePreset.alien: return pick(l, en: "Alien", uz: "O'zga sayyoralik", ru: "Пришелец", zh: "外星人")
        case NovagramVoicePreset.hoarseness: return pick(l, en: "Hoarseness", uz: "Xirillash", ru: "Хрипота", zh: "沙哑")
        case NovagramVoicePreset.modulation: return pick(l, en: "Modulation", uz: "Modulyatsiya", ru: "Модуляция", zh: "变调")
        case NovagramVoicePreset.child: return pick(l, en: "Child", uz: "Bola", ru: "Ребёнок", zh: "儿童")
        case NovagramVoicePreset.mouse: return pick(l, en: "Mouse", uz: "Sichqon", ru: "Мышь", zh: "老鼠")
        case NovagramVoicePreset.man: return pick(l, en: "Man", uz: "Erkak", ru: "Мужчина", zh: "男声")
        case NovagramVoicePreset.woman: return pick(l, en: "Woman", uz: "Ayol", ru: "Женщина", zh: "女声")
        case NovagramVoicePreset.monster: return pick(l, en: "Monster", uz: "Maxluq", ru: "Монстр", zh: "怪物")
        case NovagramVoicePreset.echo: return pick(l, en: "Echo", uz: "Aks-sado", ru: "Эхо", zh: "回声")
        case NovagramVoicePreset.noise: return pick(l, en: "Noise", uz: "Shovqin", ru: "Шум", zh: "噪音")
        case NovagramVoicePreset.helium: return pick(l, en: "Helium", uz: "Geliy", ru: "Гелий", zh: "氦气")
        case NovagramVoicePreset.hexafluoride: return pick(l, en: "Hexafluoride", uz: "Geksaftorid", ru: "Гексафторид", zh: "六氟化硫")
        case NovagramVoicePreset.cave: return pick(l, en: "Cave", uz: "G'or", ru: "Пещера", zh: "洞穴")
        case 16: return pick(l, en: "Very thick", uz: "Juda yo'g'on", ru: "Очень толсто", zh: "非常低沉")
        case 17: return pick(l, en: "Thick", uz: "Yo'g'on", ru: "Толсто", zh: "低沉")
        case 18: return pick(l, en: "Thin", uz: "Ingichka", ru: "Тонко", zh: "尖细")
        case 19: return pick(l, en: "Very thin", uz: "Juda ingichka", ru: "Очень тонко", zh: "非常尖细")
        default: return ""
        }
    }

    /// SF Symbols instead of the Android emoji: color emoji don't render on the iOS 26 simulator, and symbols follow
    /// the theme.
    static func symbol(_ id: Int) -> String {
        switch id {
        case NovagramVoicePreset.off: return "xmark.circle"
        case NovagramVoicePreset.speedRow: return "forward"
        case NovagramVoicePreset.robot: return "cpu"
        case NovagramVoicePreset.alien: return "sparkles"
        case NovagramVoicePreset.hoarseness: return "wind"
        case NovagramVoicePreset.modulation: return "slider.horizontal.3"
        case NovagramVoicePreset.child: return "figure.wave"
        case NovagramVoicePreset.mouse: return "hare"
        case NovagramVoicePreset.man: return "person.fill"
        case NovagramVoicePreset.woman: return "person"
        case NovagramVoicePreset.monster: return "flame"
        case NovagramVoicePreset.echo: return "dot.radiowaves.left.and.right"
        case NovagramVoicePreset.noise: return "waveform.path"
        case NovagramVoicePreset.helium: return "arrow.up.circle"
        case NovagramVoicePreset.hexafluoride: return "arrow.down.circle"
        case NovagramVoicePreset.cave: return "building.columns"
        default: return "waveform"
        }
    }
}
