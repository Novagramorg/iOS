import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import BalancedTextComponent
import BundleIconComponent
import GlassBarButtonComponent
import ButtonComponent
import QrCode

private final class WalletReceiveQrComponent: Component {
    let address: String

    init(address: String) {
        self.address = address
    }

    static func ==(lhs: WalletReceiveQrComponent, rhs: WalletReceiveQrComponent) -> Bool {
        return lhs.address == rhs.address
    }

    final class View: UIView {
        private var component: WalletReceiveQrComponent?
        private let imageNode: TransformImageNode

        override init(frame: CGRect) {
            self.imageNode = TransformImageNode()

            super.init(frame: frame)

            self.backgroundColor = .white
            self.isUserInteractionEnabled = false
            self.addSubview(self.imageNode.view)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(
            component: WalletReceiveQrComponent,
            availableSize: CGSize
        ) -> CGSize {
            let previousComponent = self.component
            self.component = component

            if previousComponent?.address != component.address {
                self.imageNode.setSignal(
                    qrCode(
                        string: "ton://transfer/\(component.address)",
                        color: .black,
                        backgroundColor: .white,
                        icon: .custom(UIImage(bundleImageName: "Wallet/QrGram")),
                        ecl: "Q"
                    )
                    |> map { $0.1 },
                    attemptSynchronously: true
                )
            }

            let side = min(availableSize.width, availableSize.height)
            let size = CGSize(width: side, height: side)
            let imageInset = min(6.0, max(0.0, (side - 1.0) / 2.0))
            let imageSide = max(1.0, side - imageInset * 2.0)
            let imageSize = CGSize(width: imageSide, height: imageSide)

            let makeImageLayout = self.imageNode.asyncLayout()
            let imageApply = makeImageLayout(TransformImageArguments(
                corners: ImageCorners(),
                imageSize: imageSize,
                boundingSize: imageSize,
                intrinsicInsets: .zero,
                emptyColor: nil
            ))
            let _ = imageApply()
            self.imageNode.frame = CGRect(
                origin: CGPoint(x: imageInset, y: imageInset),
                size: imageSize
            )

            return size
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self, availableSize: availableSize)
    }
}

private final class WalletReceiveAddressRingComponent: Component {
    let address: String
    let color: UIColor

    init(address: String, color: UIColor) {
        self.address = address
        self.color = color
    }

