import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import AvatarNode

// Chat-list shaped row for the "All Accounts" screen.
//
// Layout (at the default 17pt list font, params.leftInset == params.rightInset == 16):
//
//   28                100                                        w-32
//   ┌──────────┐      Azimjon Abdurasulov                    ┌─────────┐
//   │  avatar  │      @Xabarchi123                           │ Current │
//   └──────────┘      +998 33 599 94 79                      └─────────┘
//                     └── separator starts here, ends at the card edge (w-16)
//
// Name / username / phone are three fixed lines. An unknown identifier renders as an em dash
// instead of collapsing, so every row is exactly the same height. Lines 1-2 stop short of the
// pill; line 3 starts below the pill's band and therefore uses the full card width.
//
// This lives in Fenixuz on purpose: ItemListDisclosureItem hardcodes a 46pt text inset for
// iconPeer rows, so a 60pt avatar would overlap the text there, and patching it would touch a
// Telegram-owned file used by dozens of settings screens.

enum FenixAccountStatus: Equatable {
    case current
    case active
    case sleeping
}

// The single toggle offered for a non-current row: Activate or Put to Sleep.
// Surfaced three ways — long-press context menu (owned by the controller), trailing swipe, and
// a VoiceOver custom action.
struct FenixAccountToggle {
    enum Kind {
        case activate
        case putToSleep
    }

    let kind: Kind
    let title: String
    let action: () -> Void

    init(kind: Kind, title: String, action: @escaping () -> Void) {
        self.kind = kind
        self.title = title
        self.action = action
    }
}

private let cardInnerInset: CGFloat = 12.0
private let avatarTextSpacing: CGFloat = 12.0
private let titleUsernameSpacing: CGFloat = 3.0
private let usernamePhoneSpacing: CGFloat = 1.0
private let avatarVerticalPadding: CGFloat = 16.0
private let textBlockVerticalPadding: CGFloat = 21.0
private let pillHorizontalPadding: CGFloat = 8.0
private let pillTextSpacing: CGFloat = 8.0
private let pillRightInset: CGFloat = 16.0
// Stands in for an identifier we don't have. The line keeps its box either way, so a row with no
// username is exactly as tall as one carrying both identifiers.
private let unknownIdentifierPlaceholder = "\u{2014}"
// Line 3 when neither identifier is known: same box height, no visible glyph.
private let reservedEmptyLine = " "

// Decoded avatars for sleeping accounts, keyed by peerId. Reading + decoding the mirrored PNG on
// every state emission (4 signals x up to 5 accounts) was the single most expensive thing this
// screen did, and it ran on the main thread.
private let fenixAccountAvatarCache = Atomic<[Int64: UIImage?]>(value: [:])

private func fenixCachedAccountAvatar(peerId: Int64) -> UIImage? {
    if peerId == 0 {
        return nil
    }
    if let cached = fenixAccountAvatarCache.with({ $0[peerId] }) {
        return cached
    }
    var image: UIImage?
    // Path formula duplicated from fenixAccountAvatarCachePath — same process, same Caches dir.
    if let caches = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first {
        let path = caches + "/fenixuz-account-avatars/\(peerId).png"
        if FileManager.default.fileExists(atPath: path) {
            image = UIImage(contentsOfFile: path)
        }
    }
    _ = fenixAccountAvatarCache.modify { current in
        var updated = current
        // updateValue, not subscript: `dict[key] = nil` on a dictionary of optionals removes the
        // entry instead of storing a "no avatar" answer.
        updated.updateValue(image, forKey: peerId)
        return updated
    }
    return image
}

