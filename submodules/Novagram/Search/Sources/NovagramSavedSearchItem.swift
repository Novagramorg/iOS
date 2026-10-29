import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import AppBundle
import ContextUI
import ChatListSearchItemHeader
import NovagramLocalization

// The "Saved searches" section of the empty global search screen (above Recent). One scope per search
// pane; the rows are rebuilt on every emission and never stored by the pane between emissions.
public final class NovagramSavedSearchScope {
    public let isEnabled: Bool
    private let context: AccountContext

    // Only the main chat list's own search (no peer picker, no forum, no community, no Saved Messages).
    public init(context: AccountContext, location: ChatListControllerLocation, isPlainSearch: Bool) {
        self.context = context
        if case .chatList = location {
            self.isEnabled = isPlainSearch
        } else {
            self.isEnabled = false
        }
    }

    // A result was opened: remember the typed text (tokens are not part of it).
    public func record(_ query: String?) {
        guard self.isEnabled else {
            return
        }
        NovagramSavedSearches.record(query, accountPeerId: self.context.account.peerId, accountRecordId: self.context.account.id)
    }

    public func rows(appearance: Signal<(PresentationTheme, PresentationStrings), NoError>, owner: AnyObject, present: @escaping (ViewController) -> Void) -> Signal<[NovagramSavedSearchRow], NoError> {
        let context = self.context
        return combineLatest(NovagramSavedSearches.signal(accountPeerId: context.account.peerId), appearance)
        |> map { searches, appearance -> [NovagramSavedSearchRow] in
            return searches.enumerated().map { index, search in
                return NovagramSavedSearchRow(search: search, index: index, theme: appearance.0, strings: appearance.1, context: context, owner: owner, present: present)
            }
        }
    }

    // The search container registers how its search field takes a query; a tapped row looks it up by
    // the search interaction both share. Main thread only.
    private final class QueryHandler {
        let setQuery: (String) -> Void

        init(_ setQuery: @escaping (String) -> Void) {
            self.setQuery = setQuery
        }
    }

    private static let queryHandlers = NSMapTable<AnyObject, QueryHandler>(keyOptions: .weakMemory, valueOptions: .strongMemory)

    public static func setQueryHandler(owner: AnyObject, _ setQuery: @escaping (String) -> Void) {
        self.queryHandlers.setObject(QueryHandler(setQuery), forKey: owner)
    }

    static func setQuery(_ query: String, owner: AnyObject?) {
        guard let owner, let handler = self.queryHandlers.object(forKey: owner) else {
            return
        }
        handler.setQuery(query)
    }
}

public struct NovagramSavedSearchRow: Equatable {
    public let search: NovagramSavedSearch
    public let index: Int
    let theme: PresentationTheme
    let strings: PresentationStrings
    let context: AccountContext
    weak var owner: AnyObject?
    let present: (ViewController) -> Void

    static let headerId = AnyHashable("novagramSavedSearches")

    public var stableKey: String {
        return self.search.query.lowercased()
    }

    public static func == (lhs: NovagramSavedSearchRow, rhs: NovagramSavedSearchRow) -> Bool {
        return lhs.search == rhs.search && lhs.index == rhs.index && lhs.theme === rhs.theme && lhs.strings === rhs.strings
    }

    public func item() -> ListViewItem {
        let title = NovagramL10n(languageCode: NovagramL10n.languageKey(for: self.strings)).search_savedTitle
        let header = ChatListSearchItemHeader(type: .text(title, NovagramSavedSearchRow.headerId), theme: self.theme, strings: self.strings, actionTitle: nil, action: nil)
        return NovagramSavedSearchItem(row: self, header: header)
    }

    func select() {
        NovagramSavedSearchScope.setQuery(self.search.query, owner: self.owner)
    }

