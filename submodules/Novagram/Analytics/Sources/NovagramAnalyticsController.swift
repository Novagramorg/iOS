import Foundation
import UIKit
import SwiftUI
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import TelegramStringFormatting
import AnimatedStickerNode
import LottieSettings
import TelegramAnimatedStickerNode
import AccountContext
import PresentationDataUtils
import NovagramLocalization
import NovagramServices
import NovagramServicesUI

// Public entry point — pushed from the Settings screen.
public func novagramAnalyticsController(context: AccountContext) -> ViewController {
    return NovagramAnalyticsController(context: context)
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

// The page is the services SDK's StatisticsCard (NovagramServicesUI). This controller keeps what is
// ours: the counts (SDK core, through NovagramAnalyticsManager), the texts, the duck and the
// explanation alerts.
final class NovagramAnalyticsController: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private var countsDisposable: Disposable?
    private var hostingController: UIHostingController<AnyView>?
    private var counts: StatisticsCounts?

    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))

        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        // Chinese Telegram packs use free-form codes ("zh-hans-raw", "classic-zh-cn", ...), so fold them into "zh".
        let titleLanguage = self.presentationData.strings.baseLanguageCode.lowercased()
        let isChineseTitle = titleLanguage.hasPrefix("zh") || titleLanguage.contains("-zh") || titleLanguage.contains("_zh")
        switch isChineseTitle ? "zh" : self.presentationData.strings.baseLanguageCode {
        case "uz": self.title = "Analitika"
        case "ru": self.title = "Аналитика"
        case "zh": self.title = "统计"
        default: self.title = "Analytics"
        }

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
        // Match the rest of the app: every other back chevron is the primary label colour,
        // not the accent. Analytics was the only blue one.
        let chevronColor = theme.rootController.navigationBar.primaryTextColor
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
            self.displayNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
            self.updateContent()
        }
    }

    override func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor

        let hostingController = UIHostingController(rootView: self.makeContent())
        hostingController.view.backgroundColor = .clear
        self.addChild(hostingController)
        self.displayNode.view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        self.hostingController = hostingController

        self.displayNodeDidLoad()

        self.countsDisposable = (NovagramAnalyticsManager.shared.counts()
        |> deliverOnMainQueue).start(next: { [weak self] devices, accounts in
            guard let self = self else {
                return
            }
            if let devices = devices, let accounts = accounts {
                self.counts = StatisticsCounts(downloads: devices, active: accounts)
            } else {
                self.counts = nil
            }
            self.updateContent()
        })
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let navigationBarHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        let contentFrame = CGRect(x: 0.0, y: navigationBarHeight, width: layout.size.width, height: max(0.0, layout.size.height - navigationBarHeight))
        if let view = self.hostingController?.view {
            transition.updateFrame(view: view, frame: contentFrame)
        }
    }

    private func updateContent() {
        guard self.isNodeLoaded else {
            return
        }
        // The same view type stays at the root, so the duck keeps playing.
        self.hostingController?.rootView = self.makeContent()
    }

    // The old page's layout: 28 pt under the bar, 16 pt sides, rows at most 480 pt wide.
    private func makeContent() -> AnyView {
        let presentationData = self.presentationData
        let l10n = NovagramL10n(presentationData.strings)
        let isDark = presentationData.theme.overallDarkAppearance
        let card = StatisticsCard(
            counts: self.counts,
            strings: StatisticsStrings(
                subtitle: l10n.analytics_subtitle,
                downloadsCaption: l10n.analytics_usersCaption,
                activeCaption: l10n.analytics_accountsCaption
            ),
            theme: ServicesUITheme(presentationData.theme),
            locale: localeWithStrings(presentationData.strings),
            onInfo: { [weak self] counter in
                self?.presentInfo(for: counter)
            }
        ) {
            DuckStickerView(isDark: isDark)
                .frame(width: 140.0, height: 140.0)
        }
        return AnyView(
            card
                .frame(maxWidth: 480.0)
                .padding(.horizontal, 16.0)
                .padding(.top, 28.0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        )
    }

    private func presentInfo(for counter: StatisticsCounter) {
        let l10n = NovagramL10n(self.presentationData.strings)
        switch counter {
        case .downloads:
            self.presentInfo(title: l10n.analytics_usersCaption, text: l10n.analytics_usersInfo)
        case .active:
            self.presentInfo(title: l10n.analytics_accountsCaption, text: l10n.analytics_accountsInfo)
        @unknown default:
            break
        }
    }

    private func presentInfo(title: String, text: String) {
        let actions = [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]
        self.present(textAlertController(context: self.context, title: title, text: text, actions: actions), in: .window(.root))
    }
}

// The SDK's color tokens from the Telegram theme (the mapping in the SDK's docs/UI.md).
private extension ServicesUITheme {
    init(_ theme: PresentationTheme) {
        self.init(
            cardBackground: Color(theme.list.itemBlocksBackgroundColor),
            separator: Color(theme.list.itemBlocksSeparatorColor),
            primaryText: Color(theme.list.itemPrimaryTextColor),
            secondaryText: Color(theme.list.itemSecondaryTextColor),
            accent: Color(theme.list.itemAccentColor),
            positive: Color(theme.list.freeTextSuccessColor),
            negative: Color(theme.list.itemDestructiveColor),
            isDark: theme.overallDarkAppearance
        )
    }
}

// The card's header: BroadcastGroup.tgs is the animated version of the NovagramAnalyticsDuck artwork —
// same duck, same megaphone, same podium (layer `21_MEGAPHN`, assets `tumba`/`mega_circ`).
private struct DuckStickerView: UIViewRepresentable {
    let isDark: Bool

    func makeUIView(context: Context) -> DuckStickerContainerView {
        return DuckStickerContainerView()
    }

    func updateUIView(_ view: DuckStickerContainerView, context: Context) {
        view.applyShadow(isDark: self.isDark)
    }
}

private final class DuckStickerContainerView: UIView {
    // The view keeps the node alive.
    private let duckNode: AnimatedStickerNode

    init() {
        self.duckNode = DefaultAnimatedStickerNodeImpl(lottieSettings: .noAccountFallback)
        self.duckNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "BroadcastGroup"), width: 448, height: 448, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
        self.duckNode.visibility = true

        super.init(frame: .zero)

        self.addSubview(self.duckNode.view)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // The silhouette shadow the duck had on the old page.
    func applyShadow(isDark: Bool) {
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = isDark ? 0.30 : 0.10
        self.layer.shadowOffset = CGSize(width: 0.0, height: isDark ? 4.0 : 6.0)
        self.layer.shadowRadius = isDark ? 16.0 : 18.0
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.duckNode.frame = self.bounds
        // An AnimatedStickerNode renders nothing from its frame alone — it needs updateLayout too.
        self.duckNode.updateLayout(size: self.bounds.size)
    }
}