// A sleeping account has no live peer, but we still know its peerId and cached display name, which
// is everything AvatarNode needs to draw the same gradient + initials it drew while the account was
// live. Cheaper and darkmode-correct compared to hand-rolling a palette.
private func fenixPlaceholderPeer(peerId: Int64, title: String) -> EnginePeer {
    let parts = title.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
    let firstName = parts.first.map(String.init)
    let lastName = parts.count > 1 ? String(parts[1]) : nil
    return .user(TelegramUser(
        id: EnginePeer.Id(peerId),
        accessHash: nil,
        firstName: firstName,
        lastName: lastName,
        username: nil,
        phone: nil,
        photo: [],
        botInfo: nil,
        restrictionInfo: nil,
        flags: UserInfoFlags(),
        emojiStatus: nil,
        usernames: [],
        storiesHidden: nil,
        nameColor: nil,
        backgroundEmojiId: nil,
        profileColor: nil,
        profileBackgroundEmojiId: nil,
        subscriberCount: nil,
        verificationIconFileId: nil
    ))
}

// 14pt bold labels count as "large text" for WCAG, so the contrast floor is 3:1 rather than 4.5:1 —
// which is the only way a saturated pill passes at all.
private func fenixAccountPillColors(status: FenixAccountStatus, theme: PresentationTheme) -> (fill: UIColor, text: UIColor) {
    switch status {
    case .current:
        // Darkened Novagram blue: the plain accent (#0A9BF5) measures 3.0:1 against white.
        return (UIColor(rgb: 0x0a8fe0), UIColor(rgb: 0xffffff))
    case .active:
        if theme.overallDarkAppearance {
            return (UIColor(rgb: 0x4dc278), UIColor(rgb: 0x0b2e1a))
        } else {
            return (UIColor(rgb: 0x2e9e5b), UIColor(rgb: 0xffffff))
        }
    case .sleeping:
        let fill = theme.list.itemSecondaryTextColor.withAlphaComponent(0.12)
        // #6d6d72 is the light-appearance grey; on a dark card it drops to ~2:1, so dark mode uses
        // the theme's own secondary text color instead.
        let text = theme.overallDarkAppearance ? theme.list.itemSecondaryTextColor : UIColor(rgb: 0x6d6d72)
        return (fill, text)
    }
}

final class FenixAccountItem: ListViewItem, ItemListItem, ItemListRevealOptionsStatefulItem {
    let presentationData: ItemListPresentationData
    let context: AccountContext
    let peerId: Int64
    let title: String
    let username: String
    let phone: String
    let secondaryFallback: String
    let status: FenixAccountStatus
    let statusLabel: String
    let accessibilityHintText: String
    let livePeer: EnginePeer?
    let revealed: Bool
    let sectionId: ItemListSectionId
    let action: (() -> Void)?
    let toggle: FenixAccountToggle?
    let setRevealed: (Bool) -> Void

    let selectable: Bool

    var hasActiveRevealOptions: Bool {
        return self.revealed
    }

    init(
        presentationData: ItemListPresentationData,
        context: AccountContext,
        peerId: Int64,
        title: String,
        username: String,
        phone: String,
        secondaryFallback: String,
        status: FenixAccountStatus,
        statusLabel: String,
        accessibilityHintText: String,
        livePeer: EnginePeer?,
        revealed: Bool,
        sectionId: ItemListSectionId,
        action: (() -> Void)?,
        toggle: FenixAccountToggle?,
        setRevealed: @escaping (Bool) -> Void
    ) {
        self.presentationData = presentationData
        self.context = context
        self.peerId = peerId
        self.title = title
        self.username = username
        self.phone = phone
        self.secondaryFallback = secondaryFallback
        self.status = status
        self.statusLabel = statusLabel
        self.accessibilityHintText = accessibilityHintText
        self.livePeer = livePeer
        self.revealed = revealed
        self.sectionId = sectionId
        self.action = action
        self.toggle = toggle
        self.setRevealed = setRevealed
        self.selectable = action != nil
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = FenixAccountItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))

            node.contentSize = layout.contentSize
            node.insets = layout.insets

            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(synchronousLoads, false) })
                })
            }
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? FenixAccountItemNode else {
                return
            }
            let makeLayout = nodeValue.asyncLayout()

            var animated = true
            if case .None = animation {
                animated = false
            }

            async {
                let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                Queue.mainQueue().async {
                    completion(layout, { _ in
                        apply(false, animated)
                    })
                }
            }
        }
    }

    func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        self.action?()
    }
}

