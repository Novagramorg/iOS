import Foundation
import UIKit
import CoreText
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
    let cardSize: CGSize
    let cardCornerRadius: CGFloat
    let pathOffset: CGFloat

    init(
        address: String,
        color: UIColor,
        cardSize: CGSize,
        cardCornerRadius: CGFloat,
        pathOffset: CGFloat
    ) {
        self.address = address
        self.color = color
        self.cardSize = cardSize
        self.cardCornerRadius = cardCornerRadius
        self.pathOffset = pathOffset
    }

    static func ==(lhs: WalletReceiveAddressRingComponent, rhs: WalletReceiveAddressRingComponent) -> Bool {
        if lhs.address != rhs.address {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        if lhs.cardSize != rhs.cardSize {
            return false
        }
        if lhs.cardCornerRadius != rhs.cardCornerRadius {
            return false
        }
        if lhs.pathOffset != rhs.pathOffset {
            return false
        }
        return true
    }

    final class View: UIView {
        private struct RoundedRectPerimeter {
            struct Sample {
                let point: CGPoint
                let tangent: CGVector
            }

            let rect: CGRect
            let radius: CGFloat
            let horizontalLength: CGFloat
            let verticalLength: CGFloat
            let cornerLength: CGFloat
            let length: CGFloat

            init?(rect inputRect: CGRect, radius proposedRadius: CGFloat) {
                guard inputRect.origin.x.isFinite, inputRect.origin.y.isFinite,
                      inputRect.width.isFinite, inputRect.height.isFinite,
                      proposedRadius.isFinite else {
                    return nil
                }

                let rect = inputRect.standardized
                guard rect.width > 0.0, rect.height > 0.0 else {
                    return nil
                }

                let radius = min(max(0.0, proposedRadius), min(rect.width, rect.height) * 0.5)
                let horizontalLength = max(0.0, rect.width - radius * 2.0)
                let verticalLength = max(0.0, rect.height - radius * 2.0)
                let cornerLength = CGFloat.pi * radius * 0.5
                let length = horizontalLength * 2.0 + verticalLength * 2.0 + cornerLength * 4.0
                guard length.isFinite, length > 0.0 else {
                    return nil
                }

                self.rect = rect
                self.radius = radius
                self.horizontalLength = horizontalLength
                self.verticalLength = verticalLength
                self.cornerLength = cornerLength
                self.length = length
            }

            private func arcSample(center: CGPoint, angle: CGFloat) -> Sample {
                let sine = sin(angle)
                let cosine = cos(angle)
                return Sample(
                    point: CGPoint(
                        x: center.x + self.radius * cosine,
                        y: center.y + self.radius * sine
                    ),
                    tangent: CGVector(dx: -sine, dy: cosine)
                )
            }

            func sample(at distance: CGFloat) -> Sample {
                var normalizedDistance: CGFloat
                if distance.isFinite {
                    normalizedDistance = distance.truncatingRemainder(dividingBy: self.length)
                } else {
                    normalizedDistance = 0.0
                }
                if normalizedDistance < 0.0 {
                    normalizedDistance += self.length
                }

                // The primitive path starts at the top-left tangency. Apply a phase so that
                // distance zero is the center of the top edge.
                var segmentDistance = normalizedDistance + self.horizontalLength * 0.5
                if segmentDistance >= self.length {
                    segmentDistance -= self.length
                }

                if self.horizontalLength > 0.0 && segmentDistance < self.horizontalLength {
                    return Sample(
                        point: CGPoint(
                            x: self.rect.minX + self.radius + segmentDistance,
                            y: self.rect.minY
                        ),
                        tangent: CGVector(dx: 1.0, dy: 0.0)
                    )
                }
                segmentDistance -= self.horizontalLength

                if self.cornerLength > 0.0 && segmentDistance < self.cornerLength {
                    return self.arcSample(
                        center: CGPoint(x: self.rect.maxX - self.radius, y: self.rect.minY + self.radius),
                        angle: -.pi * 0.5 + segmentDistance / self.radius
                    )
                }
                segmentDistance -= self.cornerLength

                if self.verticalLength > 0.0 && segmentDistance < self.verticalLength {
                    return Sample(
                        point: CGPoint(
                            x: self.rect.maxX,
                            y: self.rect.minY + self.radius + segmentDistance
                        ),
                        tangent: CGVector(dx: 0.0, dy: 1.0)
                    )
                }
                segmentDistance -= self.verticalLength

                if self.cornerLength > 0.0 && segmentDistance < self.cornerLength {
                    return self.arcSample(
                        center: CGPoint(x: self.rect.maxX - self.radius, y: self.rect.maxY - self.radius),
                        angle: segmentDistance / self.radius
                    )
                }
                segmentDistance -= self.cornerLength

                if self.horizontalLength > 0.0 && segmentDistance < self.horizontalLength {
                    return Sample(
                        point: CGPoint(
                            x: self.rect.maxX - self.radius - segmentDistance,
                            y: self.rect.maxY
                        ),
                        tangent: CGVector(dx: -1.0, dy: 0.0)
                    )
                }
                segmentDistance -= self.horizontalLength

                if self.cornerLength > 0.0 && segmentDistance < self.cornerLength {
                    return self.arcSample(
                        center: CGPoint(x: self.rect.minX + self.radius, y: self.rect.maxY - self.radius),
                        angle: .pi * 0.5 + segmentDistance / self.radius
                    )
                }
                segmentDistance -= self.cornerLength

                if self.verticalLength > 0.0 && segmentDistance < self.verticalLength {
                    return Sample(
                        point: CGPoint(
                            x: self.rect.minX,
                            y: self.rect.maxY - self.radius - segmentDistance
                        ),
                        tangent: CGVector(dx: 0.0, dy: -1.0)
                    )
                }
                segmentDistance -= self.verticalLength

                if self.cornerLength > 0.0 && segmentDistance < self.cornerLength {
                    return self.arcSample(
                        center: CGPoint(x: self.rect.minX + self.radius, y: self.rect.minY + self.radius),
                        angle: .pi + segmentDistance / self.radius
                    )
                }

                return Sample(
                    point: CGPoint(x: self.rect.minX + self.radius, y: self.rect.minY),
                    tangent: CGVector(dx: 1.0, dy: 0.0)
                )
            }
        }

        private struct GlyphItem {
            let glyph: CGGlyph
            let position: CGPoint
            let advance: CGFloat
            let font: CTFont
        }

        private struct GlyphLayout {
            let items: [GlyphItem]
            let width: CGFloat
        }

        private var component: WalletReceiveAddressRingComponent?
        private var availableSize: CGSize = .zero

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isOpaque = false
            self.backgroundColor = .clear
            self.contentMode = .redraw
            self.isUserInteractionEnabled = false
            self.isAccessibilityElement = false
            self.accessibilityElementsHidden = true
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

        private static func glyphLayout(text: String, font: UIFont) -> GlyphLayout? {
            let line = CTLineCreateWithAttributedString(NSAttributedString(
                string: text,
                attributes: [.font: font]
            ))

            var items: [GlyphItem] = []
            let glyphRuns = CTLineGetGlyphRuns(line) as NSArray
            for runValue in glyphRuns {
                let run = runValue as! CTRun
                let glyphCount = CTRunGetGlyphCount(run)
                if glyphCount == 0 {
                    continue
                }

                var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
                var positions = [CGPoint](repeating: .zero, count: glyphCount)
                var advances = [CGSize](repeating: .zero, count: glyphCount)
                let range = CFRangeMake(0, glyphCount)
                CTRunGetGlyphs(run, range, &glyphs)
                CTRunGetPositions(run, range, &positions)
                CTRunGetAdvances(run, range, &advances)

                let attributes = CTRunGetAttributes(run) as NSDictionary
                guard let runFont = attributes[kCTFontAttributeName] as! CTFont? else {
                    continue
                }

                for index in 0 ..< glyphCount {
                    items.append(GlyphItem(
                        glyph: glyphs[index],
                        position: positions[index],
                        advance: max(0.0, advances[index].width),
                        font: runFont
                    ))
                }
            }

            items.sort { lhs, rhs in
                return lhs.position.x < rhs.position.x
            }
            guard !items.isEmpty else {
                return nil
            }

            var width: CGFloat = 0.0
            for item in items {
                width = max(width, item.position.x + item.advance)
            }
            guard width.isFinite, width > 0.0 else {
                return nil
            }

            return GlyphLayout(items: items, width: width)
        }

        override func draw(_ rect: CGRect) {
            guard let component = self.component, !component.address.isEmpty,
                  let graphicsContext = UIGraphicsGetCurrentContext() else {
                return
            }

            let bounds = self.bounds
            guard bounds.origin.x.isFinite, bounds.origin.y.isFinite,
                  bounds.width.isFinite, bounds.height.isFinite,
                  bounds.width > 0.0, bounds.height > 0.0,
                  component.cardSize.width.isFinite, component.cardSize.height.isFinite,
                  component.cardCornerRadius.isFinite, component.pathOffset.isFinite else {
                return
            }

            let groupedAddress = Self.groupedAddress(component.address)
                .joined(separator: " ")
                .uppercased()
            guard !groupedAddress.isEmpty else {
                return
            }

            let baseFontSize = max(8.0, min(11.0, bounds.width / 31.0)) * 1.2
            let baseFont = Font.with(size: baseFontSize, design: .monospace, weight: .semibold)

            let cardSize = CGSize(
                width: max(0.0, component.cardSize.width),
                height: max(0.0, component.cardSize.height)
            )
            let cardRect = CGRect(
                x: bounds.midX - cardSize.width * 0.5,
                y: bounds.midY - cardSize.height * 0.5,
                width: cardSize.width,
                height: cardSize.height
            )
            let pathOffset = max(0.0, component.pathOffset)
            let desiredPathRect = cardRect.insetBy(dx: -pathOffset, dy: -pathOffset)

            let glyphInset = ceil(baseFont.lineHeight * 0.5)
            let safeInsetX = min(glyphInset, max(0.0, (bounds.width - 1.0) * 0.5))
            let safeInsetY = min(glyphInset, max(0.0, (bounds.height - 1.0) * 0.5))
            let safeBounds = bounds.insetBy(dx: safeInsetX, dy: safeInsetY)
            let pathRect = desiredPathRect.intersection(safeBounds)
            guard !pathRect.isNull, !pathRect.isEmpty else {
                return
            }

            let cardCornerRadius = min(
                max(0.0, component.cardCornerRadius),
                min(cardRect.width, cardRect.height) * 0.5
            )
            guard let perimeter = RoundedRectPerimeter(
                rect: pathRect,
                radius: cardCornerRadius + pathOffset
            ) else {
                return
            }

            let halfLength = perimeter.length * 0.5
            guard halfLength.isFinite, halfLength > 0.0 else {
                return
            }

            let unitText = "· \(groupedAddress) "
            guard let glyphLayout = Self.glyphLayout(text: unitText, font: baseFont) else {
                return
            }
            let glyphScale: CGFloat
            if glyphLayout.width > halfLength {
                glyphScale = halfLength / glyphLayout.width * 0.99
            } else {
                glyphScale = 1.0
            }
            guard glyphScale.isFinite, glyphScale > 0.0 else {
                return
            }

            let tracking = max(
                0.0,
                (halfLength - glyphLayout.width * glyphScale) / CGFloat(glyphLayout.items.count)
            )
            guard let firstItem = glyphLayout.items.first else {
                return
            }
            let firstCenter = (firstItem.position.x + firstItem.advance * 0.5) * glyphScale

            graphicsContext.saveGState()
            graphicsContext.setFillColor(component.color.cgColor)
            graphicsContext.setTextDrawingMode(.fill)

            for copyIndex in 0 ..< 2 {
                let copyOffset = CGFloat(copyIndex) * halfLength
                for index in 0 ..< glyphLayout.items.count {
                    let item = glyphLayout.items[index]
                    let centerOffset = (item.position.x + item.advance * 0.5) * glyphScale - firstCenter
                    let distance = copyOffset + centerOffset + CGFloat(index) * tracking
                    let sample = perimeter.sample(at: distance)
                    let angle = atan2(sample.tangent.dy, sample.tangent.dx)

                    graphicsContext.saveGState()
                    graphicsContext.translateBy(x: sample.point.x, y: sample.point.y)
                    graphicsContext.rotate(by: angle)
                    graphicsContext.scaleBy(x: glyphScale, y: -glyphScale)
                    graphicsContext.textMatrix = .identity

                    var glyph = item.glyph
                    var glyphPosition = CGPoint(
                        x: -item.advance * 0.5,
                        y: (CTFontGetDescent(item.font) - CTFontGetAscent(item.font)) * 0.5
                    )
                    CTFontDrawGlyphs(item.font, &glyph, &glyphPosition, 1, graphicsContext)
                    graphicsContext.restoreGState()
                }
            }

            graphicsContext.restoreGState()
        }

        func update(
            component: WalletReceiveAddressRingComponent,
            availableSize: CGSize
        ) -> CGSize {
            let needsDisplay: Bool
            if let currentComponent = self.component {
                needsDisplay = currentComponent != component || self.availableSize != availableSize
            } else {
                needsDisplay = true
            }

            self.component = component
            self.availableSize = availableSize
            if needsDisplay {
                self.setNeedsDisplay()
            }

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
        return view.update(component: self, availableSize: availableSize)
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
            let cardCornerRadius: CGFloat = 28.0
            let ringPathOffset: CGFloat = 14.0
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
                    color: UIColor(rgb: 0x0052b3).withAlphaComponent(0.48),
                    cardSize: cardFrame.size,
                    cardCornerRadius: cardCornerRadius,
                    pathOffset: ringPathOffset
                ),
                availableSize: ringSize,
                transition: context.transition
            )

            let qrCardBackground = qrCardBackground.update(
                component: RoundedRectangle(
                    color: .white,
                    cornerRadius: cardCornerRadius,
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
                        UIColor(rgb: 0x0079ff),
                        UIColor(rgb: 0x46b2ff),
                        UIColor(rgb: 0x46b2ff),
                        UIColor(rgb: 0x067eff)
                    ],
                    cornerRadius: 0.0,
                    gradientDirection: .vertical,
                    size: CGSize(width: availableWidth, height: contentHeight)
                ),
                availableSize: CGSize(width: availableWidth, height: contentHeight),
                transition: context.transition
            )
            context.add(background.position(CGPoint(x: availableWidth / 2.0, y: contentHeight / 2.0)))
            context.add(addressRing.position(ringFrame.center))
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
                    backgroundColor: .color(UIColor(rgb: 0x0079ff)),
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
