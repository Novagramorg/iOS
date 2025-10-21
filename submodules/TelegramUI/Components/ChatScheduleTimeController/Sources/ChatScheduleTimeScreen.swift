import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import ViewControllerComponent
import TelegramPresentationData
import TelegramStringFormatting
import AccountContext
import SheetComponent
import ButtonComponent
import PlainButtonComponent
import BundleIconComponent
import GlassBackgroundComponent
import GlassBarButtonComponent
import DatePickerNode
import UndoUI

private let calendar = Calendar(identifier: .gregorian)

private final class ChatScheduleTimeSheetContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let mode: ChatScheduleTimeScreen.Mode
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        mode: ChatScheduleTimeScreen.Mode,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.mode = mode
        self.dismiss = dismiss
    }
    
    static func ==(lhs: ChatScheduleTimeSheetContentComponent, rhs: ChatScheduleTimeSheetContentComponent) -> Bool {
        return true
    }
    
    final class View: UIView {
        private let cancel = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let button = ComponentView<Empty>()
        
        private var datePicker: DatePickerNode?
        
        private let topSeparator = SimpleLayer()
        
        private let timeTitle = ComponentView<Empty>()
        private let timeValue = ComponentView<Empty>()
        
        private let bottomSeparator = SimpleLayer()
        
        private let repeatTitle = ComponentView<Empty>()
        private let repeatValue = ComponentView<Empty>()
        
        private let timePicker = ComponentView<Empty>()
        private let repeatPicker = ComponentView<Empty>()
        
        private var component: ChatScheduleTimeSheetContentComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var date: Date?
        private var minDate: Date?
        private var maxDate: Date?
        
        private var isPickingTime = false
        private var isPickingRepeatPeriod = false
        
        private var repeatPeriod: Int32?
        
        private let dateFormatter: DateFormatter
        
        override init(frame: CGRect) {
            self.dateFormatter = DateFormatter()
            self.dateFormatter.timeStyle = .none
            self.dateFormatter.dateStyle = .short
            self.dateFormatter.timeZone = TimeZone.current
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.topSeparator)
            self.layer.addSublayer(self.bottomSeparator)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func updateMinimumDate(currentTime: Int32? = nil) {
            let timeZone = TimeZone(secondsFromGMT: 0)!
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let currentDate = Date()
            var components = calendar.dateComponents(Set([.era, .year, .month, .day, .hour, .minute, .second]), from: currentDate)
            components.second = 0
            let minute = (components.minute ?? 0) % 5
            
            let next1MinDate = calendar.date(byAdding: .minute, value: 1, to: calendar.date(from: components)!)
            let next5MinDate = calendar.date(byAdding: .minute, value: 5 - minute, to: calendar.date(from: components)!)
            
            if let date = calendar.date(byAdding: .day, value: 365, to: currentDate) {
                self.maxDate = date
            }
            
            if let next1MinDate = next1MinDate, let next5MinDate = next5MinDate {
                let minimalTime: Double = 0 //self.minimalTime.flatMap(Double.init) ?? 0.0
                self.minDate = max(next1MinDate, Date(timeIntervalSince1970: minimalTime))
                if let currentTime = currentTime, Double(currentTime) > max(currentDate.timeIntervalSince1970, minimalTime) {
                    self.date = Date(timeIntervalSince1970: Double(currentTime))
                } else {
                    self.date = next5MinDate
                }
            }
        }
        
        func update(component: ChatScheduleTimeSheetContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            self.environment = environment
            
            if self.component == nil {
                self.updateMinimumDate(currentTime: nil)
            }
            
            self.component = component
            self.state = state
            
            let sideInset: CGFloat = 39.0
            
            var contentHeight: CGFloat = 0.0
            contentHeight += 30.0
                        
            let barButtonSize = CGSize(width: 40.0, height: 40.0)
            let cancelSize = self.cancel.update(
                transition: transition,
                component: AnyComponent(
                    GlassBarButtonComponent(
                        size: barButtonSize,
                        backgroundColor: environment.theme.rootController.navigationBar.glassBarButtonBackgroundColor,
                        isDark: environment.theme.overallDarkAppearance,
                        state: .generic,
                        component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                            BundleIconComponent(
                                name: "Navigation/Close",
                                tintColor: environment.theme.rootController.navigationBar.glassBarButtonForegroundColor
                            )
                        )),
                        action: { [weak self] _ in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.dismiss()
                        }
                    )
                ),
                environment: {},
                containerSize: barButtonSize
            )
            let cancelFrame = CGRect(origin: CGPoint(x: 16.0, y: 16.0), size: cancelSize)
            if let cancelView = self.cancel.view {
                if cancelView.superview == nil {
                    self.addSubview(cancelView)
                }
                transition.setFrame(view: cancelView, frame: cancelFrame)
            }
            
            let title: String
            switch component.mode {
            case .scheduledMessages:
                title = environment.strings.Conversation_ScheduleMessage_Title
            case .reminders:
                title = environment.strings.Conversation_SetReminder_Title
            }
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    Text(text: title, font: Font.semibold(17.0), color: environment.theme.actionSheet.primaryTextColor)
                ),
                environment: {},
                containerSize: availableSize
            )
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: 27.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            contentHeight += 62.0
            
            let datePicker: DatePickerNode
            if let current = self.datePicker {
                datePicker = current
            } else {
                datePicker = DatePickerNode(
                    theme: DatePickerTheme(theme: environment.theme),
                    strings: environment.strings,
                    dateTimeFormat: environment.dateTimeFormat,
                    hasValueRow: false
                )
                datePicker.date = self.date
                datePicker.valueUpdated = { [weak self] date in
                    if let self {
                        self.date = date
                        self.state?.updated()
                    }
                }
                self.addSubview(datePicker.view)
                self.datePicker = datePicker
            }
            datePicker.displayDateSelection = true
            
            if let minDate = self.minDate {
                datePicker.minimumDate = minDate
            } else {
                datePicker.minimumDate = Date()
            }
            if let maxDate = self.maxDate {
                datePicker.maximumDate = maxDate
            }
            
            let constrainedWidth = min(390.0, availableSize.width)
            let cellSize = floor((constrainedWidth - 12.0 * 2.0) / 7.0)
            let pickerHeight = 59.0 + cellSize * 5.0
            
            let datePickerSize = CGSize(width: availableSize.width - 22.0, height: pickerHeight)
            datePicker.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - datePickerSize.width) / 2.0), y: contentHeight), size: datePickerSize)
            datePicker.updateLayout(size: datePickerSize, transition: .immediate)
            contentHeight += pickerHeight
            
            self.topSeparator.frame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset * 2.0, height: UIScreenPixel))
            self.topSeparator.backgroundColor = environment.theme.list.itemBlocksSeparatorColor.cgColor
            
            let timeTitleSize = self.timeTitle.update(
                transition: transition,
                component: AnyComponent(
                    Text(text: "Time", font: Font.regular(17.0), color: environment.theme.actionSheet.primaryTextColor)
                ),
                environment: {},
                containerSize: availableSize
            )
            let timeTitleFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + 16.0), size: timeTitleSize)
            if let timeTitleView = self.timeTitle.view {
                if timeTitleView.superview == nil {
                    self.addSubview(timeTitleView)
                }
                transition.setFrame(view: timeTitleView, frame: timeTitleFrame)
            }
            
    
            let date = self.date ?? Date()
            
            var t: time_t = Int(date.timeIntervalSince1970)
            var timeinfo = tm()
            localtime_r(&t, &timeinfo);
            
            let timeString = stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min), dateTimeFormat: environment.dateTimeFormat)
            let timeValueSize = self.timeValue.update(
                transition: transition,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            ButtonContentComponent(
                                theme: environment.theme,
                                text: timeString,
                                isActive: self.isPickingTime,
                                isLocked: false
                            )
                        ),
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            if self.isPickingRepeatPeriod {
                                self.isPickingRepeatPeriod = false
                            } else {
                                self.isPickingTime = !self.isPickingTime
                            }
                            self.state?.updated()
                        },
                        animateScale: false
                    )
                ),
                environment: {
                },
                containerSize: availableSize
            )
            let timeValueFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - timeValueSize.width, y: contentHeight + 10.0), size: timeValueSize)
            if let timeValueView = self.timeValue.view {
                if timeValueView.superview == nil {
                    self.addSubview(timeValueView)
                }
                transition.setFrame(view: timeValueView, frame: timeValueFrame)
            }
            
            if self.isPickingTime {
                let timePickerSize = self.timePicker.update(
                    transition: transition,
                    component: AnyComponent(
                        MenuComponent(component: AnyComponent(TimeMenuComponent(
                            value: self.date ?? Date(),
                            valueUpdated: { [weak self] value in
                                guard let self else {
                                    return
                                }
                                self.date = value
                                self.state?.updated()
                            }
                        )))
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                let timePickerFrame = CGRect(origin: CGPoint(x: timeValueFrame.maxX - timePickerSize.width + 80.0, y: timeValueFrame.minY - 20.0 - timePickerSize.height + 80.0), size: timePickerSize)
                if let timePickerView = self.timePicker.view as? MenuComponent.View {
                    if timePickerView.superview == nil {
                        self.addSubview(timePickerView)
                        
                        timePickerView.animateIn()
                    }
                    transition.setFrame(view: timePickerView, frame: timePickerFrame)
                }
            } else if let timePicker = self.timePicker.view as? MenuComponent.View, timePicker.superview != nil {
                timePicker.animateOut(completion: {
                    timePicker.removeFromSuperview()
                })
            }
            
            contentHeight += 56.0
            
            self.bottomSeparator.frame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset * 2.0, height: UIScreenPixel))
            self.bottomSeparator.backgroundColor = environment.theme.list.itemBlocksSeparatorColor.cgColor
            
            let repeatTitleSize = self.repeatTitle.update(
                transition: transition,
                component: AnyComponent(
                    Text(text: "Repeat", font: Font.regular(17.0), color: environment.theme.actionSheet.primaryTextColor)
                ),
                environment: {},
                containerSize: availableSize
            )
            let repeatTitleFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + 16.0), size: repeatTitleSize)
            if let timeTitleView = self.repeatTitle.view {
                if timeTitleView.superview == nil {
                    self.addSubview(timeTitleView)
                }
                transition.setFrame(view: timeTitleView, frame: repeatTitleFrame)
            }
            
            let repeatString: String
            if let repeatPeriod = self.repeatPeriod {
                switch repeatPeriod {
                case 60:
                    repeatString = "Every Minute"
                case 300:
                    repeatString = "Every 5 Minutes"
                case 86400:
                    repeatString = "Daily"
                case 7 * 86400:
                    repeatString = "Weekly"
                case 14 * 86400:
                    repeatString = "Biweekly"
                case 30 * 86400:
                    repeatString = "Monthly"
                case 91 * 86400:
                    repeatString = "Every 3 Months"
                case 182 * 86400:
                    repeatString = "Every 6 Months"
                case 365 * 86400:
                    repeatString = "Yearly"
                default:
                    repeatString = "\(repeatPeriod)"
                }
            } else {
                repeatString = "Never"
            }
            
            let repeatValueSize = self.repeatValue.update(
                transition: transition,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            ButtonContentComponent(
                                theme: environment.theme,
                                text: repeatString,
                                isActive: self.isPickingRepeatPeriod,
                                isLocked: !component.context.isPremium
                            )
                        ),
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            if self.isPickingTime {
                                self.isPickingTime = false
                            } else {
                                self.isPickingRepeatPeriod = !self.isPickingRepeatPeriod
                            }
                            self.state?.updated()
                        }
                    )
                ),
                environment: {
                },
                containerSize: availableSize
            )
            let repeatValueFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - repeatValueSize.width, y: contentHeight + 10.0), size: repeatValueSize)
            if let repeatValueView = self.repeatValue.view {
                if repeatValueView.superview == nil {
                    self.addSubview(repeatValueView)
                }
                transition.setFrame(view: repeatValueView, frame: repeatValueFrame)
            }
            
            if self.isPickingRepeatPeriod {
                let repeatPickerSize = self.repeatPicker.update(
                    transition: transition,
                    component: AnyComponent(
                        MenuComponent(component: AnyComponent(RepeatMenuComponent(
                            value: self.repeatPeriod,
                            valueUpdated: { [weak self] value in
                                guard let self, let component = self.component, let environment = self.environment else {
                                    return
                                }
                                self.isPickingRepeatPeriod = false
                                if component.context.isPremium {
                                    self.repeatPeriod = value
                                } else {
                                    let toastController = UndoOverlayController(
                                        presentationData: component.context.sharedContext.currentPresentationData.with { $0 },
                                        content: .premiumPaywall(
                                            title: "Premium Required",
                                            text: "Subscribe to **Telegram Premium** to schedule repeating messages.",
                                            customUndoText: nil,
                                            timeout: nil,
                                            linkAction: nil
                                        ),
                                        elevatedLayout: true,
                                        action: { [weak environment] action in
                                            if case .info = action {
                                                var replaceImpl: ((ViewController) -> Void)?
                                                let controller = component.context.sharedContext.makePremiumDemoController(context: component.context, subject: .colors, forceDark: false, action: {
                                                    let controller = component.context.sharedContext.makePremiumIntroController(context: component.context, source: .nameColor, forceDark: false, dismissed: nil)
                                                    replaceImpl?(controller)
                                                }, dismissed: nil)
                                                replaceImpl = { [weak controller] c in
                                                    controller?.replace(with: c)
                                                }
                                                environment?.controller()?.push(controller)
                                            }
                                            return true
                                        }
                                    )
                                    environment.controller()?.present(toastController, in: .current)
                                }
                                self.state?.updated()
                            }
                        )))
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                let repeatPickerFrame = CGRect(origin: CGPoint(x: repeatValueFrame.maxX - repeatPickerSize.width + 80.0, y: repeatValueFrame.minY - 20.0 - repeatPickerSize.height + 80.0), size: repeatPickerSize)
                if let repeatPickerView = self.repeatPicker.view as? MenuComponent.View {
                    if repeatPickerView.superview == nil {
                        self.addSubview(repeatPickerView)
                        
                        repeatPickerView.animateIn()
                    }
                    transition.setFrame(view: repeatPickerView, frame: repeatPickerFrame)
                }
            } else if let repeatPicker = self.repeatPicker.view as? MenuComponent.View, repeatPicker.superview != nil {
                repeatPicker.animateOut(completion: {
                    repeatPicker.removeFromSuperview()
                })
            }
            
            contentHeight += 70.0
            
            let time = stringForMessageTimestamp(timestamp: Int32(date.timeIntervalSince1970), dateTimeFormat: environment.dateTimeFormat)
            let buttonTitle: String
            switch component.mode {
            case .scheduledMessages:
                if calendar.isDateInToday(date) {
                    buttonTitle = environment.strings.Conversation_ScheduleMessage_SendToday(time).string
                } else if calendar.isDateInTomorrow(date) {
                    buttonTitle = environment.strings.Conversation_ScheduleMessage_SendTomorrow(time).string
                } else {
                    buttonTitle = environment.strings.Conversation_ScheduleMessage_SendOn(self.dateFormatter.string(from: date), time).string
                }
            case .reminders:
                if calendar.isDateInToday(date) {
                    buttonTitle = environment.strings.Conversation_SetReminder_RemindToday(time).string
                } else if calendar.isDateInTomorrow(date) {
                    buttonTitle = environment.strings.Conversation_SetReminder_RemindTomorrow(time).string
                } else {
                    buttonTitle = environment.strings.Conversation_SetReminder_RemindOn(self.dateFormatter.string(from: date), time).string
                }
            }
                
            let buttonSideInset: CGFloat = 30.0
            let buttonSize = self.button.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8),
                    ),
                    content: AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                        Text(text: buttonTitle, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor)
                    )),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component, let controller = self.environment?.controller() as? ChatScheduleTimeScreen else {
                            return
                        }
                        controller.completion(
                            ChatScheduleTimeScreen.Result(
                                time: Int32(self.date?.timeIntervalSince1970 ?? 0),
                                repeatPeriod: self.repeatPeriod
                            )
                        )
                        component.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - buttonSideInset * 2.0, height: 52.0)
            )
            let buttonFrame = CGRect(origin: CGPoint(x: buttonSideInset, y: contentHeight), size: buttonSize)
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: buttonFrame)
            }
            contentHeight += buttonSize.height
            
            let bottomPanelPadding: CGFloat = 15.0
            let bottomInset: CGFloat = environment.safeInsets.bottom > 0.0 ? environment.safeInsets.bottom + 5.0 : bottomPanelPadding
            contentHeight += bottomInset
            
            
