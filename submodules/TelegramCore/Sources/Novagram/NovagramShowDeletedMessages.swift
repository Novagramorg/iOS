import Foundation
import Postbox

// Novagram "Deleted messages" (anti-delete) — single source of truth for the gate.
//
// The interesting part is WHERE this gets read. AccountStateManagementUtils runs in two
// processes: the main app, and the NotificationService extension (via standaloneStateManager /
// standalonePollDifference). `UserDefaults(suiteName: "pro_messager")` is a plain suite, not an
// App Group one, so it resolves to a *per-process* preferences container — the extension reading
// it always got `false`, took the vanilla delete path, and permanently erased the message from
// the shared Postbox before the app ever woke up. That is why the feature looked like it worked
// with the app open and silently did nothing with the app backgrounded.
//
// So: read the local suite first (authoritative in the main app, and the fast path), then fall
// back to the App Group suite, which the main app mirrors on every launch and on every toggle
// flip (see NovagramSharedDefaults in NovagramMessenger). Both bundle-id shapes are tried because
// the app is "uz.fenixuz.app" while the extension is "uz.fenixuz.app.NotificationService" —
// the App Group is named after the former in both processes.
@inline(__always)
internal var isNovagramShowDeletedMessagesEnabled: Bool {
    if UserDefaults(suiteName: "pro_messager")?.bool(forKey: "show_deleted_messages") == true {
        return true
    }
    guard let bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty else {
        return false
    }
    if UserDefaults(suiteName: "group.\(bundleId)")?.bool(forKey: "show_deleted_messages") == true {
        return true
    }
    if let lastDotRange = bundleId.range(of: ".", options: [.backwards]) {
        let baseBundleId = String(bundleId[..<lastDotRange.lowerBound])
        if UserDefaults(suiteName: "group.\(baseBundleId)")?.bool(forKey: "show_deleted_messages") == true {
            return true
        }
    }
    return false
}

// Second bypass path, found 2026-08-26 from a user video: HistoryViewStateValidation.
//
// While a chat is on screen, that subsystem re-asks the server for the messages in the visible
// range and deletes, locally, anything the server did not return — via a direct
// `_internal_deleteMessages` call that never goes through AccountStateManagementUtils. A message
// the peer just deleted is *by definition* absent from the server's answer, so validation undid
// our retention roughly two seconds after the 🗑 marker appeared. Use this from any site that
// deletes on the "server no longer has it" signal, so an already-retained message is left alone.
@inline(__always)
internal func isNovagramRetainedDeletedMessage(transaction: Transaction, id: MessageId) -> Bool {
    guard isNovagramShowDeletedMessagesEnabled else {
        return false
    }
    guard let message = transaction.getMessage(id) else {
        return false
    }
    return message.attributes.contains(where: { $0 is DeletedMessageAttribute })
}

// Novagram: "show deleted messages" in the update replay (HOOKS.md, "Show deleted messages"). Upstream split the old
// replayFinalState into ReplayContext's apply* functions (State/Sync, 13.2); their first line calls these. A message
// we still have gets a DeletedMessageAttribute and stays; only the rest is deleted. Returns false when the setting is
// off, and the caller then runs upstream's code.
extension ReplayContext {
    private func novagramMarkDeleted(_ message: Message) {
        var newAttributes = message.attributes.filter { !($0 is DeletedMessageAttribute) }
        newAttributes.append(DeletedMessageAttribute(timestamp: Int32(Date().timeIntervalSince1970)))
        let storeForwardInfo = message.forwardInfo.flatMap(StoreMessageForwardInfo.init)
        self.transaction.updateMessage(message.id, update: { _ in
            return .update(StoreMessage(id: message.id, customStableId: nil, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: StoreMessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: storeForwardInfo, authorId: message.author?.id, text: message.text, attributes: newAttributes, media: message.media))
        })
    }

    func novagramApplyDeleteMessagesWithGlobalIds(_ ids: [Int32]) -> Bool {
        guard isNovagramShowDeletedMessagesEnabled else {
            return false
        }
        var retainedMessageIds: Set<MessageId> = []
        for messageId in self.transaction.messageIdsForGlobalIds(ids) {
            if let message = self.transaction.getMessage(messageId) {
                if !message.attributes.contains(where: { $0 is DeletedMessageAttribute }) {
                    self.novagramMarkDeleted(message)
                }
                retainedMessageIds.insert(messageId)
            }
        }
        let actuallyDeletedGlobalIds = ids.filter { globalId in
            !self.transaction.messageIdsForGlobalIds([globalId]).contains(where: { retainedMessageIds.contains($0) })
        }
        var resourceIds: [MediaResourceId] = []
        self.transaction.deleteMessagesWithGlobalIds(actuallyDeletedGlobalIds, forEachMedia: { media in
            addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
        })
        if !resourceIds.isEmpty {
            let _ = self.mediaBox.removeCachedResources(Array(Set(resourceIds)), force: true).start()
        }
        self.deletedMessageIds.append(contentsOf: actuallyDeletedGlobalIds.map { .global($0) })
        self.deletedMessageIds.append(contentsOf: retainedMessageIds.map { .messageId($0) })
        return true
    }

    func novagramApplyDeleteMessages(_ ids: [MessageId]) -> Bool {
        guard isNovagramShowDeletedMessagesEnabled else {
            return false
        }
        var actuallyDeletedIds: [MessageId] = []
        var retainedMessageIds: Set<MessageId> = []
        for id in ids {
            if let message = self.transaction.getMessage(id) {
                if !message.attributes.contains(where: { $0 is DeletedMessageAttribute }) {
                    self.novagramMarkDeleted(message)
                }
                retainedMessageIds.insert(id)
            } else {
                actuallyDeletedIds.append(id)
            }
        }
        if !actuallyDeletedIds.isEmpty {
            _internal_deleteMessages(transaction: self.transaction, mediaBox: self.mediaBox, ids: actuallyDeletedIds, manualAddMessageThreadStatsDifference: { id, _, remove in
                self.addMessageThreadStatsDifference(threadKey: id, remove: remove, addedMessagePeer: nil, addedMessageId: nil, isOutgoing: false)
            })
        }
        self.deletedMessageIds.append(contentsOf: actuallyDeletedIds.map { .messageId($0) })
        self.deletedMessageIds.append(contentsOf: retainedMessageIds.map { .messageId($0) })
        return true
    }
}
