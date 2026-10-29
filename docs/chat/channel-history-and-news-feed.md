# Channel history fill and the News feed

> Moved verbatim from the root `CLAUDE.md` on 2026-10-29, which had passed the 150k-character limit. The root file keeps a short summary under the same heading. "Above", "below" and section names refer to the root `CLAUDE.md` unless the section is in this file.

## Opening a channel at a post (history fill and the poll gate)

Measured 2026-10-13:
the Postbox `MessageHistoryView` issues no request; the round trips before a chat shows messages all
come from TelegramCore around it. Four facts keep the critical path at one `messages.getHistory`:

- **A history fill stores before it resolves.** `fetchMessageHistoryHole` stores the messages and
  closes the hole in its first transaction; reply targets, custom emoji files and stories follow, and
  the follow-up re-adds the messages whose reply targets arrived so a view (which watches its own
  chat only) re-renders them. Forums and monoforums keep thread resolution before storage.
- **The around fill learns the top from the server.** `offset_id_offset` is the 1-based position of
  the anchor from the newest message and the server does not fill downward, so the hole closes to the
  top exactly when the newer ids returned number one less than it (`aroundHoleFillRange`, tested in
  `AroundHoleFillRangeTests`). `inexact` vetoes it; the bottom is never inferred.
- **Plain channels request no forum topics.** Every channel post is stored with `threadId = 1`;
  `resolveForumThreads` skips peers that are neither forum nor monoforum (`peerCanHaveForumThreads`).
