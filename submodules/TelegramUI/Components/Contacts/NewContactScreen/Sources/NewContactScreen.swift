import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AppBundle
import ViewControllerComponent
import MultilineTextComponent
import BundleIconComponent
import ListSectionComponent
import ListTextFieldItemComponent
import ListActionItemComponent
import TextFormat
import TextFieldComponent
import ListComposePollOptionComponent
import ListItemComponentAdaptor
import PresentationDataUtils
import EdgeEffect
import GlassBarButtonComponent
import Markdown
import CountrySelectionUI
import PhoneNumberFormat
import QrCodeUI
import MessageUI

final class NewContactScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    struct Result {
        let peer: EnginePeer?
        let firstName: String
        let lastName: String
        let phoneNumber: String
        let syncContactToPhone: Bool
        let note: NSAttributedString
    }
    
    let context: AccountContext
    let initialData: NewContactScreen.InitialData
    let completion: (TelegramMediaTodo) -> Void

    init(
        context: AccountContext,
        initialData: NewContactScreen.InitialData,
        completion: @escaping (TelegramMediaTodo) -> Void
    ) {
        self.context = context
        self.initialData = initialData
        self.completion = completion
    }

    static func ==(lhs: NewContactScreenComponent, rhs: NewContactScreenComponent) -> Bool {
        return true
    }
    
    enum ResolvedPeer: Equatable {
        case resolving
        case peer(peer: EnginePeer, isContact: Bool)
        case notFound
    }
    
    final class View: UIView, UIScrollViewDelegate, MFMessageComposeViewControllerDelegate {
        private let scrollView: UIScrollView
        private let edgeEffectView: EdgeEffectView
        
        private let nameSection = ComponentView<Empty>()
        private let phoneSection = ComponentView<Empty>()
        private let syncContactSection = ComponentView<Empty>()
        private let noteSection = ComponentView<Empty>()
        private let qrSection = ComponentView<Empty>()
        
        private let title = ComponentView<Empty>()
        private let cancelButton = ComponentView<Empty>()
        private let doneButton = ComponentView<Empty>()
                
        private var isUpdating: Bool = false
        private var ignoreScrolling: Bool = false
        private var previousHadInputHeight: Bool = false
        
        private var component: NewContactScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private var resolvedPeer: NewContactScreenComponent.ResolvedPeer?
        private var resolvedPeerDisposable = MetaDisposable()
        
        private let firstNameTag = NSObject()
        private let lastNameTag = NSObject()
        private let phoneTag = NSObject()
        private let noteTag = NSObject()
        
        private var syncContactToPhone = true
        
        private var cachedChevronImage: (UIImage, PresentationTheme)?
        
        private var composer: MFMessageComposeViewController?
        
        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = true
            
            self.edgeEffectView = EdgeEffectView()
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            
            self.addSubview(self.edgeEffectView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.resolvedPeerDisposable.dispose()
        }
        
        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        func validatedInput() -> NewContactScreenComponent.Result? {
            var peer: EnginePeer?
            var firstName = ""
            var lastName = ""
            var phoneNumber = ""
            var note = NSAttributedString()
            if case let .peer(resolvedPeer, _) = self.resolvedPeer {
                peer = resolvedPeer
            }
            if let view = self.nameSection.findTaggedView(tag: self.firstNameTag) as? ListTextFieldItemComponent.View {
                firstName = view.currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                if firstName.isEmpty {
                    return nil
                }
            }
            if let view = self.nameSection.findTaggedView(tag: self.lastNameTag) as? ListTextFieldItemComponent.View {
                lastName = view.currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let view = self.phoneSection.findTaggedView(tag: self.phoneTag) as? ListItemComponentAdaptor.View {
                if let itemNode = view.itemNode as? PhoneInputItemNode {
                    if itemNode.codeNumberAndFullNumber.0.isEmpty || itemNode.codeNumberAndFullNumber.1.isEmpty {
                        return nil
                    }
                    phoneNumber = itemNode.phoneNumber
                }
            }
            if let view = self.noteSection.findTaggedView(tag: self.noteTag) as? ListComposePollOptionComponent.View {
                note = view.currentAttributedText
            }
            return Result(
                peer: peer,
                firstName: firstName,
                lastName: lastName,
                phoneNumber: phoneNumber,
                syncContactToPhone: self.syncContactToPhone,
                note: note
            )
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {

        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            
        }
        
        func updateCountryCode(code: Int32, name: String) {
            if let view = self.phoneSection.findTaggedView(tag: self.phoneTag) as? ListItemComponentAdaptor.View {
                if let itemNode = view.itemNode as? PhoneInputItemNode {
                    itemNode.updateCountryCode(code: code, name: name)
                }
            }
        }
        
        private var currentPhoneNumber: String {
            if let view = self.phoneSection.findTaggedView(tag: tag) as? ListItemComponentAdaptor.View {
                if let itemNode = view.itemNode as? PhoneInputItemNode {
                    return itemNode.phoneNumber
                }
            }
            return ""
        }
        
        func activateInput(tag: Any) {
            if let view = self.phoneSection.findTaggedView(tag: tag) as? ListItemComponentAdaptor.View {
                if let itemNode = view.itemNode as? PhoneInputItemNode {
                    itemNode.activateInput()
                }
            }
            if let view = self.nameSection.findTaggedView(tag: tag) as? ListTextFieldItemComponent.View {
                view.activateInput()
            }
        }
        
        func deactivateInput() {
            self.endEditing(true)
        }
        
        func sendInvite() {
            guard MFMessageComposeViewController.canSendText(), let environment = self.environment else {
                return
            }
            let composer = MFMessageComposeViewController()
            composer.messageComposeDelegate = self
            composer.recipients = [self.currentPhoneNumber]
            let url = environment.strings.InviteText_URL
            let body = environment.strings.InviteText_SingleContact(url).string
            composer.body = body
            self.composer = composer
            if let window = self.window {
                window.rootViewController?.present(composer, animated: true)
            }
        }
        
        @objc public func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            self.composer = nil
            
            controller.dismiss(animated: true, completion: nil)
        }
                
        func update(component: NewContactScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
                        
            var alphaTransition = transition
            if !transition.animation.isImmediate {
                alphaTransition = alphaTransition.withAnimation(.curve(duration: 0.25, curve: .easeInOut))
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            let theme = environment.theme
            
            var initialCountryCode: Int32?
            var initialFocusTag: Any?
            if self.component == nil {
                let countryCode: Int32
                if let phone = component.initialData.phoneNumber {
                    if let (_, code) = lookupCountryIdByNumber(phone, configuration: component.context.currentCountriesConfiguration.with { $0 }), let codeValue = Int32(code.code) {
                        countryCode = codeValue
                    } else {
                        countryCode = AuthorizationSequenceCountrySelectionController.defaultCountryCode()
                    }
                    initialFocusTag = self.firstNameTag
                } else {
                    countryCode = AuthorizationSequenceCountrySelectionController.defaultCountryCode()
                    initialFocusTag = self.phoneTag
                }
                initialCountryCode = countryCode
            }
            
            self.component = component
            self.state = state
            
            let topInset: CGFloat = 24.0
            let bottomInset: CGFloat = 8.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let sectionSpacing: CGFloat = 24.0
            
            let footerAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.freeTextColor),
                bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.freeTextColor),
                link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemAccentColor),
                linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }
            )
            
            if themeUpdated {
                self.backgroundColor = theme.list.blocksBackgroundColor
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            var contentHeight: CGFloat = 0.0
            contentHeight += environment.navigationHeight
            contentHeight += topInset
                    
            let nameSectionItems: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(id: "firstName", component: AnyComponent(ListTextFieldItemComponent(
                    style: .glass,
                    theme: theme,
                    initialText: component.initialData.firstName ?? "",
                    resetText: nil,
                    placeholder: "First Name",
                    autocapitalizationType: .sentences,
                    autocorrectionType: .default,
                    updated: { value in
                        
                    },
                    tag: self.firstNameTag
                ))),
                AnyComponentWithIdentity(id: "lastName", component: AnyComponent(ListTextFieldItemComponent(
                    style: .glass,
                    theme: theme,
                    initialText: component.initialData.lastName ?? "",
                    resetText: nil,
                    placeholder: "Last Name",
                    autocapitalizationType: .sentences,
                    autocorrectionType: .default,
                    updated: { value in
                        
                    },
                    tag: self.lastNameTag
                )))
            ]
            let nameSectionSize = self.nameSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: nameSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let nameSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: nameSectionSize)
            if let nameSectionView = self.nameSection.view as? ListSectionComponent.View {
                if nameSectionView.superview == nil {
                    self.scrollView.addSubview(nameSectionView)
                    self.nameSection.parentState = state
                }
                transition.setFrame(view: nameSectionView, frame: nameSectionFrame)
            }
            contentHeight += nameSectionSize.height
            contentHeight += sectionSpacing
            
            var phoneAccesory: PhoneInputItem.Accessory?
            switch self.resolvedPeer {
            case .resolving:
                phoneAccesory = .activity
            case .peer:
                phoneAccesory = .check
            default:
                phoneAccesory = nil
            }
            
            let phoneSectionItems: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(id: "phone", component: AnyComponent(
                    ListItemComponentAdaptor(
                        itemGenerator: PhoneInputItem(
                            theme: theme,
                            strings: environment.strings,
                            value: (initialCountryCode, nil, ""),
                            accessory: phoneAccesory,
                            selectCountryCode: { [weak self] in
                                guard let self, let environment = self.environment, let controller = environment.controller() else {
                                    return
                                }
                                let countryController = AuthorizationSequenceCountrySelectionController(strings: environment.strings, theme: environment.theme, glass: true)
                                countryController.completeWithCountryCode = { [weak self] code, name in
                                    guard let self else {
                                        return
                                    }
                                    self.updateCountryCode(code: Int32(code), name: name)
                                    self.activateInput(tag: self.phoneTag)
                                }
                                self.deactivateInput()
                                controller.push(countryController)
                            },
                            updated: { [weak self] number, mask in
                                guard let self, let component = self.component else {
                                    return
                                }
                                self.resolvedPeerDisposable.set(nil)
                                self.resolvedPeer = nil
                                if !self.isUpdating {
                                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                                }
                                
                                let cleanNumber = number.replacingOccurrences(of: "+", with: "")
                                var scheduleResolve = false
                                var resolveDelay: Double = 2.5
                                if !mask.isEmpty && abs(cleanNumber.count - mask.count) < 3 {
                                    scheduleResolve = true
                                    if abs(cleanNumber.count - mask.count) == 0 {
                                        resolveDelay = 0.1
                                    }
                                } else if mask.isEmpty && cleanNumber.count > 4 {
                                    scheduleResolve = true
                                }
                                
                                if scheduleResolve {
                                    self.resolvedPeerDisposable.set(
                                        ((Signal.complete() |> delay(resolveDelay, queue: Queue.mainQueue()))
                                        |> then(
                                            component.context.engine.peers.resolvePeerByPhone(phone: number)
                                            |> beforeStarted({ [weak self] in
                                                guard let self else {
                                                    return
                                                }
                                                self.resolvedPeer = .resolving
                                                if !self.isUpdating {
                                                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                                                }
                                            })
                                        )
                                        |> deliverOnMainQueue).start(next: { [weak self] peer in
                                            guard let self, let component = self.component else {
                                                return
                                            }
                                            if let peer {
                                                self.resolvedPeerDisposable.set((component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.IsContact(id: peer.id)) |> deliverOnMainQueue).start(next: { [weak self] isContact in
                                                    guard let self else {
                                                        return
                                                    }
                                                    self.resolvedPeer = .peer(peer: peer, isContact: isContact)
                                                    if !self.isUpdating {
                                                        self.state?.updated(transition: .easeInOut(duration: 0.2))
                                                    }
                                                }))
                                            } else {
                                                self.resolvedPeer = .notFound
                                                if !self.isUpdating {
                                                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                                                }
                                            }
                                        })
                                    )
                                }
                            }
                        ),
                        params: ListViewItemLayoutParams(width: availableSize.width - sideInset * 2.0, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true),
                        tag: self.phoneTag
                    )
                ))
            ]
            
            var phoneFooterComponent: AnyComponent<Empty>?
            if let resolvedPeer = self.resolvedPeer {
                if self.cachedChevronImage == nil || self.cachedChevronImage?.1 !== environment.theme {
                    self.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: environment.theme.list.itemAccentColor)!, environment.theme)
                }
                
                let phoneFooterRawText: String
                switch resolvedPeer {
                case .resolving:
                    phoneFooterRawText = ""
                case let .peer(_, isContact):
                    if isContact {
                        phoneFooterRawText = "This phone number is already in your contacts. [View >]()"
                    } else {
                        phoneFooterRawText = "This phone number is on Telegram."
                    }
                case .notFound:
                    phoneFooterRawText = "This phone number is not on Telegram. [Invite >]()"
                }
                let phoneFooterText = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(phoneFooterRawText, attributes: footerAttributes))
                if let range = phoneFooterText.string.range(of: ">"), let chevronImage = self.cachedChevronImage?.0 {
                    phoneFooterText.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: phoneFooterText.string))
                }
                phoneFooterComponent = AnyComponent(MultilineTextComponent(
                    text: .plain(phoneFooterText),
                    maximumNumberOfLines: 0,
                    highlightColor: environment.theme.list.itemAccentColor.withAlphaComponent(0.1),
                    highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { [weak self] _, _ in
                        guard let self else {
                            return
                        }
                        if case let .peer(peer, _) = self.resolvedPeer {
                            let _ = peer
                        } else {
                            self.sendInvite()
                        }
                    }
                ))
            }
            
            let phoneSectionSize = self.phoneSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: phoneFooterComponent,
                    items: phoneSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let phoneSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: phoneSectionSize)
            if let phoneSectionView = self.phoneSection.view as? ListSectionComponent.View {
                if phoneSectionView.superview == nil {
                    self.scrollView.addSubview(phoneSectionView)
                    self.phoneSection.parentState = state
                }
                transition.setFrame(view: phoneSectionView, frame: phoneSectionFrame)
            }
            contentHeight += phoneSectionSize.height
            contentHeight += sectionSpacing
            
            if let initialCountryCode {
                self.updateCountryCode(code: initialCountryCode, name: "")
            }
            
            let syncContactSectionItems: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(id: "syncContact", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "Sync Contact to Phone",
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.syncContactToPhone, action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.syncContactToPhone = !self.syncContactToPhone
                        self.state?.updated(transition: .spring(duration: 0.4))
                    })),
                    action: nil
                )))
            ]
            let syncContactSectionSize = self.syncContactSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: syncContactSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let syncContactSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: syncContactSectionSize)
            if let syncContactSectionView = self.syncContactSection.view {
                if syncContactSectionView.superview == nil {
                    self.scrollView.addSubview(syncContactSectionView)
                    self.syncContactSection.parentState = state
                }
                transition.setFrame(view: syncContactSectionView, frame: syncContactSectionFrame)
            }
            contentHeight += syncContactSectionSize.height
            contentHeight += sectionSpacing
            
            if case .peer = self.resolvedPeer {
                if let qrSectionView = self.qrSection.view, qrSectionView.superview != nil {
                    transition.setAlpha(view: qrSectionView, alpha: 0.0, completion: { _ in
                        qrSectionView.removeFromSuperview()
                    })
                }
                
                var characterLimit: Int = 128
                if let data = component.context.currentAppConfiguration.with({ $0 }).data, let value = data["contact_note_length_limit"] as? Double {
                    characterLimit = Int(value)
                }
                let noteSectionItems: [AnyComponentWithIdentity<Empty>] = [
                    AnyComponentWithIdentity(
                        id: "note",
                        component: AnyComponent(
                            ListComposePollOptionComponent(
                                externalState: nil,
                                context: component.context,
                                style: .glass,
                                theme: theme,
                                strings: environment.strings,
                                placeholder: NSAttributedString(string: "Add notes only visible to you", font: Font.regular(17.0), textColor: theme.list.itemPlaceholderTextColor),
                                characterLimit: characterLimit,
                                emptyLineHandling: .allowed,
                                returnKeyAction: nil,
                                backspaceKeyAction: nil,
                                selection: nil,
                                inputMode: nil,
                                toggleInputMode: nil,
                                tag: self.noteTag
                            )
                        )
                    )
                ]
                var noteSectionTransition = transition
                if self.noteSection.view == nil {
                    noteSectionTransition = .immediate
                }
                let noteSectionSize = self.noteSection.update(
                    transition: noteSectionTransition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: nil,
                        footer: nil,
                        items: noteSectionItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let noteSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: noteSectionSize)
                if let noteSectionView = self.noteSection.view {
                    if noteSectionView.superview == nil {
                        self.scrollView.addSubview(noteSectionView)
                        self.syncContactSection.parentState = state
                        
                        noteSectionTransition = .immediate
                        transition.setAlpha(view: noteSectionView, alpha: 1.0)
                    }
                    noteSectionTransition.setFrame(view: noteSectionView, frame: noteSectionFrame)
                }
                contentHeight += noteSectionSize.height
                contentHeight += sectionSpacing
            } else {
                if let noteSectionView = self.noteSection.view, noteSectionView.superview != nil {
                    transition.setAlpha(view: noteSectionView, alpha: 0.0, completion: { _ in
                        noteSectionView.removeFromSuperview()
                    })
                }
                
                let qrSectionItems: [AnyComponentWithIdentity<Empty>] = [
                    AnyComponentWithIdentity(id: "syncContact", component: AnyComponent(ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: "Add via QR Code",
                                    font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                    textColor: theme.list.itemAccentColor
                                )),
                                maximumNumberOfLines: 1
                            ))),
                        ], alignment: .left, spacing: 2.0)),
                        leftIcon: .custom(
                            AnyComponentWithIdentity(
                                id: "icon",
                                component: AnyComponent(BundleIconComponent(name: "Settings/QrIcon", tintColor: theme.list.itemAccentColor))
                            ),
                            false
                        ),
                        accessory: .none,
                        action: { [weak self] _ in
                            guard let self, let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                                return
                            }
                            let scanController = QrCodeScanScreen(context: component.context, subject: .peer)
                            controller.push(scanController)
                        }
                    )))
                ]
                let qrSectionSize = self.qrSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: nil,
                        footer: nil,
                        items: qrSectionItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let qrSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: qrSectionSize)
                if let qrSectionView = self.qrSection.view {
                    var qrSectionTransition = transition
                    if qrSectionView.superview == nil {
                        self.scrollView.addSubview(qrSectionView)
                        self.syncContactSection.parentState = state
                        
                        qrSectionTransition = .immediate
                        transition.setAlpha(view: qrSectionView, alpha: 1.0)
                    }
                    qrSectionTransition.setFrame(view: qrSectionView, frame: qrSectionFrame)
                }
                contentHeight += qrSectionSize.height
                contentHeight += sectionSpacing
            }
            
            
            let inputHeight = environment.inputHeight
            
            let combinedBottomInset: CGFloat
            combinedBottomInset = bottomInset + max(environment.safeInsets.bottom, 8.0 + inputHeight)
            contentHeight += combinedBottomInset
            
            self.ignoreScrolling = true
            let previousBounds = self.scrollView.bounds
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.frame != CGRect(origin: CGPoint(), size: availableSize) {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: environment.safeInsets.bottom, right: 0.0)
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }
            
            if !previousBounds.isEmpty, !transition.animation.isImmediate {
                let bounds = self.scrollView.bounds
                if bounds.maxY != previousBounds.maxY {
                    let offsetY = previousBounds.maxY - bounds.maxY
                    transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                }
            }
            self.ignoreScrolling = false
                        

            let isValid = self.validatedInput() != nil
            
            let edgeEffectHeight: CGFloat = 66.0
            let edgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: edgeEffectHeight))
            transition.setFrame(view: self.edgeEffectView, frame: edgeEffectFrame)
            self.edgeEffectView.update(content: environment.theme.list.blocksBackgroundColor, alpha: 1.0, rect: edgeEffectFrame, edge: .top, edgeSize: edgeEffectFrame.height, transition: transition)
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(
                            NSAttributedString(
                                string: "New Contact",
                                font: Font.semibold(17.0),
                                textColor: environment.theme.rootController.navigationBar.primaryTextColor
                            )
                        )
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 40.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: floorToScreenPixels((environment.navigationHeight - titleSize.height) / 2.0) + 3.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            let barButtonSize = CGSize(width: 40.0, height: 40.0)
            let cancelButtonSize = self.cancelButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: barButtonSize,
                    backgroundColor: environment.theme.rootController.navigationBar.opaqueBackgroundColor,
                    isDark: environment.theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: environment.theme.rootController.navigationBar.glassBarButtonForegroundColor
                        )
                    )),
                    action: { [weak self] _ in
                        guard let self, let controller = self.environment?.controller() as? NewContactScreen else {
                            return
                        }
                        controller.dismiss()
                    }
                )),
                environment: {},
                containerSize: barButtonSize
            )
            let cancelButtonFrame = CGRect(origin: CGPoint(x: environment.safeInsets.left + 16.0, y: 16.0), size: cancelButtonSize)
            if let cancelButtonView = self.cancelButton.view {
                if cancelButtonView.superview == nil {
                    self.addSubview(cancelButtonView)
                }
                transition.setFrame(view: cancelButtonView, frame: cancelButtonFrame)
            }
            
            let doneButtonSize = self.doneButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: barButtonSize,
                    backgroundColor: isValid ? environment.theme.list.itemCheckColors.fillColor : environment.theme.list.itemCheckColors.fillColor.desaturated().withMultipliedAlpha(0.5),
                    isDark: environment.theme.overallDarkAppearance,
                    state: .tintedGlass,
                    isEnabled: isValid,
                    component: AnyComponentWithIdentity(id: "done", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Done",
                            tintColor: environment.theme.list.itemCheckColors.foregroundColor
                        )
                    )),
                    action: { [weak self] _ in
                        guard let self, let controller = self.environment?.controller() as? NewContactScreen else {
                            return
                        }
                        if let input = self.validatedInput() {
                            controller.complete(result: input)
                        }
                        controller.dismiss()
                    }
                )),
                environment: {},
                containerSize: barButtonSize
            )
            let doneButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - environment.safeInsets.right - 16.0 - doneButtonSize.width, y: 16.0), size: doneButtonSize)
            if let doneButtonView = self.doneButton.view {
                if doneButtonView.superview == nil {
                    self.addSubview(doneButtonView)
                }
                transition.setFrame(view: doneButtonView, frame: doneButtonFrame)
            }
            
            if let initialFocusTag {
                self.activateInput(tag: initialFocusTag)
            }
                    
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class NewContactScreen: ViewControllerComponentContainer {
    public final class InitialData {
        fileprivate let firstName: String?
        fileprivate let lastName: String?
        fileprivate let phoneNumber: String?
        
        fileprivate init(
            firstName: String?,
            lastName: String?,
            phoneNumber: String?
        ) {
            self.firstName = firstName
            self.lastName = lastName
            self.phoneNumber = phoneNumber
        }
    }
    
    private let context: AccountContext
    fileprivate let completion: (TelegramMediaTodo) -> Void
    private var isDismissed: Bool = false
            
    public init(
        context: AccountContext,
        initialData: InitialData,
        completion: @escaping (TelegramMediaTodo) -> Void
    ) {
        self.context = context
        self.completion = completion
        
        let countriesConfiguration = context.currentCountriesConfiguration.with { $0 }
        AuthorizationSequenceCountrySelectionController.setupCountryCodes(countries: countriesConfiguration.countries, codesByPrefix: countriesConfiguration.countriesByPrefix)
        
        super.init(context: context, component: NewContactScreenComponent(
            context: context,
            initialData: initialData,
            completion: completion
        ), navigationBarAppearance: .none, theme: .default)
        
        self._hasGlassStyle = true
        self.navigationPresentation = .modal
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? NewContactScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    public static func initialData(
        firstName: String? = nil,
        lastName: String? = nil,
        phoneNumber: String? = nil
    ) -> InitialData {
        return InitialData(
            firstName: firstName,
            lastName: lastName,
            phoneNumber: phoneNumber
        )
    }
    
    fileprivate func complete(result: NewContactScreenComponent.Result) {
        let entities = generateChatInputTextEntities(result.note)
        if let peer = result.peer {
            let _ = self.context.engine.contacts.addContactInteractively(
                peerId: peer.id,
                firstName: result.firstName,
                lastName: result.lastName,
                phoneNumber: result.phoneNumber,
                noteText: result.note.string,
                noteEntities: entities,
                addToPrivacyExceptions: false
            ).startStandalone()
        } else {
            let _ = self.context.engine.contacts.importContact(
                firstName: result.firstName,
                lastName: result.lastName,
                phoneNumber: result.phoneNumber,
                noteText: result.note.string,
                noteEntities: entities
            ).startStandalone()
        }
    }
}