    static func ==(lhs: WalletReceiveAddressRingComponent, rhs: WalletReceiveAddressRingComponent) -> Bool {
        if lhs.address != rhs.address {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        return true
    }

    final class View: UIView {
        private let topLabel = UILabel()
        private let rightLabel = UILabel()
        private let bottomLabel = UILabel()
        private let leftLabel = UILabel()

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
            for label in [self.topLabel, self.rightLabel, self.bottomLabel, self.leftLabel] {
                label.backgroundColor = .clear
                label.textAlignment = .center
                label.adjustsFontSizeToFitWidth = true
                label.minimumScaleFactor = 0.75
                label.lineBreakMode = .byClipping
                self.addSubview(label)
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private static func groupedAddress(_ address: String) -> [String] {
            var result: [String] = []
            var index = address.startIndex
            while index < address.endIndex {
                let endIndex = address.index(index, offsetBy: 4, limitedBy: address.endIndex) ?? address.endIndex
                result.append(String(address[index ..< endIndex]))
                index = endIndex
            }
            return result
        }

        func update(
            component: WalletReceiveAddressRingComponent,
            availableSize: CGSize,
            transition: ComponentTransition
        ) -> CGSize {
            let groups = Self.groupedAddress(component.address)
            let horizontalGroups: [String]
            let verticalGroups: [String]
            if groups.count >= 12 {
                horizontalGroups = Array(groups.suffix(4)) + ["·"] + Array(groups.prefix(4))
                verticalGroups = Array(groups.dropFirst(4).prefix(6))
            } else {
                let splitIndex = max(1, groups.count / 2)
                horizontalGroups = Array(groups.suffix(from: min(splitIndex, groups.count))) + ["·"] + Array(groups.prefix(splitIndex))
                verticalGroups = groups
            }

            let horizontalText = horizontalGroups.joined(separator: " ")
            let verticalText = verticalGroups.joined(separator: " ")
            let font = Font.with(size: max(8.0, min(11.0, availableSize.width / 31.0)) * 1.2, design: .monospace, weight: .semibold)
            //Font.monospace(max(8.0, min(11.0, availableSize.width / 31.0)) * 1.2)

            for label in [self.topLabel, self.rightLabel, self.bottomLabel, self.leftLabel] {
                label.font = font
                label.textColor = component.color
            }
            self.topLabel.text = horizontalText.uppercased()
            self.bottomLabel.text = horizontalText.uppercased()
            self.rightLabel.text = verticalText.uppercased()
            self.leftLabel.text = verticalText.uppercased()

            let horizontalSize = CGSize(width: max(1.0, availableSize.width - 64.0), height: 18.0)
            let verticalSize = CGSize(width: max(1.0, availableSize.height - 64.0), height: 18.0)

            self.topLabel.transform = .identity
            self.topLabel.bounds = CGRect(origin: .zero, size: horizontalSize)
            self.topLabel.center = CGPoint(x: availableSize.width / 2.0, y: 10.0)

            self.bottomLabel.transform = .identity
            self.bottomLabel.bounds = CGRect(origin: .zero, size: horizontalSize)
            self.bottomLabel.center = CGPoint(x: availableSize.width / 2.0, y: availableSize.height - 10.0)
            self.bottomLabel.transform = CGAffineTransform(rotationAngle: .pi)

            self.rightLabel.transform = .identity
            self.rightLabel.bounds = CGRect(origin: .zero, size: verticalSize)
            self.rightLabel.center = CGPoint(x: availableSize.width - 10.0, y: availableSize.height / 2.0)
            self.rightLabel.transform = CGAffineTransform(rotationAngle: .pi / 2.0)

            self.leftLabel.transform = .identity
            self.leftLabel.bounds = CGRect(origin: .zero, size: verticalSize)
            self.leftLabel.center = CGPoint(x: 10.0, y: availableSize.height / 2.0)
            self.leftLabel.transform = CGAffineTransform(rotationAngle: -.pi / 2.0)

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class WalletReceiveAddressGridComponent: Component {
    let address: String

    init(address: String) {
        self.address = address
    }

    static func ==(lhs: WalletReceiveAddressGridComponent, rhs: WalletReceiveAddressGridComponent) -> Bool {
        return lhs.address == rhs.address
    }

    final class View: UIView {
        private var labels: [UILabel] = []

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private static func groupedAddress(_ address: String) -> [String] {
            var result: [String] = []
            var index = address.startIndex
            while index < address.endIndex {
                let endIndex = address.index(index, offsetBy: 4, limitedBy: address.endIndex) ?? address.endIndex
                result.append(String(address[index ..< endIndex]))
                index = endIndex
            }
            return result
        }

        func update(
            component: WalletReceiveAddressGridComponent,
            availableSize: CGSize,
            transition: ComponentTransition
        ) -> CGSize {
            let groups = Self.groupedAddress(component.address)
            while self.labels.count < groups.count {
                let label = UILabel()
                label.backgroundColor = .clear
                label.font = Font.with(size: 17.0, design: .monospace, weight: .semibold)
                label.textAlignment = .center
                self.labels.append(label)
                self.addSubview(label)
            }

            let columnCount = 3
            let rowCount = Int(ceil(CGFloat(groups.count) / CGFloat(columnCount)))
            let width = min(192.0, max(1.0, availableSize.width))
            let rowHeight: CGFloat = 26.0
            let cellWidth = width / CGFloat(columnCount)

            for index in 0 ..< self.labels.count {
                let label = self.labels[index]
                guard index < groups.count else {
                    label.isHidden = true
                    continue
                }
                label.isHidden = false
                label.text = groups[index]
                label.textColor = index.isMultiple(of: 2) ? .black : UIColor(rgb: 0x8e8e93)

                let column = index % columnCount
                let row = index / columnCount
                transition.setFrame(
                    view: label,
                    frame: CGRect(
                        x: CGFloat(column) * cellWidth,
                        y: CGFloat(row) * rowHeight,
                        width: cellWidth,
                        height: rowHeight
                    )
                )
            }

            return CGSize(width: width, height: CGFloat(rowCount) * rowHeight)
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class WalletReceiveSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let address: String
    let containerHeight: CGFloat
    let animateOut: ActionSlot<Action<Void>>
    let getController: () -> ViewController?

    init(
        context: AccountContext,
        address: String,
        containerHeight: CGFloat,
        animateOut: ActionSlot<Action<Void>>,
        getController: @escaping () -> ViewController?
    ) {
        self.context = context
        self.address = address
        self.containerHeight = containerHeight
        self.animateOut = animateOut
        self.getController = getController
    }

    static func ==(lhs: WalletReceiveSheetContent, rhs: WalletReceiveSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.address != rhs.address {
            return false
        }
        if lhs.containerHeight != rhs.containerHeight {
            return false
        }
        return true
    }

    final class State: ComponentState {
        private let animateOut: ActionSlot<Action<Void>>
        private let getController: () -> ViewController?
        private let hapticFeedback = HapticFeedback()
        fileprivate var displaysAddress = false

        init(
            animateOut: ActionSlot<Action<Void>>,
            getController: @escaping () -> ViewController?
        ) {
            self.animateOut = animateOut
            self.getController = getController

            super.init()
        }

        func dismiss(animated: Bool) {
            guard let controller = self.getController() as? WalletReceiveScreen else {
                return
            }
            if animated {
                self.animateOut.invoke(Action { [weak controller] _ in
                    controller?.dismiss(completion: nil)
                })
            } else {
                controller.dismiss(animated: false)
            }
        }

        func copyAddress(_ address: String) {
            UIPasteboard.general.string = address
            self.hapticFeedback.tap()
            if !self.displaysAddress {
                self.displaysAddress = true
                self.updated(transition: ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut)))
            }
        }

        func showQrCode() {
            guard self.displaysAddress else {
                return
            }
            self.displaysAddress = false
            self.updated(transition: ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut)))
        }
    }

    func makeState() -> State {
        return State(animateOut: self.animateOut, getController: self.getController)
    }

    static var body: Body {
        let background = Child(RoundedRectangle.self)
        let closeButton = Child(GlassBarButtonComponent.self)
        let addressRing = Child(WalletReceiveAddressRingComponent.self)
        let qrCardBackground = Child(RoundedRectangle.self)
        let qrCode = Child(WalletReceiveQrComponent.self)
        let addressGrid = Child(WalletReceiveAddressGridComponent.self)
        let copiedStatus = Child(HStack<Empty>.self)
        let copyButton = Child(ButtonComponent.self)
        let explanation = Child(BalancedTextComponent.self)
        let buyButton = Child(ButtonComponent.self)

        return { context in
            let component = context.component
            let state = context.state
            let environment = context.environment[EnvironmentType.self].value

            let availableWidth = context.availableSize.width
            let horizontalInset: CGFloat = 30.0 + max(environment.safeInsets.left, environment.safeInsets.right)
            let widthLimitedCardWidth = max(1.0, availableWidth - 104.0)
            let heightLimitedCardWidth = max(1.0, component.containerHeight - 338.0)
            let minimumReadableCardWidth = min(216.0, widthLimitedCardWidth)
            let cardWidth = min(
                256.0,
                widthLimitedCardWidth,
                max(minimumReadableCardWidth, heightLimitedCardWidth)
            )
            let qrSize = max(1.0, cardWidth - 20.0)
            let copyButtonHeight: CGFloat = 28.0
            let cardHeight = qrSize + copyButtonHeight + 24.0
            let ringSize = CGSize(
                width: max(1.0, min(max(1.0, availableWidth - 32.0), cardWidth + 76.0)),
                height: cardHeight + 56.0
            )

            let cardTop: CGFloat = cardWidth < 230.0 ? 58.0 : 70.0
            let cardFrame = CGRect(
                x: floor((availableWidth - cardWidth) / 2.0),
                y: cardTop,
                width: cardWidth,
                height: cardHeight
            )
            let ringFrame = CGRect(
                x: floor((availableWidth - ringSize.width) / 2.0),
                y: cardFrame.minY - 28.0,
                width: ringSize.width,
                height: ringSize.height
            )

            let addressRing = addressRing.update(
                component: WalletReceiveAddressRingComponent(
                    address: component.address,
                    color: UIColor(rgb: 0x0052b3).withAlphaComponent(0.48)
                ),
                availableSize: ringSize,
                transition: context.transition
            )

            let qrCardBackground = qrCardBackground.update(
                component: RoundedRectangle(
                    color: .white,
                    cornerRadius: 28.0,
                    size: cardFrame.size
                ),
                availableSize: cardFrame.size,
                transition: context.transition
            )

            let copyButtonContent: AnyComponentWithIdentity<Empty>
            let copyButtonAction: () -> Void
            if state.displaysAddress {
                //TODO:localize
                let showQrTitle = "Show my QR"
                copyButtonContent = AnyComponentWithIdentity(
                    id: "showQr",
                    component: AnyComponent(Text(
                        text: showQrTitle,
                        font: Font.semibold(14.0),
                        color: UIColor(rgb: 0x087cff)
                    ))
                )
                copyButtonAction = { [weak state] in
                    state?.showQrCode()
                }
            } else {
                //TODO:localize
                let copyTitle = "Copy my address"
                copyButtonContent = AnyComponentWithIdentity(
                    id: "copy",
                    component: AnyComponent(HStack<Empty>([
                        AnyComponentWithIdentity(
                            id: "icon",
                            component: AnyComponent(BundleIconComponent(
                                name: "Wallet/ReceiveCopy",
                                tintColor: UIColor(rgb: 0x087cff)
                            ))
                        ),
                        AnyComponentWithIdentity(
                            id: "title",
                            component: AnyComponent(Text(
                                text: copyTitle,
                                font: Font.semibold(14.0),
                                color: UIColor(rgb: 0x087cff)
                            ))
                        )
                    ], spacing: 7.0))
                )
                copyButtonAction = { [weak state] in
                    state?.copyAddress(component.address)
                }
            }
            let copyButton = copyButton.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: UIColor(rgb: 0x087cff, alpha: 0.1),
                        foreground: UIColor(rgb: 0x087cff),
                        pressedColor: UIColor(rgb: 0xc8e4ff),
                        cornerRadius: copyButtonHeight / 2.0
                    ),
                    content: copyButtonContent,
                    contentInsets: UIEdgeInsets(top: 0.0, left: 14.0, bottom: 0.0, right: 14.0),
                    fitToContentWidth: true,
                    isEnabled: true,
                    displaysProgress: false,
                    action: copyButtonAction
                ),
                availableSize: CGSize(width: max(1.0, cardWidth - 32.0), height: copyButtonHeight),
                transition: context.transition
            )

            let closeButton = closeButton.update(
                component: GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: UIColor(rgb: 0x1883fc),
                    isDark: false,
                    state: .tintedGlass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: .white
                        )
                    )),
                    action: { [weak state] _ in
                        state?.dismiss(animated: true)
                    }
                ),
                availableSize: CGSize(width: 44.0, height: 44.0),
                transition: .immediate
            )

            //TODO:localize
            let explanationText = "Use to receive GRAM on\nThe Open Network (TON) only."
            let explanation = explanation.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: explanationText,
                        font: Font.regular(15.0),
                        textColor: .white
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 2,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(
                    width: max(1.0, availableWidth - horizontalInset * 2.0),
                    height: 100.0
                ),
                transition: .immediate
            )
            let explanationTop = ringFrame.maxY + (cardWidth < 230.0 ? 12.0 : 20.0)

            //TODO:localize
            let buyTitle = "Buy with cash or crypto"
            let buyContent = HStack<Empty>([
                AnyComponentWithIdentity(
                    id: "icon",
                    component: AnyComponent(BundleIconComponent(name: "Wallet/ButtonBuy", tintColor: UIColor(rgb: 0x087cff)))
                ),
                AnyComponentWithIdentity(
                    id: "title",
                    component: AnyComponent(Text(
                        text: buyTitle,
                        font: Font.semibold(17.0),
                        color: UIColor(rgb: 0x087cff)
                    ))
                )
            ], spacing: 10.0)
            let buyButton = buyButton.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .legacy,
                        color: .white,
                        foreground: UIColor(rgb: 0x087cff),
                        pressedColor: UIColor(white: 0.92, alpha: 1.0),
                        cornerRadius: 26.0
                    ),
                    content: AnyComponentWithIdentity(id: "buy", component: AnyComponent(buyContent)),
                    isEnabled: true,
                    displaysProgress: false,
                    action: {
                    }
                ),
                availableSize: CGSize(width: max(1.0, availableWidth - horizontalInset * 2.0), height: 52.0),
                transition: .immediate
            )
            let buyButtonTop = explanationTop + explanation.size.height + (cardWidth < 230.0 ? 18.0 : 30.0)

            let contentHeight = buyButtonTop + buyButton.size.height + max(22.0, environment.safeInsets.bottom + 12.0)
            let background = background.update(
                component: RoundedRectangle(
                    colors: [
                        UIColor(rgb: 0x087cff),
                        UIColor(rgb: 0x4eb9f4),
                        UIColor(rgb: 0x087cff)
                    ],
                    cornerRadius: 0.0,
                    gradientDirection: .vertical,
                    size: CGSize(width: availableWidth, height: contentHeight)
                ),
                availableSize: CGSize(width: availableWidth, height: contentHeight),
                transition: context.transition
            )
            context.add(background.position(CGPoint(x: availableWidth / 2.0, y: contentHeight / 2.0)))
            context.add(addressRing.position(ringFrame.center).opacity(0.0))
            context.add(qrCardBackground.position(cardFrame.center))
            if state.displaysAddress {
                let addressGrid = addressGrid.update(
                    component: WalletReceiveAddressGridComponent(address: component.address),
                    availableSize: CGSize(width: max(1.0, cardWidth - 52.0), height: cardHeight),
                    transition: context.transition
                )
                let addressGridTop = cardFrame.minY + (cardWidth < 230.0 ? 34.0 : 54.0)
                context.add(addressGrid
                    .position(CGPoint(
                        x: cardFrame.midX,
                        y: addressGridTop + addressGrid.size.height / 2.0
                    ))
                    .appear(.default(scale: false, alpha: true))
                    .disappear(.default(scale: false, alpha: true))
                )

                //TODO:localize
                let copiedTitle = "Address copied"
                let copiedStatus = copiedStatus.update(
                    component: HStack<Empty>([
                        AnyComponentWithIdentity(
                            id: "check",
                            component: AnyComponent(Text(
                                text: "✓",
                                font: Font.semibold(14.0),
                                color: UIColor(rgb: 0x087cff)
                            ))
                        ),
                        AnyComponentWithIdentity(
                            id: "title",
                            component: AnyComponent(Text(
                                text: copiedTitle,
                                font: Font.semibold(14.0),
                                color: UIColor(rgb: 0x087cff)
                            ))
                        )
                    ], spacing: 6.0),
                    availableSize: CGSize(width: max(1.0, cardWidth - 40.0), height: 28.0),
                    transition: context.transition
                )
                let copiedStatusTop = addressGridTop + addressGrid.size.height + (cardWidth < 230.0 ? 8.0 : 16.0)
                context.add(copiedStatus
                    .position(CGPoint(
                        x: cardFrame.midX,
                        y: copiedStatusTop + copiedStatus.size.height / 2.0
                    ))
                    .appear(.default(scale: false, alpha: true))
                    .disappear(.default(scale: false, alpha: true))
                )
            } else {
                let qrCode = qrCode.update(
                    component: WalletReceiveQrComponent(address: component.address),
                    availableSize: CGSize(width: qrSize, height: qrSize),
                    transition: context.transition
                )
                context.add(qrCode
                    .position(CGPoint(
                        x: cardFrame.midX,
                        y: cardFrame.minY + 10.0 + qrCode.size.height / 2.0
                    ))
                    .appear(.default(scale: false, alpha: true))
                    .disappear(.default(scale: false, alpha: true))
                )
            }
            context.add(copyButton.position(CGPoint(
                x: cardFrame.midX,
                y: cardFrame.maxY - 16.0 - copyButton.size.height / 2.0
            )))
            context.add(explanation.position(CGPoint(
                x: availableWidth / 2.0,
                y: explanationTop + explanation.size.height / 2.0
            )))
            context.add(buyButton.position(CGPoint(
                x: availableWidth / 2.0,
                y: buyButtonTop + buyButton.size.height / 2.0
            )))
            context.add(closeButton.position(CGPoint(
                x: 16.0 + closeButton.size.width / 2.0,
                y: 16.0 + closeButton.size.height / 2.0
            )))

            return CGSize(width: availableWidth, height: contentHeight)
        }
    }
}