- **An unjoined channel's view does not wait for the poll.** `wrappedMessageHistorySignal` still
  resets the read state and adds the full hole first, and `keepPollingChannel` still runs (with its
  1.0 s start delay), but the Postbox view is created at once. The profile warmup
  (`keepPeerInfoScreenDataHot`, eight tag views) starts after the first loaded history view.
  The full hole is added once per unpolled period (a flag on the channel's polling context), and a
  fill that closes the hole to the top advances the channel state's `synchronizedUntilMessageId`, so
  the chat's re-subscription after a fill does not wipe it and the poll does not seed a gap hole over it.

## News feed: parked at layer 232 (`TELEGRAM_NEWS_FEED_API`)

Since 2026-10-16 the news feed is parked server-side and the app talks layer 232, whose schema has no feed API:
no `feed.*` types or methods, no `updateReadFeed`, no `channels.editChannelNews`, `channels.joinChannel` without
`for_news`, and a `channel` constructor without `in_news`. That constructor keeps `pinned_msg_id` and is still
`#7ad15240`: a TL constructor id ignores `?true` fields. All News code stays in the app, so the feature comes back
by defining one compile-time condition, not by restoring code. None of this shows up as a build error:

- **`TELEGRAM_NEWS_FEED_API` is defined nowhere.** TelegramCore wraps only the lines that use a removed API symbol,
  or read the removed `in_news` bit, in `#if TELEGRAM_NEWS_FEED_API`. Each `#else` sends nothing and answers with an
  empty success (an empty For you batch, an empty Added page, a read mark kept local, interests left unchanged), so
  no context retries. The feed models, contexts, page storage, grouping, caches and read state stay compiled. Code
  inside an inactive `#if` is not type-checked, which is why the blocks are kept that small.
- **One gate hides News.** TelegramCore exports `newsFeedApiIsAvailable` (Swift defines are per module, so the app
  cannot test the condition itself), and `isNewsFeedEnabled(appConfiguration:apiIsAvailable:)` in `NewsFeedSupport`
  returns false while it is false, before the `dev` flag and the `news_feed_enabled` kill switch. Every News surface
  outside the News modules reads that gate: the tab (`ApplicationContext` → `TelegramRootController`), the channel
  bar (Join or Mute/Unmute instead of the island, also for a channel a 233 build stored with `in_news`) and the
  title's mute badge. `NewsScreen` is still created, like the hidden Calls tab, but never loads, so no feed context
  starts. There is no `#if` on the app side: a new News entry point must go through the gate.
- **A raw bit read compiles silently.** The parse of a channel's `flags2` bit 21 is a bit test, not an accessor, so
  nothing would have caught it; `ParkedNewsFeedApiTests` pins that the parked build ignores it.
- **Stays on:** the pinned-message skeleton (fed by the constructor's `pinned_msg_id` and by `channelFull`'s), no
  read state for unjoined channels (below), and the history-open request chain (above).

To bring the feed back:

1. restore its entries in `swift_scheme.tl`, with `in_news`, `for_news` and `editChannelNews` as the server has them;
2. define the condition for **both** TelegramCore and its tests: `"-DTELEGRAM_NEWS_FEED_API"` in the `copts` of
   `TelegramCore` and `TelegramCoreTestsLib` in `submodules/TelegramCore/BUILD`, and
   `.define("TELEGRAM_NEWS_FEED_API")` in the `swiftSettings` of both the `TelegramCore` and `TelegramCoreTests`
   targets in its `Package.swift`. The tests are their own module. Without the define there, the parked tests
   (`FeedApiConversionTests`, the `in_news` cases of `ChannelInNewsFlagTests` and `ChannelInNewsLocalChangeTests`)
   stay compiled out, `ParkedNewsFeedApiTests` skips itself, and bit 21 is tested by nothing;
3. set `Serialization.currentLayer()` to the server's layer;
4. run `submodules/TelegramApi/generate-swiftpm.sh`.

## Opening a post from the News feed: the cached post first

Reachable only while the feed is on (see "News feed: parked at layer 232" above).
The feed stores every post it shows into the channel's history (inside the hole). Opening a post
from the feed passes `cachedAnchor: true` in `ChatControllerSubject.message`, which the history
view turns into `includeAnchorWhileLoading`: a Postbox view opened around a message that is stored
but still inside a hole then carries that message and its album as entries while it reports
`isLoading` (`MessageHistoryView.isAnchorOnlyWhileLoading`, `PostboxTests`
`MessageHistoryViewAnchorWhileLoadingTests`). Views without the flag keep no entries while loading.
The chat applies the partial view scrolled with the post at the bottom (top edge at the top when
taller). Both measure the post without its date header's space
(`ChatMessageItemView.attachedDateHeaderInset`, `ListViewScrollToItem.excludesAttachedHeaderSpace`):
alone in the view the post carries its day's header, which moves to an older post of the same day once
those load, and a tall post held by its top edge moved with it. The chat also reports the partial
view as loading earlier so the existing placeholder stacks its skeleton bubbles above it, and applies
the loaded view in place (`ChatHistoryViewScrollPosition.pinnedAnchor` /
`.keepInPlace`, resolved in the history node from the post's relative offset). The partial view
reports the history as still loading (`historyState`), so the profile warmup and the pinned-message
view start after the fill as for any other open, and it makes no read claim (`maxReadIndex` is nil,
so no unread separator lands above the post). While the post is pinned and its surroundings have not
loaded, the view reports no hole-fill restart, so a hole operation on the channel (the poll's, or any
other) cannot restart the history around a post that is still inside the hole.

**A channel the account is not a member of has no read state** (For You channels, and channels added only
to News, which stay `.left`): the server keeps none, so the client keeps none either
(`TelegramCore/Sources/State/NonMemberChannelReadState.swift`). Opening one installs a fixed state with
nothing unread and nothing counted (`maxKnownId: Int32.max - 1`), interactive reads do nothing, the
server's read-state operations for it are skipped in replay, and the synchronizer confirms anything queued
for it without sending; dialogs fetched for chat folders store no read state for it either. The state's
`maxIncomingReadId` is 0 on purpose: replaying `.ResetReadState` and validation both keep a local mark that
is ahead of the server's while it reports unread (`localReadMarkIsAheadOfServer`), so a higher one would block
the state a join brings in, which can itself be 0. **A join does
not reliably fetch the dialog:** `initialStateWithPeerIds` judges the stored, still non-member channel and
builds its chat info from stored notification settings, which opening the chat has fetched, so
`resolveMissingPeerChatInfos` asks for nothing. A stored channel that becomes a member therefore queues a
read-state validation itself (`channelJoinNeedsServerReadState` in `updatePeersCustom`). Monoforums (a
user's direct messages with a channel) keep their read state whatever the participation status. A chat
opened from News also shows no unread badge on its back button
(`NavigateToChatControllerParams.showsUnreadChatsBackBadge`).
