import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import PresentationDataUtils

// Public entry point — pushed from the Settings screen.
public func fenixAnalyticsController(context: AccountContext) -> ViewController {
    return FenixuzAnalyticsController(context: context)
}

private func formatCount(_ value: Int?) -> String? {
    guard let value = value else {
        return nil
    }
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = true
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

// Rasterizes a tinted SF Symbol into a flat bitmap. ASImageNode draws an image via its
// backing CGImage, which for a `.withTintColor` symbol is still the uncolored template mask
// (renders black). Flattening through a renderer bakes the color into the pixels.
private func renderedSymbol(_ name: String, pointSize: CGFloat, weight: UIImage.SymbolWeight = .regular, color: UIColor) -> UIImage? {
    let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    guard let symbol = UIImage(systemName: name, withConfiguration: config) else {
        return nil
    }
    let tinted = symbol.withTintColor(color, renderingMode: .alwaysOriginal)
    let renderer = UIGraphicsImageRenderer(size: tinted.size)
    return renderer.image { _ in
        tinted.draw(in: CGRect(origin: .zero, size: tinted.size))
    }
}

// iOS 26 "glass" back button: an accent chevron sitting inside a neutral translucent
// circle, matching the native PeerInfo (Novagram settings) back button. Drawn as one
// baked image so it survives as a plain leftBarButtonItem (the system glass treatment is
// only applied to the nav bar's own back node, which we can't reach with a custom button).
private func backButtonImage(circleColor: UIColor, chevronColor: UIColor) -> UIImage? {
    let size = CGSize(width: 30.0, height: 30.0)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
        let c = context.cgContext
        circleColor.setFill()
        c.fillEllipse(in: CGRect(origin: .zero, size: size))
        c.setStrokeColor(chevronColor.cgColor)
        c.setLineWidth(2.0)
        c.setLineCap(.round)
        c.setLineJoin(.round)
        c.move(to: CGPoint(x: 18.0, y: 9.0))
        c.addLine(to: CGPoint(x: 11.5, y: 15.0))
        c.addLine(to: CGPoint(x: 18.0, y: 21.0))
        c.strokePath()
    }.withRenderingMode(.alwaysOriginal)
}

final class FenixuzAnalyticsController: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private var countsDisposable: Disposable?

    private var controllerNode: FenixuzAnalyticsControllerNode {
        return self.displayNode as! FenixuzAnalyticsControllerNode
    }

    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))

        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.title = "Analytics"

        // Icon-only back button: an iOS 26 "glass" chevron-in-a-circle (no "Back" text),
        // matching the native PeerInfo back button. A standard image bar button (not the
        // empty-title back-appearance one — that collapses its hit area and swallows taps),
        // so it stays a real 44pt tap target wired to backPressed.
        self.updateBackButton()

        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let self = self else {
                return
            }
            let previousTheme = self.presentationData.theme
            self.presentationData = presentationData
            if previousTheme !== presentationData.theme {
                self.updateThemeAndStrings()
            }
        })
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.presentationDataDisposable?.dispose()
        self.countsDisposable?.dispose()
    }

    private func updateBackButton() {
        let theme = self.presentationData.theme
        let circleColor = theme.overallDarkAppearance ? UIColor(rgb: 0x767680).withAlphaComponent(0.30) : UIColor(rgb: 0x767680).withAlphaComponent(0.16)
        let chevronColor = theme.rootController.navigationBar.accentTextColor
        let image = backButtonImage(circleColor: circleColor, chevronColor: chevronColor)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(self.backPressed))
    }

    @objc private func backPressed() {
        if let navigationController = self.navigationController as? NavigationController {
            navigationController.filterController(self, animated: true)
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }

    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData), transition: .immediate)
        self.updateBackButton()
        if self.isNodeLoaded {
            self.controllerNode.updatePresentationData(self.presentationData)
        }
    }

    override func loadDisplayNode() {
        self.displayNode = FenixuzAnalyticsControllerNode(presentationData: self.presentationData)
        self.controllerNode.presentUsersInfo = { [weak self] in
            self?.presentInfo(title: "Novagram users", text: "The number of unique devices that have installed Novagram. Each device is counted once.")
        }
        self.controllerNode.presentAccountsInfo = { [weak self] in
            self?.presentInfo(title: "Active accounts", text: "The total number of accounts that have ever signed in to Novagram.")
        }
        self.displayNodeDidLoad()

        self.countsDisposable = (FenixuzAnalyticsManager.shared.counts()
        |> deliverOnMainQueue).start(next: { [weak self] devices, accounts in
            self?.controllerNode.update(devices: devices, accounts: accounts)
        })
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }

    private func presentInfo(title: String, text: String) {
        let actions = [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]
        self.present(textAlertController(context: self.context, title: title, text: text, actions: actions), in: .window(.root))
    }
}

