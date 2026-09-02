import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import ContextUI
import ContextControllerImpl
import WalletContext

typealias WalletCurrencyListItem = (currency: WalletContext.FiatCurrency, name: String)

func walletCurrencyListItems() -> [WalletCurrencyListItem] {
    return WalletContext.FiatCurrency.allCases.map { currency in
        return (currency, walletCurrencyName(currency))
    }
}

//TODO:localize
private func walletCurrencyName(_ currency: WalletContext.FiatCurrency) -> String {
    switch currency {
    case .usd: return "US Dollar"
    case .eur: return "Euro"
    case .rub: return "Russian Ruble"
    case .cny: return "Chinese Yuan"
    case .aed: return "UAE Dirham"
    case .afn: return "Afghan Afghani"
    case .all: return "Albanian Lek"
    case .amd: return "Armenian Dram"
    case .ars: return "Argentine Peso"
    case .aud: return "Australian Dollar"
    case .azn: return "Azerbaijani Manat"
    case .bam: return "Bosnia-Herzegovina Convertible Mark"
    case .bdt: return "Bangladeshi Taka"
    case .bgn: return "Bulgarian Lev"
    case .bhd: return "Bahraini Dinar"
    case .bnd: return "Brunei Dollar"
    case .bob: return "Bolivian Boliviano"
    case .brl: return "Brazilian Real"
    case .byn: return "Belarusian Ruble"
    case .cad: return "Canadian Dollar"
    case .chf: return "Swiss Franc"
    case .clp: return "Chilean Peso"
    case .cop: return "Colombian Peso"
    case .crc: return "Costa Rican Colón"
    case .czk: return "Czech Koruna"
    case .dkk: return "Danish Krone"
    case .dop: return "Dominican Peso"
    case .dzd: return "Algerian Dinar"
    case .egp: return "Egyptian Pound"
    case .etb: return "Ethiopian Birr"
    case .gbp: return "British Pound"
    case .gel: return "Georgian Lari"
    case .ghs: return "Ghanaian Cedi"
    case .gtq: return "Guatemalan Quetzal"
    case .hkd: return "Hong Kong Dollar"
    case .hnl: return "Honduran Lempira"
    case .hrk: return "Croatian Kuna"
    case .huf: return "Hungarian Forint"
    case .idr: return "Indonesian Rupiah"
    case .ils: return "Israeli New Shekel"
    case .inr: return "Indian Rupee"
    case .iqd: return "Iraqi Dinar"
    case .irr: return "Iranian Rial"
    case .isk: return "Icelandic Króna"
    case .jmd: return "Jamaican Dollar"
    case .jod: return "Jordanian Dinar"
    case .jpy: return "Japanese Yen"
    case .kes: return "Kenyan Shilling"
    case .kgs: return "Kyrgyzstani Som"
    case .krw: return "South Korean Won"
    case .kzt: return "Kazakhstani Tenge"
    case .lbp: return "Lebanese Pound"
    case .lkr: return "Sri Lankan Rupee"
    case .mad: return "Moroccan Dirham"
    case .mdl: return "Moldovan Leu"
    case .mmk: return "Myanmar Kyat"
    case .mnt: return "Mongolian Tögrög"
    case .mop: return "Macanese Pataca"
    case .mur: return "Mauritian Rupee"
    case .mvr: return "Maldivian Rufiyaa"
    case .mxn: return "Mexican Peso"
    case .myr: return "Malaysian Ringgit"
    case .mzn: return "Mozambican Metical"
    case .ngn: return "Nigerian Naira"
    case .nio: return "Nicaraguan Córdoba"
    case .nok: return "Norwegian Krone"
    case .npr: return "Nepalese Rupee"
    case .nzd: return "New Zealand Dollar"
    case .pab: return "Panamanian Balboa"
    case .pen: return "Peruvian Sol"
    case .php: return "Philippine Peso"
    case .pkr: return "Pakistani Rupee"
    case .pln: return "Polish Złoty"
    case .pyg: return "Paraguayan Guaraní"
    case .qar: return "Qatari Riyal"
    case .ron: return "Romanian Leu"
    case .rsd: return "Serbian Dinar"
    case .sar: return "Saudi Riyal"
    case .sek: return "Swedish Krona"
    case .sgd: return "Singapore Dollar"
    case .syp: return "Syrian Pound"
    case .thb: return "Thai Baht"
    case .tjs: return "Tajikistani Somoni"
    case .tryCurrency: return "Turkish Lira"
    case .ttd: return "Trinidad and Tobago Dollar"
    case .twd: return "New Taiwan Dollar"
    case .tzs: return "Tanzanian Shilling"
    case .uah: return "Ukrainian Hryvnia"
    case .ugx: return "Ugandan Shilling"
    case .uyu: return "Uruguayan Peso"
    case .uzs: return "Uzbekistani Som"
    case .vnd: return "Vietnamese Đồng"
    case .yer: return "Yemeni Rial"
    case .zar: return "South African Rand"
    }
}

