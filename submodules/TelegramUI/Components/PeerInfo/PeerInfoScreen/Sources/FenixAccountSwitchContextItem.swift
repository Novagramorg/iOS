import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ContextUI

// Custom context menu item for non-current accounts in the Settings tab-bar long-press switcher.
//
// Renders: left = colored initials circle (30 pt), center-column = name (bold) + @username
// (secondary, smaller). Tapping calls the provided action closure.
//
// Used in PeerInfoScreen.tabBarItemContextAction to replace plain ContextMenuActionItem rows for
// non-current accounts, which showed only a name + arrow icon and had no avatar or username.

// MARK: - Public item type

final class FenixAccountSwitchContextItem: ContextMenuCustomItem {
    let peerId: Int64      // used to load the account's real avatar cached on disk while it was live
    let displayName: String
    let username: String   // "@handle", "+phone", or "" — cached from fenixuz_account_usernames
    let action: (ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void) -> Void

    init(
        peerId: Int64,
        displayName: String,
        username: String,
        action: @escaping (ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void) -> Void
    ) {
        self.peerId = peerId
        self.displayName = displayName
        self.username = username
        self.action = action
    }

    func node(
        presentationData: PresentationData,
        getController: @escaping () -> ContextControllerProtocol?,
        actionSelected: @escaping (ContextMenuActionResult) -> Void
    ) -> ContextMenuCustomNode {
        return FenixAccountSwitchContextItemNode(
            presentationData: presentationData,
            item: self,
            getController: getController,
            actionSelected: actionSelected
        )
    }
}

// MARK: - Node

private final class FenixAccountSwitchContextItemNode: ASDisplayNode, ContextMenuCustomNode {
    private let item: FenixAccountSwitchContextItem
    private let presentationData: PresentationData
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void

    private let buttonNode: HighlightTrackingButtonNode
    // Initials circle rendered into a plain image layer (no AvatarNode dependency needed here)
    private let avatarNode: ASImageNode
    private let nameNode: ImmediateTextNode
    private let usernameNode: ImmediateTextNode

    init(
        presentationData: PresentationData,
        item: FenixAccountSwitchContextItem,
        getController: @escaping () -> ContextControllerProtocol?,
        actionSelected: @escaping (ContextMenuActionResult) -> Void
    ) {
        self.item = item
        self.presentationData = presentationData
        self.getController = getController
        self.actionSelected = actionSelected

        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.isAccessibilityElement = true
        self.buttonNode.accessibilityLabel = item.displayName

        self.avatarNode = ASImageNode()
        self.avatarNode.isLayerBacked = true
        self.avatarNode.displayWithoutProcessing = true
        self.avatarNode.displaysAsynchronously = false
        self.avatarNode.contentMode = .scaleAspectFill
        // Prefer the account's real photo (cached to disk while the account was live); fall back to a
        // colored initials circle when no photo is cached yet (or the account has no avatar set).
        self.avatarNode.image = fenixContextCachedAccountAvatar(peerId: item.peerId)
            ?? fenixContextInitialsAvatar(name: item.displayName, size: CGSize(width: 30, height: 30))

        let nameFont = Font.semibold(presentationData.listsFontSize.baseDisplaySize * 15.0 / 17.0)
        self.nameNode = ImmediateTextNode()
        self.nameNode.isAccessibilityElement = false
        self.nameNode.isUserInteractionEnabled = false
        self.nameNode.displaysAsynchronously = false
        self.nameNode.maximumNumberOfLines = 1
        self.nameNode.attributedText = NSAttributedString(
            string: item.displayName.isEmpty ? "Account" : item.displayName,
            font: nameFont,
            textColor: presentationData.theme.contextMenu.primaryColor
        )

        let usernameFont = Font.regular(presentationData.listsFontSize.baseDisplaySize * 12.0 / 17.0)
        self.usernameNode = ImmediateTextNode()
        self.usernameNode.isAccessibilityElement = false
        self.usernameNode.isUserInteractionEnabled = false
        self.usernameNode.displaysAsynchronously = false
        self.usernameNode.maximumNumberOfLines = 1
        self.usernameNode.attributedText = NSAttributedString(
            string: item.username,
            font: usernameFont,
            textColor: presentationData.theme.contextMenu.secondaryColor
        )

        super.init()

        self.addSubnode(self.avatarNode)
        self.addSubnode(self.nameNode)
        self.addSubnode(self.usernameNode)
        self.addSubnode(self.buttonNode)

        self.buttonNode.addTarget(self, action: #selector(buttonPressed), forControlEvents: .touchUpInside)

        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            guard let self else { return }
            if highlighted {
                self.avatarNode.alpha = 0.6
                self.nameNode.alpha = 0.6
                self.usernameNode.alpha = 0.6
            } else {
                let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
                transition.updateAlpha(node: self.avatarNode, alpha: 1.0)
                transition.updateAlpha(node: self.nameNode, alpha: 1.0)
                transition.updateAlpha(node: self.usernameNode, alpha: 1.0)
            }
        }
    }

    // MARK: ContextMenuCustomNode

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let leftInset: CGFloat = 16.0
        let avatarSize = CGSize(width: 30.0, height: 30.0)
        let avatarRightGap: CGFloat = 10.0
        let rightInset: CGFloat = 16.0
        let verticalPadding: CGFloat = 9.0
        let interLineGap: CGFloat = 2.0

        let textMaxWidth = constrainedWidth - leftInset - avatarSize.width - avatarRightGap - rightInset

