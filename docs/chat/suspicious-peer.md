# A non-contact's chat before it is accepted

> Moved verbatim from the root `CLAUDE.md` on 2026-10-29, which had passed the 150k-character limit. The root file keeps a short summary under the same heading. "Above", "below" and section names refer to the root `CLAUDE.md` unless the section is in this file.

## A non-contact's chat before it is accepted (suspicious peer)

While a user's chat shows the report/block panel (`PeerStatusSettings` `canReport`/`canBlock`; the one
predicate is `CachedUserData.isSuspiciousPeer`), their incoming messages are untrusted until the panel is
dismissed or the account sends them a message:

- Links, mentions, hashtags and cashtags, emails, bank cards and TON addresses show as plain text
  (`MessageTextEntity.isShownFromSuspiciousPeer`, also in a link preview's text; `instantPageForSuspiciousSender`
  for rich messages). A link preview opens nothing and has no button.
- Buttons are not shown: reply-markup rows, rich inline pills and button rows. A link-styled rich button keeps
  its label as plain text.
- Their emoji status is hidden in the chat title, in the panel's "is a mark for Premium" note and in the
  profile header, including the cover and colours of a collectible status.
- Nothing is marked read (`ChatHistoryListNode.holdsReadsForSender`). Reads also wait while a non-contact's
  settings are still unknown, as on the first open of a chat they started: a read cannot be taken back.

Non-obvious:

- **Sending clears the flags locally.** `enqueueMessages(transaction:)` drops `canReport`/`canBlock` for a
  non-scheduled send; Add Contact stays. `users.getFullUser` rewrites the settings on every refresh, so if the
  server keeps those flags after a reply, the state returns on the next refresh. Unverified as of 2026-10-21
  (no second account to test with); the fallback is `hidePeerSettingsBar` on send, which also drops Add Contact.
- **The rich transform keeps every block's index.** A button row stays with no buttons, which lays out to
  nothing and adds no spacing. Block paths are rich-quote node ids, and quotes are built from the stored page.
  Removing an inline pill drops its label from its node's text, so such a message cannot be partially quoted
  while the state lasts.
- Private chats only. Chat list rows, search, and groups or channels with a report panel are unchanged.