final class WalletCurrencyListContextItem: ContextMenuCustomItem {
    let context: AccountContext
    let currencies: [WalletCurrencyListItem]
    let selectedCurrency: WalletContext.FiatCurrency
    let searchQuery: Signal<String, NoError>
    let currencySelected: (WalletContext.FiatCurrency) -> Void

    init(
        context: AccountContext,
        currencies: [WalletCurrencyListItem],
        selectedCurrency: WalletContext.FiatCurrency,
        searchQuery: Signal<String, NoError>,
        currencySelected: @escaping (WalletContext.FiatCurrency) -> Void
    ) {
        self.context = context
        self.currencies = currencies
        self.selectedCurrency = selectedCurrency
        self.searchQuery = searchQuery
        self.currencySelected = currencySelected
    }

    func node(
        presentationData: PresentationData,
        getController: @escaping () -> ContextControllerProtocol?,
        actionSelected: @escaping (ContextMenuActionResult) -> Void
    ) -> ContextMenuCustomNode {
        return WalletCurrencyListContextItemNode(
            presentationData: presentationData,
            item: self,
            getController: getController,
            actionSelected: actionSelected
        )
    }
}

private func walletCurrencySearchTokens(_ value: String) -> [String] {
    let normalizedValue = value
        .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        .lowercased()
    return normalizedValue.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
}

private func filteredWalletCurrencies(_ currencies: [WalletCurrencyListItem], query: String) -> [WalletCurrencyListItem] {
    if query.isEmpty {
        return currencies
    }
    let queryTokens = walletCurrencySearchTokens(query)
    if queryTokens.isEmpty {
        return []
    }

    return currencies.filter { item in
        let itemTokens = walletCurrencySearchTokens("\(item.currency.code) \(item.name)")
        return queryTokens.allSatisfy { queryToken in
            return itemTokens.contains(where: { itemToken in
                return itemToken.hasPrefix(queryToken)
            })
        }
    }
}

private func walletCurrencyAction(
    item: WalletCurrencyListContextItem,
    currency: WalletCurrencyListItem
) -> ContextMenuActionItem {
    return ContextMenuActionItem(
        text: currency.currency.code,
        textLayout: .secondLineWithValue(currency.name),
        icon: { _ in
            return nil
        },
        additionalLeftIcon: { theme in
            if currency.currency == item.selectedCurrency {
                return generateTintedImage(
                    image: UIImage(bundleImageName: "Chat/Context Menu/Check"),
                    color: theme.contextMenu.primaryColor
                )
            } else {
                return UIImage()
            }
        },
        action: { _, dismiss in
            item.currencySelected(currency.currency)
            dismiss(.default)
        }
    )
}

private final class WalletCurrencyListContextItemNode: ASDisplayNode, ContextMenuCustomNode, ContextActionNodeProtocol, ASScrollViewDelegate {
    private enum ItemType {
        case currency(WalletCurrencyListItem)
        case noResults
    }

    private let item: WalletCurrencyListContextItem
    private let presentationData: PresentationData
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void

    private let scrollNode: ASScrollNode
    private var actionNodes: [AnyHashable: ContextControllerActionsListActionItemNode] = [:]

    private var searchDisposable: Disposable?
    private var searchQuery = ""

    private var currencyItemHeight: CGFloat?
    private var noResultsItemHeight: CGFloat?
    private var totalContentHeight: CGFloat = 0.0
    private var maxWidth: CGFloat?

    let needsPadding: Bool = false

    init(
        presentationData: PresentationData,
        item: WalletCurrencyListContextItem,
        getController: @escaping () -> ContextControllerProtocol?,
        actionSelected: @escaping (ContextMenuActionResult) -> Void
    ) {
        self.item = item
        self.presentationData = presentationData.withUpdate(listsFontSize: .regular)
        self.getController = getController
        self.actionSelected = actionSelected
        self.scrollNode = ASScrollNode()

        super.init()

        self.addSubnode(self.scrollNode)

        self.searchDisposable = (item.searchQuery
        |> deliverOnMainQueue).start(next: { [weak self] searchQuery in
            guard let self else {
                return
            }
            let updatedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard self.searchQuery != updatedQuery else {
                return
            }
            self.searchQuery = updatedQuery
            self.totalContentHeight = 0.0
            if self.scrollNode.view.contentOffset != .zero {
                self.scrollNode.view.setContentOffset(.zero, animated: false)
            }
            self.getController()?.requestLayout(transition: .immediate)
        })
    }

    deinit {
        self.searchDisposable?.dispose()
    }