//            if let controller = environment.controller(), !controller.automaticallyControlPresentationContextLayout {
//                let sideInset: CGFloat = 0.0
//                let bottomInset: CGFloat = max(environment.safeInsets.bottom, contentHeight)
////                if case .regular = environment.metrics.widthClass {
////                    sideInset = floor((context.availableSize.width - 430.0) / 2.0) - 12.0
////                    bottomInset = (context.availableSize.height - sheetExternalState.contentHeight) / 2.0 + sheetExternalState.contentHeight
////                }
//                
//                let layout = ContainerViewLayout(
//                    size: availableSize,
//                    metrics: environment.metrics,
//                    deviceMetrics: environment.deviceMetrics,
//                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
//                    safeInsets: UIEdgeInsets(top: 0.0, left: max(sideInset, environment.safeInsets.left), bottom: 0.0, right: max(sideInset, environment.safeInsets.right)),
//                    additionalInsets: .zero,
//                    statusBarHeight: environment.statusBarHeight,
//                    inputHeight: nil,
//                    inputHeightIsInteractivellyChanging: false,
//                    inVoiceOver: false
//                )
//                controller.presentationContext.containerLayoutUpdated(layout, transition: transition.containedViewLayoutTransition)
//            }
            
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ChatScheduleTimeScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let mode: ChatScheduleTimeScreen.Mode
    
    init(
        context: AccountContext,
        mode: ChatScheduleTimeScreen.Mode
    ) {
        self.context = context
        self.mode = mode
    }
    
    static func ==(lhs: ChatScheduleTimeScreenComponent, rhs: ChatScheduleTimeScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, SheetComponentEnvironment)>()
        private let sheetAnimateOut = ActionSlot<Action<Void>>()
        
        private var component: ChatScheduleTimeScreenComponent?
        private var environment: EnvironmentType?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ChatScheduleTimeScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            
            let sheetEnvironment = SheetComponentEnvironment(
                isDisplaying: environment.isVisible,
                isCentered: environment.metrics.widthClass == .regular,
                hasInputHeight: !environment.inputHeight.isZero,
                regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                dismiss: { [weak self] _ in
                    guard let self, let environment = self.environment else {
                        return
                    }
                    self.sheetAnimateOut.invoke(Action { _ in
                        if let controller = environment.controller() {
                            controller.dismiss(completion: nil)
                        }
                    })
                }
            )
            let _ = self.sheet.update(
                transition: transition,
                component: AnyComponent(SheetComponent(
                    content: AnyComponent(ChatScheduleTimeSheetContentComponent(
                        context: component.context,
                        mode: component.mode,
                        dismiss: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.sheetAnimateOut.invoke(Action { _ in
                                if let controller = environment.controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    animateOut: self.sheetAnimateOut
                )),
                environment: {
                    environment
                    sheetEnvironment
                },
                containerSize: availableSize
            )
            if let sheetView = self.sheet.view {
                if sheetView.superview == nil {
                    self.addSubview(sheetView)
                }
                transition.setFrame(view: sheetView, frame: CGRect(origin: CGPoint(), size: availableSize))
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class ChatScheduleTimeScreen: ViewControllerComponentContainer {
    public enum Mode: Equatable {
        case scheduledMessages(sendWhenOnlineAvailable: Bool)
        case reminders
    }
    
    public struct Result {
        public let time: Int32
        public let repeatPeriod: Int32?
    }
    
    fileprivate let completion: (Result) -> Void
    
    public init(
        context: AccountContext,
        mode: Mode,
        completion: @escaping (Result) -> Void
    ) {
        self.completion = completion
        
        super.init(context: context, component: ChatScheduleTimeScreenComponent(
            context: context,
            mode: mode
        ), navigationBarAppearance: .none)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        
        //self.automaticallyControlPresentationContextLayout = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
    }
}

private final class ButtonContentComponent: Component {
    let theme: PresentationTheme
    let text: String
    let isActive: Bool
    let isLocked: Bool
    
    init(
        theme: PresentationTheme,
        text: String,
        isActive: Bool,
        isLocked: Bool
    ) {
        self.theme = theme
        self.text = text
        self.isActive = isActive
        self.isLocked = isLocked
    }

    static func ==(lhs: ButtonContentComponent, rhs: ButtonContentComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.isActive != rhs.isActive {
            return false
        }
        if lhs.isLocked != rhs.isLocked {
            return false
        }
        return true
    }

    final class View: UIView {
        private var component: ButtonContentComponent?
        private weak var componentState: EmptyComponentState?
        
        private let backgroundLayer = SimpleLayer()
        private let title = ComponentView<Empty>()
        private let icon = ComponentView<Empty>()
                
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.layer.addSublayer(self.backgroundLayer)
            self.backgroundLayer.masksToBounds = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: ButtonContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.componentState = state
                        
            let backgroundColor: UIColor = component.isActive ? component.theme.actionSheet.controlAccentColor.withMultipliedAlpha(0.1) : component.theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.07)
            let textColor: UIColor = component.isActive ? component.theme.actionSheet.controlAccentColor : component.theme.actionSheet.primaryTextColor
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    Text(text: component.text, font: Font.regular(17.0), color: textColor)
                ),
                environment: {},
                containerSize: availableSize
            )
            
            var totalWidth = titleSize.width
            
            var iconSize = CGSize()
            if component.isLocked {
                iconSize = self.icon.update(
                    transition: .immediate,
                    component: AnyComponent(
                        BundleIconComponent(
                            name: "Media Grid/Lock",
                            tintColor: textColor
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: 44.0, height: 44.0)
                )
                totalWidth += iconSize.width + 2.0
            }
            
            let padding: CGFloat = 12.0
            let size = CGSize(width: totalWidth + padding * 2.0, height: 36.0)
                                    
            let titleFrame = CGRect(origin: CGPoint(x: padding, y: floorToScreenPixels((size.height - titleSize.height) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            let iconFrame = CGRect(origin: CGPoint(x: size.width - padding - iconSize.width, y: floorToScreenPixels((size.height - iconSize.height) / 2.0)), size: iconSize)
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                }
                transition.setFrame(view: iconView, frame: iconFrame)
            }
            
            self.backgroundLayer.backgroundColor = backgroundColor.cgColor
            transition.setFrame(layer: self.backgroundLayer, frame: CGRect(origin: .zero, size: size))
            self.backgroundLayer.cornerRadius = size.height / 2.0
                        
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}



private final class MenuComponent: Component {
    public let component: AnyComponent<Empty>

    public init(
        component: AnyComponent<Empty>
    ) {
        self.component = component
    }

    public static func ==(lhs: MenuComponent, rhs: MenuComponent) -> Bool {
        if lhs.component != rhs.component {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let backgroundView: GlassBackgroundView
        private var componentView: ComponentView<Empty>?
        
        private var component: MenuComponent?
        
        public override init(frame: CGRect) {
            self.backgroundView = GlassBackgroundView()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
        }
        
        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func animateIn() {
            let duration: Double = 0.35
            
            self.layer.removeAllAnimations()
            self.alpha = 0.0
            self.transform = CGAffineTransform(scaleX: 0.001, y: 0.001)
            self.layer.anchorPoint = CGPoint(x: 1.0, y: 1.0)
            
            UIView.animate(
                withDuration: duration,
                delay: 0.0,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 0.6,
                options: [.curveEaseOut],
                animations: {
                    self.transform = .identity
                    self.alpha = 1.0
                },
                completion: nil
            )
        }
        
        public func animateOut(duration: TimeInterval = 0.15, completion: (() -> Void)? = nil) {
            self.layer.removeAllAnimations()
            self.layer.anchorPoint = CGPoint(x: 1.0, y: 1.0)
            
            UIView.animate(
                withDuration: duration,
                delay: 0.0,
                options: [.curveEaseInOut],
                animations: {
                    self.transform = CGAffineTransform(scaleX: 0.001, y: 0.001)
                },
                completion: { _ in
                    completion?()
                }
            )
        }
                
        func update(component: MenuComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            var componentView: ComponentView<Empty>
            var componentTransition = transition
            if let current = self.componentView {
                componentView = current
            } else {
                componentTransition = .immediate
                componentView = ComponentView()
                self.componentView = componentView
            }
            
            let componentSize = componentView.update(
                transition: componentTransition,
                component: component.component,
                environment: {},
                containerSize: availableSize
            )
            let componentFrame = CGRect(origin: CGPoint(x: 80.0, y: 80.0), size: componentSize)
            if let view = componentView.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                componentTransition.setFrame(view: view, frame: componentFrame)
            }
            
            let tintColor = GlassBackgroundView.TintColor(kind: .custom, color: UIColor(rgb: 0xf6f7f8))
            
            let backgroundFrame = CGRect(origin: CGPoint(x: 80.0, y: 80.0), size: componentSize)
            self.backgroundView.update(size: backgroundFrame.size, cornerRadius: 30.0, isDark: false, tintColor: tintColor, transition: transition)
            self.backgroundView.frame = backgroundFrame
            
            return CGSize(width: componentSize.width + 80.0 * 2.0, height: componentSize.height + 80.0 * 2.0)
        }
        
        public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            return self.backgroundView.frame.contains(point)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class RepeatMenuComponent: Component {
    let value: Int32?
    let valueUpdated: (Int32?) -> Void
    
    init(
        value: Int32?,
        valueUpdated: @escaping (Int32?) -> Void
    ) {
        self.value = value
        self.valueUpdated = valueUpdated
    }

    public static func ==(lhs: RepeatMenuComponent, rhs: RepeatMenuComponent) -> Bool {
        if lhs.value != rhs.value {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let backgroundView: GlassBackgroundView
        private let never = ComponentView<Empty>()
        private let separator = SimpleLayer()
        private var itemViews: [Int32: ComponentView<Empty>] = [:]
        private let checkIcon = UIImageView()
        
        private var component: RepeatMenuComponent?
        
        private let values: [Int32] = [
            86400,
            7 * 86400,
            14 * 86400,
            30 * 86400,
            91 * 86400,
            182 * 86400,
            365 * 86400
        ]
        
        public override init(frame: CGRect) {
            self.backgroundView = GlassBackgroundView()
            self.checkIcon.image = UIImage(bundleImageName: "Media Gallery/Check")?.withRenderingMode(.alwaysTemplate)
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.layer.addSublayer(self.separator)
        }
        
        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: RepeatMenuComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let sideInset: CGFloat = 18.0
            let itemInset: CGFloat = 60.0
            
            self.checkIcon.tintColor = .black
            
            let neverSize = self.never.update(
                transition: transition,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            Text(text: "Never", font: Font.regular(17.0), color: .black)
                        ),
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.component?.valueUpdated(nil)
                        }
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let neverFrame = CGRect(origin: CGPoint(x: itemInset, y: 21.0), size: neverSize)
            if let neverView = self.never.view {
                if neverView.superview == nil {
                    self.addSubview(neverView)
                }
                transition.setFrame(view: neverView, frame: neverFrame)
                
                if component.value == nil {
                    neverView.addSubview(self.checkIcon)
                }
            }
            
            var maxWidth: CGFloat = 0.0
            var originY: CGFloat = 83.0
            for value in self.values {
                let itemView: ComponentView<Empty>
                if let current = self.itemViews[value] {
                    itemView = current
                } else {
                    itemView = ComponentView()
                    self.itemViews[value] = itemView
                }
                
                let repeatString: String
                switch value {
                case 60:
                    repeatString = "Every Minute"
                case 300:
                    repeatString = "Every 5 Minutes"
                case 86400:
                    repeatString = "Daily"
                case 7 * 86400:
                    repeatString = "Weekly"
                case 14 * 86400:
                    repeatString = "Biweekly"
                case 30 * 86400:
                    repeatString = "Monthly"
                case 91 * 86400:
                    repeatString = "Every 3 Months"
                case 182 * 86400:
                    repeatString = "Every 6 Months"
                case 365 * 86400:
                    repeatString = "Yearly"
                default:
                    repeatString = "\(value)"
                }
                
                let itemSize = itemView.update(
                    transition: transition,
                    component: AnyComponent(
                        PlainButtonComponent(
                            content: AnyComponent(
                                Text(text: repeatString, font: Font.regular(17.0), color: .black)
                            ),
                            action: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.component?.valueUpdated(value)
                            }
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                maxWidth = max(maxWidth, itemSize.width)
                let itemFrame = CGRect(origin: CGPoint(x: itemInset, y: originY), size: itemSize)
                if let itemView = itemView.view {
                    if itemView.superview == nil {
                        self.addSubview(itemView)
                    }
                    transition.setFrame(view: itemView, frame: itemFrame)
                    
                    if component.value == value {
                        itemView.addSubview(self.checkIcon)
                    }
                }
                originY += 42.0
            }
            
            if let image = self.checkIcon.image {
                self.checkIcon.frame = CGRect(origin: CGPoint(x: -35.0, y: floorToScreenPixels((12.0 - image.size.height) / 2.0) + 5.0), size: image.size)
            }
            
            let size = CGSize(width: itemInset + maxWidth + 40.0, height: originY)
            
            self.separator.backgroundColor = UIColor(rgb: 0xdddddd).cgColor
            self.separator.frame = CGRect(origin: CGPoint(x: sideInset, y: 62.0), size: CGSize(width: size.width - sideInset * 2.0, height: UIScreenPixel))
                        
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class TimeMenuComponent: Component {
    let value: Date
    let valueUpdated: (Date) -> Void

    init(
        value: Date,
        valueUpdated: @escaping (Date) -> Void
    ) {
        self.value = value
        self.valueUpdated = valueUpdated
    }

    public static func == (lhs: TimeMenuComponent, rhs: TimeMenuComponent) -> Bool {
        return lhs.value == rhs.value
    }

    public final class View: UIView {
        private let picker = UIDatePicker()
        private var component: TimeMenuComponent?

        public override init(frame: CGRect) {
            super.init(frame: frame)

            self.picker.datePickerMode = .time
            if #available(iOS 13.4, *) {
                self.picker.preferredDatePickerStyle = .wheels
            }
            self.picker.addTarget(self, action: #selector(valueChanged), for: .valueChanged)

            self.addSubview(self.picker)
        }

        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func valueChanged() {
            guard let component = self.component else {
                return
            }
            component.valueUpdated(self.picker.date)
        }

        func update(component: TimeMenuComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previous = self.component
            self.component = component

            if previous == nil || abs(component.value.timeIntervalSince(self.picker.date)) > 0.5 {
                self.picker.setDate(component.value, animated: false)
            }

            let pickerSize = self.picker.sizeThatFits(availableSize)
            let width = min(availableSize.width, max(pickerSize.width, 230.0))
            let height = pickerSize.height > 0 ? pickerSize.height : 216.0

            let frame = CGRect(origin: .zero, size: CGSize(width: width, height: height))
            transition.setFrame(view: self.picker, frame: frame)

            return frame.size
        }
    }

    public func makeView() -> View {
        return View(frame: .zero)
    }

    public func update( view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
