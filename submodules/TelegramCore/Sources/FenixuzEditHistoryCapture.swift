import Foundation
import Postbox

// Fenixuz: capture the pre-edit version of a message into EditedMessageHistoryAttribute so the
// edited-history viewer ("History" context-menu item) can show it.
//
// This is called from BOTH edit code paths:
//   1. the live state-manager path (AccountStateManagementUtils `.EditMessage`) — records edits the
//      client observes for a message it already holds (typically other people's edits), and
//   2. the local request-edit result path (RequestEditMessage) — records the user's OWN edits.
//
// Why (2) is needed: a user's own FIRST edit used to be lost. RequestEditMessage overwrites the
// message with the server copy (which carries none of this local attribute) and only afterwards
// feeds the same updates to the state manager — by then the stored text already equals the server
// text, so the `.EditMessage` path sees no change and captures nothing. The history therefore only
// began accumulating from the SECOND edit onward. Capturing here, where `previousMessage` still
// holds the pre-edit text, fixes the first edit.
//
// The helper is idempotent across the two paths: once the first path has stored the pre-edit
// version, the second path sees no text/media change and simply carries the existing history
// forward instead of dropping it or duplicating an entry.
func fenixuzAppendEditHistory(previousMessage: Message, newText: String, newMedia: [Media], into attributes: inout [MessageAttribute]) {
    // Webpage previews are excluded from the media comparison because preview loading/updating is
    // also delivered as an edit and is not a user edit.
    let previousMedia = previousMessage.media.filter { !($0 is TelegramMediaWebpage) }
    let updatedMedia = newMedia.filter { !($0 is TelegramMediaWebpage) }
    let mediaChanged = previousMedia.map { $0.id } != updatedMedia.map { $0.id }
    let textChanged = previousMessage.text != newText

    let existingHistory = (previousMessage.attributes.first(where: { $0 is EditedMessageHistoryAttribute }) as? EditedMessageHistoryAttribute)?.history ?? []

    if textChanged || mediaChanged {
        let previousEntities = previousMessage.textEntitiesAttribute?.entities ?? []
        let previousVersionTimestamp = (previousMessage.attributes.first(where: { $0 is EditedMessageAttribute }) as? EditedMessageAttribute)?.date ?? previousMessage.timestamp
        let entry = EditedMessageHistoryEntry(
            timestamp: previousVersionTimestamp,
            text: previousMessage.text,
            entities: previousEntities,
            media: previousMedia
        )
        var updatedHistory = existingHistory
        updatedHistory.append(entry)
        attributes.removeAll(where: { $0 is EditedMessageHistoryAttribute })
        attributes.append(EditedMessageHistoryAttribute(history: updatedHistory))
    } else if !existingHistory.isEmpty {
        // Nothing new to record, but keep an already-captured history instead of letting the
        // server copy's attribute set silently drop it.
        attributes.removeAll(where: { $0 is EditedMessageHistoryAttribute })
        attributes.append(EditedMessageHistoryAttribute(history: existingHistory))
    }
}