// A single rounded stat card: big number on top, caption + info hint below. The whole card
// is the tap target (opens an explanation alert).
private final class StatChipNode: ASDisplayNode {
    private let valueNode: ImmediateTextNode
    private let captionNode: ImmediateTextNode
    private let infoIconNode: ASImageNode

    private var theme: PresentationTheme
    private let caption: String
    private var value: Int?

    var onTap: (() -> Void)?

    init(theme: PresentationTheme, caption: String) {
        self.theme = theme
        self.caption = caption

        self.valueNode = ImmediateTextNode()
        self.valueNode.maximumNumberOfLines = 1
        self.valueNode.isUserInteractionEnabled = false

        self.captionNode = ImmediateTextNode()
        self.captionNode.maximumNumberOfLines = 1
        self.captionNode.isUserInteractionEnabled = false

        self.infoIconNode = ASImageNode()
        self.infoIconNode.displaysAsynchronously = false
        self.infoIconNode.isUserInteractionEnabled = false

        super.init()

        self.cornerRadius = 16.0
        self.addSubnode(self.valueNode)
        self.addSubnode(self.captionNode)
        self.addSubnode(self.infoIconNode)

        self.applyTheme()
        self.applyValue()
    }

    override func didLoad() {
        super.didLoad()
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapped))
        self.view.addGestureRecognizer(recognizer)
    }

    @objc private func tapped() {
        let view = self.view
        view.alpha = 0.55
        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.allowUserInteraction, .curveEaseOut], animations: {
            view.alpha = 1.0
        })
        self.onTap?()
    }

    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        self.applyTheme()
        self.applyValue()
    }

    func update(value: Int?) {
        self.value = value
        self.applyValue()
    }

    private func applyTheme() {
        self.backgroundColor = self.theme.list.itemBlocksBackgroundColor
        self.layer.borderWidth = UIScreenPixel
        self.layer.borderColor = self.theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.5).cgColor
        if self.theme.overallDarkAppearance {
            self.layer.shadowOpacity = 0.0
        } else {
            self.layer.shadowColor = UIColor.black.cgColor
            self.layer.shadowOpacity = 0.05
            self.layer.shadowOffset = CGSize(width: 0.0, height: 2.0)
            self.layer.shadowRadius = 8.0
        }
        self.captionNode.attributedText = NSAttributedString(string: self.caption, font: Font.regular(13.0), textColor: self.theme.list.itemSecondaryTextColor)
        self.infoIconNode.image = renderedSymbol("info.circle", pointSize: 13.0, color: self.theme.list.itemSecondaryTextColor.withAlphaComponent(0.9))
    }

    private func applyValue() {
        if let text = formatCount(self.value) {
            self.valueNode.attributedText = NSAttributedString(string: text, font: Font.with(size: 34.0, design: .round, weight: .bold), textColor: self.theme.list.itemPrimaryTextColor)
        } else {
            self.valueNode.attributedText = NSAttributedString(string: "—", font: Font.with(size: 34.0, design: .round, weight: .bold), textColor: self.theme.list.itemSecondaryTextColor)
        }
    }

    // Positions the value, caption and info hint inside a fixed-height chip and refreshes the
    // shadow path for the current bounds.
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let horizontalInset: CGFloat = 12.0
        let availableWidth = size.width - horizontalInset * 2.0

        // Shrink the number a step at a time so long counts still fit the chip.
        var valueSize = self.valueNode.updateLayout(CGSize(width: availableWidth, height: .greatestFiniteMagnitude))
        for fontSize in [28.0, 24.0] as [CGFloat] where valueSize.width > availableWidth {
            let color = formatCount(self.value) == nil ? self.theme.list.itemSecondaryTextColor : self.theme.list.itemPrimaryTextColor
            self.valueNode.attributedText = NSAttributedString(string: self.valueNode.attributedText?.string ?? "—", font: Font.with(size: fontSize, design: .round, weight: .bold), textColor: color)
            valueSize = self.valueNode.updateLayout(CGSize(width: availableWidth, height: .greatestFiniteMagnitude))
        }

        let captionSize = self.captionNode.updateLayout(CGSize(width: availableWidth, height: .greatestFiniteMagnitude))
        let infoSide: CGFloat = 14.0
        let captionToInfoGap: CGFloat = 4.0
        let valueToCaptionGap: CGFloat = 5.0

        let captionRowHeight = max(captionSize.height, infoSide)
        let contentHeight = valueSize.height + valueToCaptionGap + captionRowHeight
        var y = floor((size.height - contentHeight) / 2.0)

        transition.updateFrame(node: self.valueNode, frame: CGRect(x: floor((size.width - valueSize.width) / 2.0), y: y, width: valueSize.width, height: valueSize.height))
        y += valueSize.height + valueToCaptionGap

        let captionGroupWidth = captionSize.width + captionToInfoGap + infoSide
        let captionGroupX = floor((size.width - captionGroupWidth) / 2.0)
        transition.updateFrame(node: self.captionNode, frame: CGRect(x: captionGroupX, y: y + floor((captionRowHeight - captionSize.height) / 2.0), width: captionSize.width, height: captionSize.height))
        transition.updateFrame(node: self.infoIconNode, frame: CGRect(x: captionGroupX + captionSize.width + captionToInfoGap, y: y + floor((captionRowHeight - infoSide) / 2.0), width: infoSide, height: infoSide))

        if !self.theme.overallDarkAppearance {
            self.layer.shadowPath = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: self.cornerRadius).cgPath
        }
    }
}

