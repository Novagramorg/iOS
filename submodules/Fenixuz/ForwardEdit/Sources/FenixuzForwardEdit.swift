import Foundation
import UIKit
import Display
import Postbox
import TelegramCore
import AccountContext
import ContextUI

/// "Edit and Send" for a pending forward.
///
/// Forwarding without the sender's name still can't change the text, and editing afterwards
/// leaves an "edited" label. This option sends the post as a brand new message instead: the
/// same photos/videos/files (re-sent by their cloud ids, nothing is uploaded again) with the
/// text the user edited. It is the client-side equivalent of the Bot API `copyMessage`.
///
/// Hooked into the chat's forward-options menu (`ChatMessageActionOptions.swift`, see HOOKS.md);
/// everything else lives here.
public enum FenixuzForwardEdit {
    /// The menu item, or nil when the pending forward can't be sent as an edited copy.
    /// - Parameters:
    ///   - messages: the forwarded messages; one post or one album is supported.
    ///   - present: shows the editor screen.
    ///   - send: receives the ready messages; the caller sends them through the chat and clears
    ///     the pending forward.
    public static func menuItem(
        context: AccountContext,
        targetPeerId: EnginePeer.Id,
        threadId: Int64?,
        messages: [Message],
        present: @escaping (ViewController) -> Void,
        send: @escaping ([EnqueueMessage]) -> Void
    ) -> ContextMenuItem? {
        guard let source = FenixuzForwardEditSource(messages: messages, targetPeerId: targetPeerId) else {
            return nil
        }
        let strings = FenixuzForwardEditStrings(context.sharedContext.currentPresentationData.with { $0 }.strings)

        return .action(ContextMenuActionItem(text: strings.menuTitle, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor)
        }, action: { _, f in
            f(.default)
            present(FenixuzForwardEditScreen(context: context, source: source, threadId: threadId, send: send))
        }))
    }
}