private final class WalletReceiveSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let address: String

    init(context: AccountContext, address: String) {
        self.context = context
        self.address = address
    }

    static func ==(lhs: WalletReceiveSheetComponent, rhs: WalletReceiveSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.address != rhs.address {
            return false
        }
        return true
    }

    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()

        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller

            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(WalletReceiveSheetContent(
                        context: context.component.context,
                        address: context.component.address,
                        containerHeight: context.availableSize.height,
                        animateOut: animateOut,
                        getController: controller
                    )),
                    style: .glass,
                    backgroundColor: .color(UIColor(rgb: 0x087cff)),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    autoAnimateOut: false,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {
                    },
                    willDismiss: {
                    }
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            guard let controller = controller() as? WalletReceiveScreen else {
                                return
                            }
                            if animated {
                                animateOut.invoke(Action { _ in
                                    controller.dismiss(completion: nil)
                                })
                            } else {
                                controller.dismiss(completion: nil)
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(sheet.position(CGPoint(
                x: context.availableSize.width / 2.0,
                y: context.availableSize.height / 2.0
            )))

            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                var sideInset: CGFloat = 0.0
                var bottomInset: CGFloat = max(environment.safeInsets.bottom, sheetExternalState.contentHeight)
                if case .regular = environment.metrics.widthClass {
                    sideInset = floor((context.availableSize.width - 430.0) / 2.0) - 12.0
                    bottomInset = (context.availableSize.height - sheetExternalState.contentHeight) / 2.0 + sheetExternalState.contentHeight
                }

                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(
                        top: 0.0,
                        left: max(sideInset, environment.safeInsets.left),
                        bottom: 0.0,
                        right: max(sideInset, environment.safeInsets.right)
                    ),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(
                    layout,
                    transition: context.transition.containedViewLayoutTransition
                )
            }

            return context.availableSize
        }
    }
}

public final class WalletReceiveScreen: ViewControllerComponentContainer {
    private let context: AccountContext

    public init(context: AccountContext, address: String) {
        self.context = context

        super.init(
            context: context,
            component: WalletReceiveSheetComponent(context: context, address: address),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.disablesInteractiveModalDismiss = true
    }

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(
            tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()
        ) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}