private final class FenixuzAnalyticsControllerNode: ASDisplayNode {
    private var presentationData: PresentationData

    private let duckNode: ASImageNode
    private let subtitleNode: ImmediateTextNode
    private let usersChip: StatChipNode
    private let accountsChip: StatChipNode

    var presentUsersInfo: (() -> Void)?
    var presentAccountsInfo: (() -> Void)?

    private var validLayout: (ContainerViewLayout, CGFloat)?

    init(presentationData: PresentationData) {
        self.presentationData = presentationData

        self.duckNode = ASImageNode()
        self.duckNode.displaysAsynchronously = false
        self.duckNode.contentMode = .scaleAspectFit
        self.duckNode.image = UIImage(bundleImageName: "FenixAnalyticsDuck")

        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.maximumNumberOfLines = 1
        self.subtitleNode.textAlignment = .center

        self.usersChip = StatChipNode(theme: presentationData.theme, caption: "Novagram users")
        self.accountsChip = StatChipNode(theme: presentationData.theme, caption: "Active accounts")

        super.init()

        self.backgroundColor = presentationData.theme.list.blocksBackgroundColor

        self.addSubnode(self.duckNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.usersChip)
        self.addSubnode(self.accountsChip)

        self.usersChip.onTap = { [weak self] in
            self?.presentUsersInfo?()
        }
        self.accountsChip.onTap = { [weak self] in
            self?.presentAccountsInfo?()
        }

        self.applyStaticContent()
        self.applyDuckShadow()
    }

    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.applyStaticContent()
        self.applyDuckShadow()
        self.usersChip.updateTheme(presentationData.theme)
        self.accountsChip.updateTheme(presentationData.theme)
        if let (layout, navigationBarHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }

    func update(devices: Int?, accounts: Int?) {
        self.usersChip.update(value: devices)
        self.accountsChip.update(value: accounts)
        if let (layout, navigationBarHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }

    private func applyStaticContent() {
        self.subtitleNode.attributedText = NSAttributedString(string: "App usage numbers", font: Font.regular(15.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor)
    }

    private func applyDuckShadow() {
        let dark = self.presentationData.theme.overallDarkAppearance
        self.duckNode.layer.shadowColor = UIColor.black.cgColor
        self.duckNode.layer.shadowOpacity = dark ? 0.30 : 0.10
        self.duckNode.layer.shadowOffset = CGSize(width: 0.0, height: dark ? 4.0 : 6.0)
        self.duckNode.layer.shadowRadius = dark ? 16.0 : 18.0
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)

        let sideInset: CGFloat = 16.0
        let rowWidth = min(layout.size.width - sideInset * 2.0, 480.0)
        let rowX = floor((layout.size.width - rowWidth) / 2.0)

        let topPadding: CGFloat = 28.0
        let duckSize: CGFloat = 140.0
        let afterDuck: CGFloat = 14.0
        let afterSubtitle: CGFloat = 24.0
        let chipHeight: CGFloat = 88.0
        let chipGap: CGFloat = 12.0

        var y = navigationBarHeight + topPadding

        transition.updateFrame(node: self.duckNode, frame: CGRect(x: floor((layout.size.width - duckSize) / 2.0), y: y, width: duckSize, height: duckSize))
        y += duckSize + afterDuck

        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: rowWidth, height: .greatestFiniteMagnitude))
        transition.updateFrame(node: self.subtitleNode, frame: CGRect(x: floor((layout.size.width - subtitleSize.width) / 2.0), y: y, width: subtitleSize.width, height: subtitleSize.height))
        y += subtitleSize.height + afterSubtitle

        let leftChipWidth = floor((rowWidth - chipGap) / 2.0)
        let rightChipWidth = rowWidth - chipGap - leftChipWidth
        let usersFrame = CGRect(x: rowX, y: y, width: leftChipWidth, height: chipHeight)
        let accountsFrame = CGRect(x: rowX + leftChipWidth + chipGap, y: y, width: rightChipWidth, height: chipHeight)
        transition.updateFrame(node: self.usersChip, frame: usersFrame)
        transition.updateFrame(node: self.accountsChip, frame: accountsFrame)
        self.usersChip.updateLayout(size: usersFrame.size, transition: transition)
        self.accountsChip.updateLayout(size: accountsFrame.size, transition: transition)
    }
}