    override func didLoad() {
        super.didLoad()

        self.scrollNode.view.delegate = self.wrappedScrollViewDelegate
        self.scrollNode.view.alwaysBounceVertical = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.scrollIndicatorInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 5.0, right: 0.0)
        self.scrollNode.view.scrollsToTop = false
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let maxWidth = self.maxWidth {
            self.updateScrolling(maxWidth: maxWidth)
        }
    }

    private func visibleItems(in scrollView: UIScrollView, constrainedWidth: CGFloat) -> [(id: AnyHashable, type: ItemType, frame: CGRect)] {
        let currencies = filteredWalletCurrencies(self.item.currencies, query: self.searchQuery)
        var items: [(id: AnyHashable, type: ItemType, frame: CGRect)] = []
        var yOffset: CGFloat = 0.0

        for currency in currencies {
            let height = self.currencyItemHeight ?? 60.0
            let frame = CGRect(x: 0.0, y: yOffset, width: constrainedWidth, height: height)
            items.append((AnyHashable(currency.currency.code), .currency(currency), frame))
            yOffset += height
        }

        if !self.searchQuery.isEmpty && currencies.isEmpty {
            let height = self.noResultsItemHeight ?? 42.0
            let frame = CGRect(x: 0.0, y: yOffset, width: constrainedWidth, height: height)
            items.append((AnyHashable("noResults"), .noResults, frame))
            yOffset += height
        }

        self.totalContentHeight = yOffset

        let visibleBounds = scrollView.bounds.insetBy(dx: 0.0, dy: -100.0)
        return items.filter { visibleBounds.intersects($0.frame) }
    }

    private func updateScrolling(maxWidth: CGFloat) {
        let scrollView = self.scrollNode.view
        let visibleItems = self.visibleItems(in: scrollView, constrainedWidth: scrollView.bounds.width)
        var validNodeIds = Set<AnyHashable>()
        var measuredNewHeight = false

        for (itemId, itemType, frame) in visibleItems {
            validNodeIds.insert(itemId)

            let action: ContextMenuActionItem
            switch itemType {
            case let .currency(currency):
                action = walletCurrencyAction(item: self.item, currency: currency)
            case .noResults:
                let noAction: ((ContextControllerProtocol?, @escaping (ContextMenuActionResult) -> Void) -> Void)? = nil
                action = ContextMenuActionItem(
                    text: self.presentationData.strings.Conversation_SearchNoResults,
                    textFont: .small,
                    icon: { _ in
                        return nil
                    },
                    action: noAction
                )
            }

            let actionNode: ContextControllerActionsListActionItemNode
            if let current = self.actionNodes[itemId] {
                actionNode = current
                actionNode.setItem(item: action)
            } else {
                actionNode = ContextControllerActionsListActionItemNode(
                    context: self.item.context,
                    getController: self.getController,
                    requestDismiss: self.actionSelected,
                    requestUpdateAction: { _, _ in },
                    item: action
                )
                self.actionNodes[itemId] = actionNode
                self.scrollNode.addSubnode(actionNode)
            }

            actionNode.frame = frame
            let (minSize, complete) = actionNode.update(
                presentationData: self.presentationData,
                constrainedSize: frame.size
            )
            switch itemType {
            case .currency:
                if self.currencyItemHeight == nil {
                    self.currencyItemHeight = minSize.height
                    measuredNewHeight = true
                }
            case .noResults:
                if self.noResultsItemHeight == nil {
                    self.noResultsItemHeight = minSize.height
                    measuredNewHeight = true
                }
            }
            complete(CGSize(width: maxWidth, height: minSize.height), .immediate)
        }

        var nodesToRemove: [AnyHashable] = []
        for (nodeId, node) in self.actionNodes {
            if !validNodeIds.contains(nodeId) {
                nodesToRemove.append(nodeId)
                node.removeFromSupernode()
            }
        }
        for nodeId in nodesToRemove {
            self.actionNodes.removeValue(forKey: nodeId)
        }

        self.scrollNode.view.contentSize = CGSize(width: scrollView.bounds.width, height: self.totalContentHeight)

        if measuredNewHeight {
            self.getController()?.requestLayout(transition: .animated(duration: 0.45, curve: .spring))
        }
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let minActionsWidth: CGFloat = 270.0
        let maxActionsWidth: CGFloat = 300.0
        let constrainedWidth = min(constrainedWidth, maxActionsWidth)
        let maxWidth = max(constrainedWidth, minActionsWidth)
        let maxHeight = min(360.0, max(0.0, constrainedHeight - 150.0))

        if self.totalContentHeight == 0.0 {
            let _ = self.visibleItems(in: UIScrollView(), constrainedWidth: constrainedWidth)
        }

        return (CGSize(width: maxWidth, height: min(maxHeight, self.totalContentHeight)), { size, transition in
            self.maxWidth = maxWidth
            transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: .zero, size: size))
            self.scrollNode.view.contentSize = CGSize(width: size.width, height: self.totalContentHeight)
            self.updateScrolling(maxWidth: maxWidth)
        })
    }

    func updateTheme(presentationData: PresentationData) {
    }

    var isActionEnabled: Bool {
        return true
    }

    func performAction() {
    }

    func setIsHighlighted(_ value: Bool) {
    }

    func canBeHighlighted() -> Bool {
        return false
    }

    func updateIsHighlighted(isHighlighted: Bool) {
    }

    func actionNode(at point: CGPoint) -> ContextActionNodeProtocol {
        return self
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        for actionNode in self.actionNodes.values {
            actionNode.updateIsHighlighted(isHighlighted: false)
        }
    }
}