    func openMenu(sourceView: UIView, gesture: ContextGesture?) {
        let context = self.context
        let search = self.search
        let l10n = NovagramL10n(languageCode: NovagramL10n.languageKey(for: self.strings))
        let accountPeerId = context.account.peerId
        let accountRecordId = context.account.id
        let items: [ContextMenuItem] = [
            .action(ContextMenuActionItem(text: search.isPinned ? l10n.search_savedUnpin : l10n.search_savedPin, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: search.isPinned ? "Chat/Context Menu/Unpin" : "Chat/Context Menu/Pin"), color: theme.contextMenu.primaryColor)
            }, action: { _, dismiss in
                dismiss(.default)
                NovagramSavedSearches.setPinned(search.query, pinned: !search.isPinned, accountPeerId: accountPeerId, accountRecordId: accountRecordId)
            })),
            .action(ContextMenuActionItem(text: l10n.search_savedRemove, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
            }, action: { _, dismiss in
                dismiss(.default)
                NovagramSavedSearches.remove(search.query, accountPeerId: accountPeerId, accountRecordId: accountRecordId)
            }))
        ]
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = makeContextController(presentationData: presentationData, source: .reference(NovagramSavedSearchReferenceSource(sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        self.present(controller)
    }
}

private final class NovagramSavedSearchReferenceSource: ContextReferenceContentSource {
    private let sourceView: UIView

    init(sourceView: UIView) {
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private let savedSearchHeaderFamily = ListViewItemHeaderFamily("novagramSavedSearch")

private final class NovagramSavedSearchItem: ListViewItem {
    let row: NovagramSavedSearchRow
    let header: ListViewItemHeader?
    let selectable: Bool = true

    var neighborDescriptor: AnyEquatable {
        return AnyEquatable(HeaderNeighborDescriptor(headerId: self.header?.id, headerFamily: savedSearchHeaderFamily))
    }

    init(row: NovagramSavedSearchRow, header: ListViewItemHeader?) {
        self.row = row
        self.header = header
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = NovagramSavedSearchItemNode()
            let (firstWithHeader, last) = self.position(neighbors)
            let (layout, apply) = node.asyncLayout()(self, params, firstWithHeader, last)
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? NovagramSavedSearchItemNode else {
                return
            }
            let makeLayout = nodeValue.asyncLayout()
            async {
                let (firstWithHeader, last) = self.position(neighbors)
                let (layout, apply) = makeLayout(self, params, firstWithHeader, last)
                Queue.mainQueue().async {
                    completion(layout, { _ in
                        apply()
                    })
                }
            }
        }
    }

    func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        self.row.select()
    }

    // First row of the section (room for the header) and last row (no separator).
    private func position(_ neighbors: ListViewItemNeighbors) -> (firstWithHeader: Bool, last: Bool) {
        let headerId = self.header?.id
        var firstWithHeader = true
        if let previous = neighbors.previous?.base(HeaderNeighborFacet.self), previous.headerFamily == savedSearchHeaderFamily {
            firstWithHeader = previous.headerId != headerId
        }
        var last = true
        if let next = neighbors.next?.base(HeaderNeighborFacet.self), next.headerFamily == savedSearchHeaderFamily {
            last = next.headerId != headerId
        }
        return (firstWithHeader, last)
    }
}

private final class NovagramSavedSearchItemNode: ListViewItemNode {
    private static let rowHeight: CGFloat = 44.0
    private static let headerHeight: CGFloat = 29.0
    private static let iconSize: CGFloat = 20.0
    private static let iconInset: CGFloat = 18.0
    private static let textInset: CGFloat = 54.0
    private static let rightInset: CGFloat = 16.0
    private static let labelSpacing: CGFloat = 8.0

    private let containerNode: ContextControllerSourceNode
    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let iconNode: ASImageNode
    private let titleNode: TextNode
    private let labelNode: TextNode
    private let activateArea: AccessibilityAreaNode
    private var item: NovagramSavedSearchItem?

    init() {
        self.containerNode = ContextControllerSourceNode()
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode.alpha = 0.0
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.activateArea = AccessibilityAreaNode()

        super.init(layerBacked: false)

        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.backgroundNode)
        self.containerNode.addSubnode(self.highlightedBackgroundNode)
        self.containerNode.addSubnode(self.separatorNode)
        self.containerNode.addSubnode(self.iconNode)
        self.containerNode.addSubnode(self.titleNode)
        self.containerNode.addSubnode(self.labelNode)
        self.addSubnode(self.activateArea)

        self.containerNode.activated = { [weak self] gesture, _ in
            guard let self, let item = self.item else {
                gesture.cancel()
                return
            }
            item.row.openMenu(sourceView: self.containerNode.view, gesture: gesture)
        }
        self.activateArea.activate = { [weak self] in
            self?.item?.row.select()
            return true
        }
    }

    func asyncLayout() -> (_ item: NovagramSavedSearchItem, _ params: ListViewItemLayoutParams, _ firstWithHeader: Bool, _ last: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)

        return { item, params, firstWithHeader, last in
            let row = item.row
            let theme = row.theme
            let l10n = NovagramL10n(languageCode: NovagramL10n.languageKey(for: row.strings))
            let labelText = row.search.isPinned ? l10n.search_savedPinned : ""

            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: labelText, font: Font.regular(15.0), textColor: theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width / 3.0, height: .greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let labelWidth = labelText.isEmpty ? 0.0 : labelLayout.size.width + NovagramSavedSearchItemNode.labelSpacing
            let titleWidth = max(1.0, params.width - params.leftInset - params.rightInset - NovagramSavedSearchItemNode.textInset - NovagramSavedSearchItemNode.rightInset - labelWidth)
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: row.search.query, font: Font.regular(17.0), textColor: theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: titleWidth, height: .greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))

            let contentSize = CGSize(width: params.width, height: NovagramSavedSearchItemNode.rowHeight)
            let insets = UIEdgeInsets(top: firstWithHeader ? NovagramSavedSearchItemNode.headerHeight : 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)

            return (layout, { [weak self] in
                guard let self else {
                    return
                }
                self.item = item
                _ = titleApply()
                _ = labelApply()

                let bounds = CGRect(origin: CGPoint(), size: contentSize)
                self.containerNode.frame = bounds
                self.backgroundNode.backgroundColor = theme.list.plainBackgroundColor
                self.backgroundNode.frame = bounds
                self.highlightedBackgroundNode.backgroundColor = theme.list.itemHighlightedBackgroundColor
                self.highlightedBackgroundNode.frame = bounds
                self.separatorNode.backgroundColor = theme.list.itemPlainSeparatorColor
                self.separatorNode.isHidden = last
                let textX = params.leftInset + NovagramSavedSearchItemNode.textInset
                self.separatorNode.frame = CGRect(x: textX, y: contentSize.height - UIScreenPixel, width: max(0.0, params.width - params.rightInset - textX), height: UIScreenPixel)

                let symbol = UIImage(systemName: "magnifyingglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17.0, weight: .regular))
                self.iconNode.image = symbol?.withTintColor(theme.list.itemSecondaryTextColor, renderingMode: .alwaysOriginal)
                let iconSize = self.iconNode.image?.size ?? CGSize(width: NovagramSavedSearchItemNode.iconSize, height: NovagramSavedSearchItemNode.iconSize)
                self.iconNode.frame = CGRect(x: params.leftInset + NovagramSavedSearchItemNode.iconInset, y: floor((contentSize.height - iconSize.height) / 2.0), width: iconSize.width, height: iconSize.height)

                self.titleNode.frame = CGRect(x: textX, y: floor((contentSize.height - titleLayout.size.height) / 2.0), width: titleLayout.size.width, height: titleLayout.size.height)
                self.labelNode.frame = CGRect(x: params.width - params.rightInset - NovagramSavedSearchItemNode.rightInset - labelLayout.size.width, y: floor((contentSize.height - labelLayout.size.height) / 2.0), width: labelLayout.size.width, height: labelLayout.size.height)

                self.activateArea.frame = bounds
                self.activateArea.accessibilityLabel = labelText.isEmpty ? row.search.query : "\(row.search.query), \(labelText)"
                self.activateArea.accessibilityTraits = .button
            })
        }
    }

    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
        } else {
            let previous = self.highlightedBackgroundNode.alpha
            self.highlightedBackgroundNode.alpha = 0.0
            if animated {
                self.highlightedBackgroundNode.layer.animateAlpha(from: previous, to: 0.0, duration: 0.3)
            }
        }
    }

    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
    }

    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }

    override func headers() -> [ListViewItemHeader]? {
        return self.item?.header.flatMap { [$0] }
    }
}
