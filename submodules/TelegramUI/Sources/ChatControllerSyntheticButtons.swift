import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore

#if DEBUG

/// Debug fixture for the InstantPage button work.
///
/// The server does not emit `textButton` / `pageBlockButtonRow` yet, so there is no way to see the
/// Stage 2 rendering against real data. Sending this command in any chat inserts a **local incoming**
/// rich message that exercises every case: accent and regular pills, disabled pills, inline buttons
/// mid-sentence across two paragraphs, and a block-level button row.
///
/// Local-namespace incoming messages are the same mechanism service notifications use
/// (`AccountStateManagementUtils.swift:1273`), so the message is never sent anywhere and disappears
/// on logout. Aimed at 1:1 chats: `authorId` is the chat peer, which in a group would attribute the
/// message to the group itself.
let chatSyntheticButtonsCommand = "/synthetic_buttons"

private enum SyntheticButtonKind {
    case regular
    case accent
    case success
    case destructive
}

/// Enabled buttons get two different actions so a tap exercises two dispatch paths:
/// accent buttons open a URL, regular buttons copy their label.
private func syntheticButton(_ label: String, kind: SyntheticButtonKind, disabled: Bool = false) -> InstantPageButton {
    let action: ReplyMarkupButtonAction
    if disabled {
        action = .disabled
    } else if case .accent = kind {
        action = .url("https://telegram.org")
    } else {
        action = .copyText(payload: label)
    }
    let buttonColor: ReplyMarkupButton.Style.Color?
    switch kind {
    case .regular:
        buttonColor = nil
    case .accent:
        buttonColor = .primary
    case .success:
        buttonColor = .success
    case .destructive:
        buttonColor = .danger
    }
    return InstantPageButton(
        text: .plain(label),
        action: action,
        color: buttonColor
    )
}

private func syntheticButtonsInstantPage() -> InstantPage {
    // Paragraph 1 — three accent pills, the last one disabled.
    let firstParagraph = RichText.concat([
        .plain("Your daily "),
        .textButton(syntheticButton("challenge", kind: .accent)),
        .plain(" ready! Tap "),
        .textButton(syntheticButton("Play Now", kind: .accent)),
        .plain(" start. or "),
        .textButton(syntheticButton("Continue", kind: .accent, disabled: true)),
        .plain(" your last run once you finish today's round. We also support "),
        .textButton(syntheticButton("Very loooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooong button titles", kind: .accent, disabled: false)),
    ])

    // Paragraph 2 — two regular pills, the last one disabled. "anytimt" is reproduced verbatim from
    // the fixture template rather than silently corrected.
    let secondParagraph = RichText.concat([
        .plain("Need a break? You can "),
        .textButton(syntheticButton("View stats", kind: .regular)),
        .plain(" anytimt, or "),
        .textButton(syntheticButton("Claim reward", kind: .regular, disabled: true)),
        .plain(" after your first win. Also: "),
        .textButton(syntheticButton("add friend", kind: .success, disabled: false)),
        .textButton(syntheticButton("block", kind: .destructive, disabled: false)),
        .textButton(syntheticButton("profile", kind: .regular, disabled: false)),
    ])

    return InstantPage(
        blocks: [
            .paragraph(firstParagraph),
            .paragraph(secondParagraph),
            .buttonRow(buttons: [
                syntheticButton("Start", kind: .accent),
                syntheticButton("Skip", kind: .regular),
                syntheticButton("Share", kind: .regular, disabled: true)
            ])
        ],
        media: [:],
        isComplete: true,
        rtl: false,
        url: "",
        views: nil
    )
}

extension ChatControllerImpl {
    /// True when `messages` is exactly the synthetic-buttons command and nothing else.
    func isSyntheticButtonsCommand(_ messages: [EnqueueMessage]) -> Bool {
        // `.message` carries 10 associated values; bind only the two that matter.
        guard messages.count == 1,
              case let .message(text, _, _, mediaReference, _, _, _, _, _, _) = messages[0] else {
            return false
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines) == chatSyntheticButtonsCommand
            && mediaReference == nil
    }

    /// Inserts the fixture as a local incoming message. Nothing is sent to the server.
    func insertSyntheticButtonsMessage(peerId: PeerId, threadId: Int64?) {
        let page = syntheticButtonsInstantPage()
        // `text` is left empty below, so the message renders purely from its RichTextMessageAttribute.
        // The chat-list preview and notifications therefore show nothing for it — acceptable for a debug
        // fixture. To populate them, set `text:` to the blocks' joined `plainText` instead.

        let timestamp = Int32(Date().timeIntervalSince1970)
        let _ = (self.context.account.postbox.transaction { transaction -> Void in
            let _ = transaction.addMessages([
                StoreMessage(
                    peerId: peerId,
                    namespace: Namespaces.Message.Local,
                    customStableId: nil,
                    globallyUniqueId: nil,
                    groupingKey: nil,
                    threadId: threadId,
                    timestamp: timestamp,
                    flags: [.Incoming],
                    tags: [],
                    globalTags: [],
                    localTags: [],
                    forwardInfo: nil,
                    authorId: peerId,
                    text: "",
                    attributes: [RichTextMessageAttribute(instantPage: page, fullInstantPage: nil)],
                    media: []
                )
            ], location: .UpperHistoryBlock)
            let _ = transaction.addMessages([
                StoreMessage(
                    peerId: peerId,
                    namespace: Namespaces.Message.Local,
                    customStableId: nil,
                    globallyUniqueId: nil,
                    groupingKey: nil,
                    threadId: threadId,
                    timestamp: timestamp,
                    flags: [],
                    tags: [],
                    globalTags: [],
                    localTags: [],
                    forwardInfo: nil,
                    authorId: peerId,
                    text: "",
                    attributes: [RichTextMessageAttribute(instantPage: page, fullInstantPage: nil)],
                    media: []
                )
            ], location: .UpperHistoryBlock)
        }).startStandalone()
    }
}

#endif
