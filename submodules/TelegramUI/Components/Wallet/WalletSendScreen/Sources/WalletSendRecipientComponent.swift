import Foundation
import UIKit
import Display
import SwiftSignalKit
import AppBundle
import AccountContext
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ComponentFlow
import AvatarComponent
import BundleIconComponent
import MultilineTextComponent
import PlainButtonComponent

final class WalletSendRecipientComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let nameDisplayOrder: PresentationPersonNameOrder
    let peer: EnginePeer?
    let address: String
    let isLoading: Bool
    let openChat: (() -> Void)?
    let copyAddress: () -> Void
    let openInfo: () -> Void

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        nameDisplayOrder: PresentationPersonNameOrder,
        peer: EnginePeer?,
        address: String,
        isLoading: Bool,
        openChat: (() -> Void)?,
        copyAddress: @escaping () -> Void,
        openInfo: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
        self.peer = peer
        self.address = address
        self.isLoading = isLoading
        self.openChat = openChat
        self.copyAddress = copyAddress
        self.openInfo = openInfo
    }

    static func ==(lhs: WalletSendRecipientComponent, rhs: WalletSendRecipientComponent) -> Bool {
        return lhs.context === rhs.context
            && lhs.theme === rhs.theme
            && lhs.nameDisplayOrder == rhs.nameDisplayOrder
            && lhs.peer == rhs.peer
            && lhs.address == rhs.address
            && lhs.isLoading == rhs.isLoading
            && (lhs.openChat == nil) == (rhs.openChat == nil)
    }

    final class View: UIView {
        private enum AddressPhase {
            case loading
            case revealing
            case ready
        }

        private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        private static let flipDuration = 0.14
        private static let sweepDuration = 0.4
        private static let settleDuration = 0.546

        private let backgroundView = UIView()
        private let avatar = ComponentView<Empty>()
        private let tonIconView = UIImageView()
        private let name = ComponentView<Empty>()
        private let username = ComponentView<Empty>()
        private let address = ComponentView<Empty>()
        private let infoButton = ComponentView<Empty>()
        private var component: WalletSendRecipientComponent?
        private var addressPhase: AddressPhase = .ready
        private var animationElapsed: CFTimeInterval = 0
        private var revealElapsed: CFTimeInterval = 0
        private var lastAnimationTimestamp: CFTimeInterval?
        private var animationTimer: Foundation.Timer?
        private var isAnimationVisible = false
        private var applicationIsActive = false
        private let applicationIsActiveDisposable = MetaDisposable()
        private var formattedAddressLines: [String] = []
        private var addressAttributes: [NSAttributedString.Key: Any] = [:]
        private var addressTextWidth: CGFloat = 0
        private var addressSize: CGSize = .zero
        private var renderedAddress: NSAttributedString?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.backgroundView.isUserInteractionEnabled = false
            self.addSubview(self.backgroundView)

            self.tonIconView.image = UIImage(bundleImageName: "Wallet/Ton")
            self.tonIconView.contentMode = .scaleAspectFill
            self.tonIconView.clipsToBounds = true
            self.tonIconView.isUserInteractionEnabled = false
            self.tonIconView.accessibilityElementsHidden = true
            self.addSubview(self.tonIconView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.animationTimer?.invalidate()
            self.applicationIsActiveDisposable.dispose()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            self.updateAnimationActivity()
        }

        func setAnimationVisible(_ isVisible: Bool) {
            guard self.isAnimationVisible != isVisible else { return }
            self.isAnimationVisible = isVisible
            self.updateAnimationActivity()
        }

        private func advanceAnimation(to timestamp: CFTimeInterval) {
            guard let previousTimestamp = self.lastAnimationTimestamp else { return }
            let delta = max(0.0, timestamp - previousTimestamp)
            self.lastAnimationTimestamp = timestamp
            self.animationElapsed += delta
            if self.addressPhase == .revealing {
                self.revealElapsed += delta
                if self.revealElapsed >= Self.settleDuration {
                    self.addressPhase = .ready
                }
            }
        }

        private func updateAnimationActivity() {
            let timestamp = CACurrentMediaTime()
            self.advanceAnimation(to: timestamp)
            let reduceMotion = UIAccessibility.isReduceMotionEnabled
            if reduceMotion && self.addressPhase == .revealing {
                self.addressPhase = .ready
            }
            self.updateAddressText()

            let shouldAnimate = self.component != nil && self.addressPhase != .ready
                && self.isAnimationVisible && self.window != nil && self.applicationIsActive && !reduceMotion
            if shouldAnimate {
                if self.animationTimer == nil {
                    self.lastAnimationTimestamp = timestamp
                    let timer = Foundation.Timer(timeInterval: 0.035, repeats: true, block: { [weak self] _ in
                        self?.updateAnimationActivity()
                    })
                    self.animationTimer = timer
                    RunLoop.main.add(timer, forMode: .common)
                }
            } else {
                self.animationTimer?.invalidate()
                self.animationTimer = nil
                self.lastAnimationTimestamp = nil
            }
        }

        private func updateAddressText(force: Bool = false) {
            guard let component = self.component else { return }
            let total = self.formattedAddressLines.reduce(0) { $0 + $1.count }
            let tick = Int(self.animationElapsed / Self.flipDuration)
            let attributedAddress = NSMutableAttributedString()
            var place = 0
            for (row, line) in self.formattedAddressLines.enumerated() {
                if row != 0 {
                    attributedAddress.append(NSAttributedString(string: "\n", attributes: self.addressAttributes))
                }
                for (column, group) in line.split(separator: " ").enumerated() {
                    if column != 0 {
                        attributedAddress.append(NSAttributedString(string: " ", attributes: self.addressAttributes))
                        place += 1
                    }
                    let color = (row + column).isMultiple(of: 2)
                        ? component.theme.list.itemPrimaryTextColor
                        : component.theme.list.itemSecondaryTextColor
                    for character in group {
                        let settled = self.addressPhase == .ready || (self.addressPhase == .revealing
                            && self.revealElapsed >= Self.sweepDuration * Double(place) / Double(max(total - 1, 1)))
                        var attributes = self.addressAttributes
                        attributes[.foregroundColor] = settled ? color : color.withMultipliedAlpha(0.35)
                        let displayedCharacter: Character
                        if settled {
                            displayedCharacter = character
                        } else {
                            let hash = (place &* 2_654_435_761) ^ (tick &* 40_503)
                            displayedCharacter = Self.alphabet[(hash & 0x7fff_ffff) % Self.alphabet.count]
                        }
                        attributedAddress.append(NSAttributedString(string: String(displayedCharacter), attributes: attributes))
                        place += 1
                    }
                }
            }
            guard force || self.renderedAddress?.isEqual(to: attributedAddress) != true else { return }
            self.renderedAddress = attributedAddress

            self.addressSize = self.address.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(MultilineTextComponent(
                        text: .plain(attributedAddress),
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )),
                    action: { [weak self] in self?.component?.copyAddress() },
                    isEnabled: !component.isLoading && !component.address.isEmpty,
                    animateScale: false
                )),
                environment: {},
                containerSize: CGSize(width: self.addressTextWidth, height: .greatestFiniteMagnitude)
            )
            if let addressView = self.address.view as? PlainButtonComponent.View {
                addressView.isAccessibilityElement = !component.isLoading && !component.address.isEmpty
                addressView.accessibilityLabel = component.address
                addressView.contentView?.accessibilityElementsHidden = true
            }
        }

        private static func addressLines(_ address: String, groupsPerLine: Int) -> [String] {
            var lines: [String] = []
            var groups: [String] = []
            var index = address.startIndex
            while index < address.endIndex {
                let endIndex = address.index(index, offsetBy: 4, limitedBy: address.endIndex) ?? address.endIndex
                groups.append(String(address[index ..< endIndex]))
                index = endIndex
                if groups.count == groupsPerLine {
                    lines.append(groups.joined(separator: " "))
                    groups.removeAll(keepingCapacity: true)
                }
            }
            if !groups.isEmpty {
                lines.append(groups.joined(separator: " "))
            }
            return lines
        }

        func update(component: WalletSendRecipientComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.advanceAnimation(to: CACurrentMediaTime())
            let contextChanged = self.component?.context !== component.context
            if contextChanged {
                self.applicationIsActive = false
            }
            let hasPeer = component.peer != nil
            let displaysPlaceholder = hasPeer && (component.isLoading || component.address.isEmpty)
            if self.component?.peer?.id != component.peer?.id || self.component?.address != component.address || self.component?.isLoading != component.isLoading {
                let continuesLoading = self.component?.peer?.id == component.peer?.id
                    && self.addressPhase == .loading
                if !continuesLoading {
                    self.animationElapsed = 0
                }
                self.revealElapsed = 0
                if displaysPlaceholder {
                    self.addressPhase = .loading
                } else if hasPeer && continuesLoading {
                    self.addressPhase = .revealing
                } else {
                    self.addressPhase = .ready
                }
            }
            self.component = component
            if UIAccessibility.isReduceMotionEnabled && self.addressPhase == .revealing {
                self.addressPhase = .ready
            }
            let canOpenInfo = !component.isLoading && !component.address.isEmpty
            let textOriginX: CGFloat = 60.0
            let textWidth = max(1.0, availableSize.width - textOriginX - 42.0)
            let addressFont = Font.monospace(14.0)
            let addressKerning = ("0" as NSString).size(withAttributes: [.font: addressFont]).width * 0.08
            let addressAttributes: [NSAttributedString.Key: Any] = [
                .font: addressFont,
                .foregroundColor: component.theme.list.itemSecondaryTextColor,
                .kern: addressKerning
            ]
            var groupsPerLine = 6
            while groupsPerLine > 1 {
                let sample = Array(repeating: "0000", count: groupsPerLine).joined(separator: " ")
                if ceil((sample as NSString).size(withAttributes: addressAttributes).width) <= textWidth {
                    break
                }
                groupsPerLine -= 1
            }

            let addressText = displaysPlaceholder ? String(repeating: "0", count: 48) : (component.address.isEmpty ? "—" : component.address)
            self.formattedAddressLines = Self.addressLines(addressText, groupsPerLine: groupsPerLine)
            self.addressAttributes = addressAttributes
            self.addressTextWidth = textWidth
            self.updateAddressText(force: true)
            let addressSize = self.addressSize

            let avatarSize = CGSize(width: 36.0, height: 36.0)
            var nameSize: CGSize = .zero
            var usernameSize: CGSize = .zero
            var usernameText: String?
            if let peer = component.peer {
                let _ = self.avatar.update(
                    transition: transition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(AvatarComponent(context: component.context, theme: component.theme, peer: peer, size: avatarSize)),
                        action: { component.openChat?() },
                        isEnabled: component.openChat != nil,
                        animateAlpha: false,
                        animateScale: false
                    )),
                    environment: {},
                    containerSize: avatarSize
                )
                if let addressName = peer.addressName, !addressName.isEmpty {
                    usernameText = "@\(addressName)"
                    usernameSize = self.username.update(
                        transition: transition,
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "@\(addressName)",
                                font: Font.regular(14.0),
                                textColor: component.theme.list.itemSecondaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        )),
                        environment: {},
                        containerSize: CGSize(width: floor(textWidth * 0.45), height: 30.0)
                    )
                }
            }
            nameSize = self.name.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.peer?.displayTitle(strings: component.strings, displayOrder: component.nameDisplayOrder) ?? component.strings.Wallet_Recipient_GramWallet,
                        font: Font.semibold(16.0),
                        textColor: component.theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: max(1.0, textWidth - usernameSize.width - (usernameText == nil ? 0.0 : 6.0)), height: 30.0)
            )
            let infoButtonSize = self.infoButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(BundleIconComponent(
                        name: "Wallet/AddressInfo",
                        tintColor: component.theme.list.itemAccentColor,
                        maxSize: CGSize(width: 24.0, height: 24.0)
                    )),
                    minSize: CGSize(width: 44.0, height: 44.0),
                    action: component.openInfo,
                    isEnabled: canOpenInfo
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )

            let titleHeight = max(19.0, max(nameSize.height, usernameSize.height))
            let titleSpacing: CGFloat = 2.0
            let textHeight = titleHeight + titleSpacing + addressSize.height
            let size = CGSize(width: availableSize.width, height: max(68.0, textHeight + 12.0))
            let textOriginY = floorToScreenPixels((size.height - textHeight) / 2.0) + 1.0
            let addressFrame = CGRect(x: textOriginX, y: textOriginY + titleHeight + titleSpacing, width: addressSize.width, height: addressSize.height)

            self.backgroundView.backgroundColor = component.theme.list.itemInputField.backgroundColor
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: size))
            transition.setCornerRadius(layer: self.backgroundView.layer, cornerRadius: size.height / 2.0)

            let avatarFrame = CGRect(x: 16.0, y: floorToScreenPixels((size.height - avatarSize.height) / 2.0), width: avatarSize.width, height: avatarSize.height)
            transition.setFrame(view: self.tonIconView, frame: avatarFrame)
            self.tonIconView.layer.cornerRadius = avatarSize.width / 2.0
            transition.setAlpha(view: self.tonIconView, alpha: hasPeer ? 0.0 : 1.0)

            if let avatarView = self.avatar.view {
                if avatarView.superview == nil {
                    self.addSubview(avatarView)
                }
                avatarView.isUserInteractionEnabled = hasPeer && component.openChat != nil
                avatarView.isAccessibilityElement = hasPeer && component.openChat != nil
                avatarView.accessibilityLabel = component.peer?.displayTitle(strings: component.strings, displayOrder: component.nameDisplayOrder)
                transition.setFrame(view: avatarView, frame: avatarFrame)
                transition.setAlpha(view: avatarView, alpha: hasPeer ? 1.0 : 0.0)
            }
            if let nameView = self.name.view {
                if nameView.superview == nil {
                    nameView.isUserInteractionEnabled = false
                    self.addSubview(nameView)
                }
                transition.setFrame(view: nameView, frame: CGRect(x: textOriginX, y: textOriginY - 1.0, width: nameSize.width, height: nameSize.height))
            }
            if let usernameView = self.username.view {
                if usernameView.superview == nil {
                    usernameView.isUserInteractionEnabled = false
                    self.addSubview(usernameView)
                }
                usernameView.isAccessibilityElement = usernameText != nil
                usernameView.accessibilityLabel = usernameText
                let baselineOffset = floorToScreenPixels(Font.semibold(16.0).ascender) - floorToScreenPixels(Font.regular(14.0).ascender)
                transition.setFrame(view: usernameView, frame: CGRect(x: textOriginX + nameSize.width + 6.0, y: textOriginY + baselineOffset - 1.0, width: usernameSize.width, height: usernameSize.height))
                transition.setAlpha(view: usernameView, alpha: usernameText == nil ? 0.0 : 1.0)
            }
            if let addressView = self.address.view {
                if addressView.superview == nil {
                    self.addSubview(addressView)
                }
                addressView.isUserInteractionEnabled = canOpenInfo
                transition.setFrame(view: addressView, frame: addressFrame)
            }
            if let infoButtonView = self.infoButton.view {
                if infoButtonView.superview == nil {
                    self.addSubview(infoButtonView)
                }
                infoButtonView.isUserInteractionEnabled = canOpenInfo
                transition.setFrame(view: infoButtonView, frame: CGRect(x: size.width - 6.0 - infoButtonSize.width, y: floorToScreenPixels((size.height - infoButtonSize.height) / 2.0), width: infoButtonSize.width, height: infoButtonSize.height))
                transition.setAlpha(view: infoButtonView, alpha: 1.0)
            }

            if contextChanged {
                self.applicationIsActiveDisposable.set((component.context.sharedContext.applicationBindings.applicationIsActive
                |> distinctUntilChanged
                |> deliverOnMainQueue).start(next: { [weak self] isActive in
                    guard let self else { return }
                    self.applicationIsActive = isActive
                    self.updateAnimationActivity()
                }))
            }
            self.updateAnimationActivity()
            return size
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