        let nameSize = self.nameNode.updateLayout(CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude))
        let hasUsername = !self.item.username.isEmpty
        let usernameSize = hasUsername
            ? self.usernameNode.updateLayout(CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude))
            : CGSize.zero

        let textBlockHeight = hasUsername
            ? nameSize.height + interLineGap + usernameSize.height
            : nameSize.height
        let rowHeight = max(avatarSize.height, textBlockHeight) + verticalPadding * 2.0

        return (
            CGSize(width: constrainedWidth, height: rowHeight),
            { size, transition in
                let avatarX = leftInset
                let avatarY = floor((size.height - avatarSize.height) / 2.0)
                transition.updateFrame(
                    node: self.avatarNode,
                    frame: CGRect(origin: CGPoint(x: avatarX, y: avatarY), size: avatarSize)
                )

                let textX = leftInset + avatarSize.width + avatarRightGap
                let textBlockY = floor((size.height - textBlockHeight) / 2.0)

                transition.updateFrame(
                    node: self.nameNode,
                    frame: CGRect(origin: CGPoint(x: textX, y: textBlockY), size: nameSize)
                )

                if hasUsername {
                    self.usernameNode.isHidden = false
                    transition.updateFrame(
                        node: self.usernameNode,
                        frame: CGRect(
                            origin: CGPoint(x: textX, y: textBlockY + nameSize.height + interLineGap),
                            size: usernameSize
                        )
                    )
                } else {
                    self.usernameNode.isHidden = true
                }

                transition.updateFrame(
                    node: self.buttonNode,
                    frame: CGRect(origin: .zero, size: size)
                )
            }
        )
    }

    func updateTheme(presentationData: PresentationData) {
        if let attributed = self.nameNode.attributedText {
            let mutable = NSMutableAttributedString(attributedString: attributed)
            mutable.addAttribute(
                .foregroundColor,
                value: presentationData.theme.contextMenu.primaryColor,
                range: NSRange(location: 0, length: mutable.length)
            )
            self.nameNode.attributedText = mutable
        }
        if let attributed = self.usernameNode.attributedText {
            let mutable = NSMutableAttributedString(attributedString: attributed)
            mutable.addAttribute(
                .foregroundColor,
                value: presentationData.theme.contextMenu.secondaryColor,
                range: NSRange(location: 0, length: mutable.length)
            )
            self.usernameNode.attributedText = mutable
        }
    }

    func canBeHighlighted() -> Bool { return true }
    func updateIsHighlighted(isHighlighted: Bool) {}

    func performAction() {
        guard let controller = self.getController() else { return }
        self.item.action(controller) { [weak self] result in
            self?.actionSelected(result)
        }
    }

    @objc private func buttonPressed() {
        self.performAction()
    }
}

// MARK: - Initials avatar helpers (private, mirrors FenixAccountsController.swift)
// Kept private so they don't pollute the module namespace. The originals in
// FenixAccountsController are also private — copy is intentional (different size,
// different font) and avoids creating a shared Fenixuz utility module for two callers.

// Loads the account's real avatar that SharedAccountContext mirrored to disk while the account was
// live. Path formula is duplicated from fenixAccountAvatarCachePath (different module, same process,
// same Caches directory). Returns nil when nothing is cached yet so callers fall back to initials.
private func fenixContextCachedAccountAvatar(peerId: Int64) -> UIImage? {
    guard peerId != 0,
          let caches = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first else {
        return nil
    }
    let path = caches + "/fenixuz-account-avatars/\(peerId).png"
    guard FileManager.default.fileExists(atPath: path) else {
        return nil
    }
    return UIImage(contentsOfFile: path)
}

private func fenixContextInitialsAvatar(name: String, size: CGSize) -> UIImage? {
    let initials = fenixContextAvatarInitials(from: name)
    let color = fenixContextAvatarColor(for: name)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        ctx.cgContext.setFillColor(color.cgColor)
        ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        let fontSize = floor(size.width * 0.4)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let text = initials as NSString
        let textSize = text.size(withAttributes: attrs)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2.0,
            y: (size.height - textSize.height) / 2.0,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attrs)
    }
}

private func fenixContextAvatarInitials(from name: String) -> String {
    let parts = name.split(separator: " ").prefix(2)
    if parts.isEmpty { return "?" }
    return parts.compactMap { $0.first.map { String($0).uppercased() } }.joined()
}

private let fenixContextAvatarPalette: [UIColor] = [
    UIColor(red: 0.48, green: 0.63, blue: 0.91, alpha: 1),
    UIColor(red: 0.55, green: 0.80, blue: 0.59, alpha: 1),
    UIColor(red: 0.89, green: 0.52, blue: 0.50, alpha: 1),
    UIColor(red: 0.97, green: 0.69, blue: 0.39, alpha: 1),
    UIColor(red: 0.57, green: 0.74, blue: 0.82, alpha: 1),
    UIColor(red: 0.80, green: 0.59, blue: 0.80, alpha: 1),
    UIColor(red: 0.40, green: 0.73, blue: 0.64, alpha: 1)
]

private func fenixContextAvatarColor(for name: String) -> UIColor {
    let hash = abs(name.unicodeScalars.reduce(0) { $0 &+ Int(bitPattern: UInt(bitPattern: Int($1.value))) })
    return fenixContextAvatarPalette[hash % fenixContextAvatarPalette.count]
}
