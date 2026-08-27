import Foundation
import Postbox

// Fenixuz "Deleted messages" (anti-delete) — single source of truth for the gate.
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
// flip (see FenixSharedDefaults in FenixuzProMessager). Both bundle-id shapes are tried because
// the app is "uz.fenixuz.app" while the extension is "uz.fenixuz.app.NotificationService" —
// the App Group is named after the former in both processes.
@inline(__always)
internal var isFenixuzShowDeletedMessagesEnabled: Bool {
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
internal func isFenixuzRetainedDeletedMessage(transaction: Transaction, id: MessageId) -> Bool {
    guard isFenixuzShowDeletedMessagesEnabled else {
        return false
    }
    guard let message = transaction.getMessage(id) else {
        return false
    }
    return message.attributes.contains(where: { $0 is DeletedMessageAttribute })
}