final class FenixAccountItemNode: ItemListRevealOptionsItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode

    // Reveal option nodes are positioned in absolute row coordinates, so they must NOT live inside
    // the container we translate by revealOffset.
    private let controlsContainerNode: ASDisplayNode
    private let contentContainerNode: ASDisplayNode

    private let avatarNode: AvatarNode
    private var cachedAvatarView: UIImageView?
    private let titleNode: TextNode
    // Line 2: the username, an em dash, or — when neither identifier is known — the fallback label.
    private let usernameNode: TextNode
    private let phoneNode: TextNode
    private let pillBackgroundNode: ASImageNode
    private let pillLabelNode: TextNode

    private var layoutParams: (FenixAccountItem, ListViewItemLayoutParams, ItemListNeighbors)?
    private var contentContainerSize: CGSize?

    override var controlsContainer: ASDisplayNode {
        return self.controlsContainerNode
    }

    override var canBeSelected: Bool {
        if self.isDisplayingRevealedOptions {
            return false
        }
        return self.layoutParams?.0.action != nil
    }

    var tag: ItemListItemTag? {
        return nil
    }

    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true

        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true

        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true

        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true

        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false

        self.controlsContainerNode = ASDisplayNode()
        self.contentContainerNode = ASDisplayNode()

        self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 26.0))

        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale

        self.usernameNode = TextNode()
        self.usernameNode.isUserInteractionEnabled = false
        self.usernameNode.contentMode = .left
        self.usernameNode.contentsScale = UIScreen.main.scale

        self.phoneNode = TextNode()
        self.phoneNode.isUserInteractionEnabled = false
        self.phoneNode.contentMode = .left
        self.phoneNode.contentsScale = UIScreen.main.scale

        self.pillBackgroundNode = ASImageNode()
        self.pillBackgroundNode.displayWithoutProcessing = true
        self.pillBackgroundNode.displaysAsynchronously = false
        self.pillBackgroundNode.isLayerBacked = true

        self.pillLabelNode = TextNode()
        self.pillLabelNode.isUserInteractionEnabled = false
        self.pillLabelNode.contentMode = .left
        self.pillLabelNode.contentsScale = UIScreen.main.scale

        super.init(layerBacked: false, rotated: false, seeThrough: false)

        self.isAccessibilityElement = true

        self.addSubnode(self.controlsContainerNode)
        self.controlsContainerNode.addSubnode(self.contentContainerNode)
        self.contentContainerNode.addSubnode(self.avatarNode)
        self.contentContainerNode.addSubnode(self.titleNode)
        self.contentContainerNode.addSubnode(self.usernameNode)
        self.contentContainerNode.addSubnode(self.phoneNode)
        self.contentContainerNode.addSubnode(self.pillBackgroundNode)
        self.contentContainerNode.addSubnode(self.pillLabelNode)
    }

    func asyncLayout() -> (_ item: FenixAccountItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool, Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeUsernameLayout = TextNode.asyncLayout(self.usernameNode)
        let makePhoneLayout = TextNode.asyncLayout(self.phoneNode)
        let makePillLabelLayout = TextNode.asyncLayout(self.pillLabelNode)

        let currentItem = self.layoutParams?.0
        let hasPillImage = self.pillBackgroundNode.image != nil

        return { item, params, neighbors in
            let theme = item.presentationData.theme
            let baseFontSize = item.presentationData.fontSize.itemListBaseFontSize

            let avatarDiameter = min(60.0, floor(item.presentationData.fontSize.baseDisplaySize * 60.0 / 17.0))
            let avatarFontSize = floor(avatarDiameter * 26.0 / 60.0)

            let cardLeft = params.leftInset
            let cardRight = params.width - params.rightInset
            let avatarLeft = cardLeft + cardInnerInset
            let textLeft = avatarLeft + avatarDiameter + avatarTextSpacing

            let pillHeight = floor(baseFontSize * 20.0 / 17.0)
            let pillFont = Font.bold(floor(baseFontSize * 14.0 / 17.0))
            let pillRightEdge = cardRight - pillRightInset
            let stackedPillTopSpacing = floor(baseFontSize * 6.0 / 17.0)

            let pillColors = fenixAccountPillColors(status: item.status, theme: theme)

            var updatedPillImage: UIImage?
            if !hasPillImage
                || currentItem?.presentationData.theme !== theme
                || currentItem?.status != item.status
                || currentItem?.presentationData.fontSize != item.presentationData.fontSize {
                updatedPillImage = generateStretchableFilledCircleImage(diameter: pillHeight, color: pillColors.fill)
            }

            let pillLabelString = NSAttributedString(string: item.statusLabel, font: pillFont, textColor: pillColors.text)
            let (pillLabelLayout, pillLabelApply) = makePillLabelLayout(TextNodeLayoutArguments(attributedString: pillLabelString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(1.0, cardRight - textLeft), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let pillWidth = max(pillHeight, pillLabelLayout.size.width + pillHorizontalPadding * 2.0)

            // Three fixed lines. A missing identifier becomes an em dash rather than folding the
            // line away; only when both are missing does line 2 borrow the fallback label and
            // line 3 shrink to an invisible-but-still-measured box.
            let usernameText: String
            let phoneText: String
            if item.username.isEmpty && item.phone.isEmpty {
                usernameText = item.secondaryFallback
                phoneText = reservedEmptyLine
            } else {
                usernameText = item.username.isEmpty ? unknownIdentifierPlaceholder : item.username
                phoneText = item.phone.isEmpty ? unknownIdentifierPlaceholder : item.phone
            }

            // Lines 1-2 share their band with the pill; line 3 sits below it and gets the whole card.
            let pillAvoidingWidth = max(1.0, pillRightEdge - pillWidth - pillTextSpacing - textLeft)
            let fullTextWidth = max(1.0, pillRightEdge - textLeft)

            let titleFont = Font.semibold(floor(baseFontSize * 16.0 / 17.0))
            let titleString = NSAttributedString(string: item.title, font: titleFont, textColor: theme.list.itemPrimaryTextColor)

            // The pill drops below the text exactly when the name would otherwise truncate. That is
            // a width test, not a font-size test, so narrow devices and longer localized pill
            // labels ("Активный" vs "Uyquda") self-correct.
            let (narrowTitleLayout, narrowTitleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: pillAvoidingWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let isStackedPill = narrowTitleLayout.truncated
            let headerTextWidth = isStackedPill ? fullTextWidth : pillAvoidingWidth

            let titleLayout: TextNodeLayout
            let titleApply: () -> TextNode
            if isStackedPill {
                let relaidTitle = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: fullTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                titleLayout = relaidTitle.0
                titleApply = relaidTitle.1
            } else {
                titleLayout = narrowTitleLayout
                titleApply = narrowTitleApply
            }

            // Same size and colour on both identity lines — weight alone separates them. There is no
            // contrast headroom left in itemSecondaryTextColor to dim or shrink line 3 with.
            let identityFontSize = floor(baseFontSize * 15.0 / 17.0)
            let usernameString = NSAttributedString(string: usernameText, font: Font.medium(identityFontSize), textColor: theme.list.itemSecondaryTextColor)
            let (usernameLayout, usernameApply) = makeUsernameLayout(TextNodeLayoutArguments(attributedString: usernameString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: headerTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))

            let phoneString = NSAttributedString(string: phoneText, font: Font.regular(identityFontSize), textColor: theme.list.itemSecondaryTextColor)
            let (phoneLayout, phoneApply) = makePhoneLayout(TextNodeLayoutArguments(attributedString: phoneString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: fullTextWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))

            var textBlockHeight = titleLayout.size.height + titleUsernameSpacing + usernameLayout.size.height + usernamePhoneSpacing + phoneLayout.size.height
            if isStackedPill {
                textBlockHeight += stackedPillTopSpacing + pillHeight
            }
            let contentHeight = max(avatarDiameter + avatarVerticalPadding, textBlockHeight + textBlockVerticalPadding)
            let contentSize = CGSize(width: params.width, height: contentHeight)

            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let separatorHeight = UIScreenPixel
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)

            let cachedAvatarImage: UIImage? = item.livePeer == nil ? fenixCachedAccountAvatar(peerId: item.peerId) : nil
            let placeholderPeer: EnginePeer? = (item.livePeer == nil && cachedAvatarImage == nil) ? fenixPlaceholderPeer(peerId: item.peerId, title: item.title) : nil

            return (layout, { [weak self] synchronousLoad, animated in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.layoutParams = (item, params, neighbors)
                strongSelf.contentContainerSize = contentSize

                let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.4, curve: .spring) : .immediate
                let revealOffset = strongSelf.revealOffset

                // Announced in visual order (the label carries the name), and an em-dash placeholder
                // is dropped rather than read out as "dash".
                var accessibilityValueParts: [String] = []
                if !item.username.isEmpty {
                    accessibilityValueParts.append(item.username)
                }
                if !item.phone.isEmpty {
                    accessibilityValueParts.append(item.phone)
                }
                accessibilityValueParts.append(item.statusLabel)

                strongSelf.accessibilityLabel = item.title
                strongSelf.accessibilityValue = accessibilityValueParts.joined(separator: ", ")
                strongSelf.accessibilityHint = item.accessibilityHintText
                strongSelf.accessibilityTraits = item.action != nil ? .button : .staticText
                // Long-press is the only route to Activate / Put to Sleep on touch, and VoiceOver
                // cannot perform it — so it gets an explicit custom action instead.
                if let toggle = item.toggle {
                    strongSelf.accessibilityCustomActions = [
                        UIAccessibilityCustomAction(name: toggle.title, actionHandler: { _ in
                            toggle.action()
                            return true
                        })
                    ]
                } else {
                    strongSelf.accessibilityCustomActions = nil
                }

                strongSelf.backgroundNode.backgroundColor = theme.list.itemBlocksBackgroundColor
                strongSelf.topStripeNode.backgroundColor = theme.list.itemBlocksSeparatorColor
                strongSelf.bottomStripeNode.backgroundColor = theme.list.itemBlocksSeparatorColor
                strongSelf.highlightedBackgroundNode.backgroundColor = theme.list.itemHighlightedBackgroundColor

                if strongSelf.backgroundNode.supernode == nil {
                    strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                }
                if strongSelf.topStripeNode.supernode == nil {
                    strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                }
                if strongSelf.bottomStripeNode.supernode == nil {
                    strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                }
                if strongSelf.maskNode.supernode == nil {
                    strongSelf.addSubnode(strongSelf.maskNode)
                }

                let hasCorners = itemListHasRoundedBlockLayout(params)
                var hasTopCorners = false
                var hasBottomCorners = false
                let topStripeIsHidden: Bool
                switch neighbors.top {
                case .sameSection(false):
                    topStripeIsHidden = true
                default:
                    hasTopCorners = true
                    topStripeIsHidden = hasCorners
                }
                let bottomStripeInset: CGFloat
                let bottomStripeOffset: CGFloat
                let bottomStripeIsHidden: Bool
                switch neighbors.bottom {
                case .sameSection(false):
                    bottomStripeInset = textLeft
                    bottomStripeOffset = -separatorHeight
                    bottomStripeIsHidden = false
                default:
                    bottomStripeInset = 0.0
                    bottomStripeOffset = 0.0
                    hasBottomCorners = true
                    bottomStripeIsHidden = hasCorners
                }
                strongSelf.updateRevealOptionsSeparatorNodes(top: strongSelf.topStripeNode, bottom: strongSelf.bottomStripeNode, topIsHidden: topStripeIsHidden, bottomIsHidden: bottomStripeIsHidden, topHiddenByPreviousRevealOptions: neighbors.topHasActiveRevealOptions, bottomHiddenByNextRevealOptions: neighbors.bottomHasActiveRevealOptions)

                strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(theme, top: hasTopCorners, bottom: hasBottomCorners) : nil

                strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentHeight + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                transition.updateFrame(node: strongSelf.topStripeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight)))
                transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentHeight + bottomStripeOffset), size: CGSize(width: params.width - bottomStripeInset - params.rightInset, height: separatorHeight)))

                strongSelf.controlsContainerNode.frame = CGRect(origin: CGPoint(), size: contentSize)
                transition.updateFrame(node: strongSelf.contentContainerNode, frame: CGRect(origin: CGPoint(x: revealOffset, y: 0.0), size: contentSize))

                _ = titleApply()
                _ = usernameApply()
                _ = phoneApply()
                _ = pillLabelApply()

                let textTop = floorToScreenPixels((contentHeight - textBlockHeight) / 2.0)
                let titleFrame = CGRect(origin: CGPoint(x: textLeft, y: textTop), size: titleLayout.size)
                transition.updateFrame(node: strongSelf.titleNode, frame: titleFrame)
                let usernameFrame = CGRect(origin: CGPoint(x: textLeft, y: titleFrame.maxY + titleUsernameSpacing), size: usernameLayout.size)
                transition.updateFrame(node: strongSelf.usernameNode, frame: usernameFrame)
                let phoneFrame = CGRect(origin: CGPoint(x: textLeft, y: usernameFrame.maxY + usernamePhoneSpacing), size: phoneLayout.size)
                transition.updateFrame(node: strongSelf.phoneNode, frame: phoneFrame)

                if let updatedPillImage = updatedPillImage {
                    strongSelf.pillBackgroundNode.image = updatedPillImage
                }
                let pillFrame: CGRect
                if isStackedPill {
                    pillFrame = CGRect(origin: CGPoint(x: textLeft, y: phoneFrame.maxY + stackedPillTopSpacing), size: CGSize(width: pillWidth, height: pillHeight))
                } else {
                    pillFrame = CGRect(origin: CGPoint(x: pillRightEdge - pillWidth, y: floorToScreenPixels((contentHeight - pillHeight) / 2.0)), size: CGSize(width: pillWidth, height: pillHeight))
                }
                transition.updateFrame(node: strongSelf.pillBackgroundNode, frame: pillFrame)
                transition.updateFrame(node: strongSelf.pillLabelNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels(pillFrame.midX - pillLabelLayout.size.width / 2.0), y: floorToScreenPixels(pillFrame.midY - pillLabelLayout.size.height / 2.0)), size: pillLabelLayout.size))

                let avatarFrame = CGRect(origin: CGPoint(x: avatarLeft, y: floorToScreenPixels((contentHeight - avatarDiameter) / 2.0)), size: CGSize(width: avatarDiameter, height: avatarDiameter))
                strongSelf.avatarNode.font = avatarPlaceholderFont(size: avatarFontSize)
                transition.updateFrame(node: strongSelf.avatarNode, frame: avatarFrame)

                // Live peer → mirrored PNG → initials, same fallback chain as before.
                if let livePeer = item.livePeer {
                    strongSelf.removeCachedAvatarView()
                    strongSelf.avatarNode.isHidden = false
                    strongSelf.avatarNode.setPeer(context: item.context, theme: theme, peer: livePeer, synchronousLoad: synchronousLoad, displayDimensions: avatarFrame.size)
                } else if let cachedAvatarImage = cachedAvatarImage {
                    strongSelf.avatarNode.isHidden = true
                    let cachedAvatarView: UIImageView
                    if let current = strongSelf.cachedAvatarView {
                        cachedAvatarView = current
                    } else {
                        cachedAvatarView = UIImageView()
                        cachedAvatarView.contentMode = .scaleAspectFill
                        cachedAvatarView.clipsToBounds = true
                        strongSelf.cachedAvatarView = cachedAvatarView
                        strongSelf.contentContainerNode.view.addSubview(cachedAvatarView)
                    }
                    cachedAvatarView.image = cachedAvatarImage
                    cachedAvatarView.layer.cornerRadius = avatarDiameter / 2.0
                    transition.updateFrame(view: cachedAvatarView, frame: avatarFrame)
                } else if let placeholderPeer = placeholderPeer {
                    strongSelf.removeCachedAvatarView()
                    strongSelf.avatarNode.isHidden = false
                    strongSelf.avatarNode.setPeer(context: item.context, theme: theme, peer: placeholderPeer, synchronousLoad: synchronousLoad, displayDimensions: avatarFrame.size)
                }

                strongSelf.updateRevealOptionsHighlightedBackgroundFrame(strongSelf.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentHeight + UIScreenPixel + UIScreenPixel)), transition: transition)

                strongSelf.updateLayout(size: contentSize, leftInset: params.leftInset, rightInset: params.rightInset)

                var revealOptions: [ItemListRevealOption] = []
                if let toggle = item.toggle {
                    let colors: PresentationThemeFillForeground
                    switch toggle.kind {
                    case .activate:
                        colors = theme.list.itemDisclosureActions.constructive
                    case .putToSleep:
                        colors = theme.list.itemDisclosureActions.accent
                    }
                    revealOptions.append(ItemListRevealOption(key: 0, title: toggle.title, icon: .none, color: colors.fillColor, iconColor: colors.foregroundColor, textColor: theme.list.itemSecondaryTextColor))
                }
                strongSelf.setRevealOptions((left: [], right: revealOptions))
                // Only correct the node when the model disagrees, so an unrelated state emission
                // mid-swipe can't snap the row shut under the user's finger.
                if item.revealed != strongSelf.isDisplayingRevealedOptions {
                    strongSelf.setRevealOptionsOpened(item.revealed, animated: animated)
                }

                strongSelf.updateIsHighlighted(transition: transition)
            })
        }
    }

    private func removeCachedAvatarView() {
        if let cachedAvatarView = self.cachedAvatarView {
            self.cachedAvatarView = nil
            cachedAvatarView.removeFromSuperview()
        }
    }

    private var isHighlighted = false

    private var reallyHighlighted: Bool {
        return self.isHighlighted || self.isRevealOptionsActive
    }

    private func updateIsHighlighted(transition: ContainedViewLayoutTransition) {
        self.updateRevealOptionsHighlightedBackgroundNode(self.highlightedBackgroundNode, isHighlighted: self.reallyHighlighted, transition: transition, aboveNodes: [self.bottomStripeNode, self.topStripeNode, self.backgroundNode])
    }

    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)

        self.isHighlighted = highlighted
        self.updateIsHighlighted(transition: (animated && !highlighted) ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
    }

    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }

    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }

    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)

        guard let contentContainerSize = self.contentContainerSize else {
            return
        }
        transition.updateFrame(node: self.contentContainerNode, frame: CGRect(origin: CGPoint(x: offset, y: 0.0), size: contentContainerSize))
    }

    override func revealOptionsActiveStateUpdated(isActive: Bool, transition: ContainedViewLayoutTransition) {
        super.revealOptionsActiveStateUpdated(isActive: isActive, transition: transition)

        self.updateIsHighlighted(transition: transition)
    }

    override func revealOptionsInteractivelyOpened() {
        self.layoutParams?.0.setRevealed(true)
    }

    override func revealOptionsInteractivelyClosed() {
        self.layoutParams?.0.setRevealed(false)
    }

    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()

        self.layoutParams?.0.toggle?.action()
    }
}
