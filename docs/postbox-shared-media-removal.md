# Postbox shared-media removal

> Moved verbatim from the root `CLAUDE.md` on 2026-10-29, which had passed the 150k-character limit. The root file keeps a short summary under the same heading. "Above", "below" and section names refer to the root `CLAUDE.md` unless the section is in this file.

## Postbox shared-media removal (deferred design: tombstones)

`Transaction.updateMedia(id, update: nil)` is meant to remove a media from every message that
carries it. Today it is used for one thing: the server answers a web-page update with `webPageEmpty`
(no preview exists for that URL) and `AccountStateManagementUtils` turns it into a nil media update
(replayed through `updateMessageMedia(transaction:id:media:)`). The intended end state matches a
fresh store of such a message, which yields no web-page media at all.

It works only for media **embedded** in a single message (the message is rewritten and an
`.UpdateEmbeddedMedia` operation is emitted). For a **shared record** — two or more messages carry
the same media id, which is exactly what pasting or forwarding the same link produces, since web-page
ids are stable per URL — `MessageHistoryTable.updateMedia` merely decrements the record's reference
count and stops: the record stays, every message keeps the preview, and the update is not even
reported to views because `updatedMedia[id] = nil` on a `[MediaId: Media?]` **deletes the key**
instead of storing `.some(nil)`. Each further empty update decrements again, so the record is freed
while messages still reference it (an undercount; 3.1 in the 2026-09-18 audit was the matching leak).

The root cause is that the media table knows only a *count* for a shared record, not which messages
reference it; the only reverse lookup is `enumerateMediaMessages`, a history scan.

**Decided 2026-09-18, deferred:** implement removal of a shared record as a **tombstone** — rewrite
the `Direct` record into a flagged row whose `get` returns no media, leave the reference count
untouched, and record the removal with `updatedMedia.updateValue(nil, forKey: id)` so live views drop
it (the history view's `updateMedia` already handles `.some(nil)`). Every render then omits the
media, the count stays honest so the row is deleted on the final dereference as today, and a later
real update for the same id revives it for every referencing message at once. Do **not** delete the
row immediately: the stale ids left in the messages' reference arrays would corrupt the count of the
record when the same id reappears (old messages would resolve a new message's embedded copy, and
their later removal would decrement a count they never contributed to). The fully correct
alternative is a reverse index (media id → message indices) maintained beside the reference arrays,
which also lets the per-message tag recomputation in `updateMessageMedia` run; it needs a version
bump and a rebuild from the scan, so it is the eventual replacement only if a tag turns out to
derive from the web-page media rather than the URL entity. Tests belong in
`submodules/Postbox/Tests/` on `PostboxFixture` (two messages sharing one media, then an empty update).
