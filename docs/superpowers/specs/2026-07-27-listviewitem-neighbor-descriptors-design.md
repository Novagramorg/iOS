# `ListViewItem` neighbor descriptors

Replace `previousItem: ListViewItem?` / `nextItem: ListViewItem?` throughout the list system with a
small `Equatable` descriptor that each item publishes about itself, so that "did my neighbor change"
becomes a decidable question.

**Status:** design approved 2026-07-27; not yet implemented.

## Motivation

`CoreListChatHistoryBackend` (`submodules/TelegramUI/Sources/CoreListChatHistoryBackend.swift`)
currently calls `nodeConfiguredForParams`/`updateNode` with `previousItem: nil, nextItem: nil`. Every
message therefore renders unmerged and every row draws its own date header. Implementing neighbor
awareness there needs two things the current API cannot give:

1. Enough information about a neighbor to reproduce the merge/date decisions.
2. A cheap way to tell whether that information changed, so a row is re-laid-out exactly when it
   must be.

`previousItem: ListViewItem?` fails the second outright: it hands an item an escape hatch into the
whole mutable surface of its neighbor, so nothing downstream can bound what a "neighbor change" is.
`ListViewImpl` copes by relaying out the neighbors of every insert and delete unconditionally — and
by never relaying out the neighbor of a merely *updated* item, which is a latent bug (an edit that
changes `mediaMergeableStyle` leaves the bubble above it with stale corners).

The fix is to invert the direction: an item **publishes** a descriptor of itself, and neighbors
consume only that.

## Architecture

### Display layer

Three additions, one deletion.

```swift
// submodules/Display/Source/AnyEquatable.swift — new
public struct AnyEquatable: Equatable {
    private let value: Any
    private let isEqualTo: (Any) -> Bool

    public init<T: Equatable>(_ value: T) {
        self.value = value
        self.isEqualTo = { ($0 as? T) == value }
    }

    public static func == (lhs: AnyEquatable, rhs: AnyEquatable) -> Bool {
        return lhs.isEqualTo(rhs.value)
    }

    /// Also accepts a protocol (facet) type; `as?` to an existential is well-defined here.
    public func base<T>(_ type: T.Type) -> T? {
        return self.value as? T
    }

    /// Payload for items nothing reads. One shared constant, so it is equal to itself.
    public static let noNeighborInfluence = AnyEquatable(NoNeighborInfluence())
}

private struct NoNeighborInfluence: Equatable {}
```

Hashing is deliberately not required: no consumer hashes a descriptor, and `Equatable` is a strictly
weaker constraint on payloads than `Hashable`.

```swift
// submodules/Display/Source/ListViewItem.swift
public struct ListViewItemNeighbors: Equatable {
    public var previous: AnyEquatable?   // nil means *no neighbor on that side*
    public var next: AnyEquatable?
    public static let none = ListViewItemNeighbors(previous: nil, next: nil)
}

public protocol ListViewItem: AnyObject {
    /// Everything a *neighbor* is permitted to know about this item.
    ///
    /// Load-bearing: a descriptor must encode everything a neighbor reads. A backend relayouts a
    /// row exactly when this value changes on either side, so a fact omitted here goes stale.
    /// No default implementation — every conformer states its answer explicitly.
    var neighborDescriptor: AnyEquatable { get }

    func nodeConfiguredForParams(async:, params:, synchronousLoads:, neighbors: ListViewItemNeighbors, completion:)
    func updateNode(async:, node:, params:, neighbors: ListViewItemNeighbors, animation:, completion:)
}
```

`previousItem:`/`nextItem:` are removed from both methods and from
`ListViewItemNode.layoutForParams(_:item:previousItem:nextItem:)`.

**`neighborDescriptor` has no default implementation, by decision.** A default of
`.opaque(ObjectIdentifier(self))` would compile everywhere without thought, but combined with the
precise invalidation below, any item that forgot to publish a descriptor would force its neighbor to
relayout on every transaction where items are recreated — which is *worse* than today's policy for
update-heavy lists such as settings screens, which rebuild their whole item array on each state
change. A required member turns that silent perf cliff into a compile error.
`AnyEquatable.noNeighborInfluence` keeps the answer a one-liner for items nothing reads.

### Facets

Two neighbor idioms dominate the codebase, and some items need both — `ContactsPeerItem` reads
`previousItem as? ItemListItem` *and* `previousItem as? ListViewItemWithHeader`. A single payload
type per item cannot serve two independent consumers unless payloads are queried by capability, so
descriptors are queried through **facet protocols**:

```swift
// ItemListUI
public protocol ItemListNeighborFacet {
    var sectionId: ItemListSectionId { get }
    var isAlwaysPlain: Bool { get }
    var requestsNoInset: Bool { get }
    var isTextItem: Bool { get }               // itemListNeighbors' `topItem is ItemListTextItem` branch
    var hasActiveRevealOptions: Bool { get }   // from ItemListRevealOptionsStatefulItem
}

// Display
public protocol HeaderNeighborFacet {
    var headerId: ListViewItemNode.HeaderId? { get }
}
```

Consumers become:

```swift
if let previous = neighbors.previous?.base(ItemListNeighborFacet.self),
   previous.sectionId == self.sectionId, !previous.isAlwaysPlain { ... }
```

A payload conforms to as many facets as it needs; `noNeighborInfluence` conforms to none. Modules
define their own facets without touching `Display`.

**Nil versus facet-less is a real distinction and must be preserved.** `ContactsPeerItem` treats "a
previous item exists but has no header" (`firstWithHeader = true`) differently from "there is no
previous item" (`first = true`). `neighbors.previous == nil` means *no neighbor*; non-nil but
facet-less means *a neighbor that publishes nothing*. This is why `neighborDescriptor` is
non-optional and why every item publishes something.

### Chat layer

Lives in `ChatMessageItemCommon` (deps: `Display`, `TelegramCore`, `Emoji`) — see
[Verification](#verification) for why that module and not `ChatMessageItem`. `ChatMessageMerge` moves
down from `ChatMessageItem` into `ChatMessageItemCommon` (a dependency-free `Int32` enum);
`ChatMessageHeaderSpec` stays where it is, since only the `ChatMessageItem` protocol returns it.

```swift
public enum ChatHistoryItemNeighbor: Equatable {
    case message(dateHeaderId: ListViewItemNode.HeaderId,
                 topicHeaderId: ListViewItemNode.HeaderId?,
                 merge: ChatMessageMergeFingerprint)
    case unread(dateHeaderId: ListViewItemNode.HeaderId)
    case replyCount(dateHeaderId: ListViewItemNode.HeaderId)

    public var dateHeaderId: ListViewItemNode.HeaderId { ... }
}

public struct ChatHistoryItemNeighbors: Equatable {
    public var previous: ChatHistoryItemNeighbor?
    public var next: ChatHistoryItemNeighbor?

    public init(_ neighbors: ListViewItemNeighbors) {
        self.previous = neighbors.previous?.base(ChatHistoryItemNeighbor.self)
        self.next = neighbors.next?.base(ChatHistoryItemNeighbor.self)
    }
}
```

There is deliberately **no `.other` case**. Every branch was checked: a neighbor that is not one of
those three types and *no neighbor at all* produce identical results in both consumers
(`mergedWithItems`' trailing `else` sets `hasDate = true`; `chatItemsHaveCommonDateHeader` returns
`false` when either header is nil). So `ChatBotInfoItem`, `ChatUserInfoItem` and
`ChatNewThreadInfoItem` publish `noNeighborInfluence`, which decodes to `nil` — correct, and being
one shared constant, swapping one info item for another correctly triggers no neighbor relayout.

The two consumers change signature:

```swift
// ChatMessageItem protocol — replaces mergedWithItems(top:bottom:isRotated:)
func merged(with neighbors: ChatHistoryItemNeighbors, isRotated: Bool)
    -> (top: ChatMessageMerge, bottom: ChatMessageMerge, dateAtBottom: ChatMessageHeaderSpec)

// replaces chatItemsHaveCommonDateHeader(_ lhs: ListViewItem, _ rhs: ListViewItem?)
func chatItemsHaveCommonDateHeader(_ dateHeaderId: ListViewItemNode.HeaderId,
                                   _ neighbor: ChatHistoryItemNeighbor?) -> Bool
```

The second is exactly equivalent to the original: the original's `lhs` is always `self` (a
`ChatUnreadItem` or `ChatReplyCountItem`, both of which always have a header), and it returns `false`
whenever the right-hand header is absent.

`neighborDescriptor` is a **computed** property on the chat items, not stored. It is evaluated only
when an adjacent item is laid out or diffed, and computing it costs the same media/attribute walk
that `messagesShouldBeMerged` already performs per layout today — so this is net-neutral to cheaper,
with no init-time cost for the many items created per transition that never reach layout. If
profiling later shows otherwise, caching can be added then; it is not part of this design.

### The merge fingerprint

`messagesShouldBeMerged(accountPeerId:_:_:)` is a pairwise, **asymmetric** function over two
`Message` objects (a Postbox class, not `Equatable`). It must be factored into a per-message
projection plus a pure comparison of two projections.

Three places read only the *upper* message and apply the answer to both sides, so the naive "each
message resolves its own effective author" split is subtly wrong. The fingerprint therefore stores
raw **ingredients** rather than resolved values, and the pairwise function does the resolving.

```swift
public struct ChatMessageMergeFingerprint: Equatable {
    let peerId: EnginePeer.Id
    let rawAuthorId: EnginePeer.Id?          // message.author?.id
    let overriddenAuthorId: EnginePeer.Id?   // after SourceReferenceMessageAttribute + sourceAuthorInfo.originalAuthor
    let hasBroadcastProfiles: Bool           // peers[peerId] is .broadcast(messagesShouldHaveProfiles)
    let groupChannelId: EnginePeer.Id?       // peers[peerId] is a .group channel -> its id
    let isMonoforumChannel: Bool
    let authorSignature: String?             // authorSignatureAttribute?.signature, nil when empty
    let isEffectivelyIncoming: Bool          // effectivelyIncoming(accountPeerId)
    let isRepliesOrSavedMessages: Bool       // peerId.isRepliesOrSavedMessages(accountPeerId:)
    let sourceAuthorInfo: SourceAuthorInfoKey?   // (originalAuthor, originalAuthorName)
    let hasForwardInfo: Bool
    let forwardAuthorId: EnginePeer.Id?
    let forwardAuthorSignature: String?
    let importedForwardDate: Int32?          // forwardInfo.date when flags.contains(.isImported)
    let timestamp: Int32
    let hasPaidStars: Bool
    let mediaMergeStyle: Int32               // min over media of mediaMergeableStyle(_).rawValue
    let hasInlineReplyMarkup: Bool           // first ReplyMarkupMessageAttribute has .inline && !rows.isEmpty
}

func merge(upper: ChatMessageMergeFingerprint, lower: ChatMessageMergeFingerprint) -> ChatMessageMerge
```

The three traps, and how the ingredient-level split handles each:

- **`messagesShouldHaveProfiles`** resets *both* effective authors to `.author`, gated on the upper
  message's channel. Storing `rawAuthorId`, `overriddenAuthorId` and the flag lets the comparison
  apply `upper.hasBroadcastProfiles` to both sides, as the original does. Resolving per-message would
  diverge when the two messages carry different snapshots of the same peer.
- **`anonymousGroupAdminSignature(message:effectiveAuthor:)`** takes the *already-resolved* effective
  author as an argument, so it cannot be precomputed. Storing `groupChannelId` and `authorSignature`
  lets the comparison compute it after resolution: the signature applies only when the resolved
  effective author id equals `groupChannelId`. (A group channel can never carry
  `messagesShouldHaveProfiles`, which is broadcast-only — but the ingredient split does not rely on
  that.)
- **The imported-forward branch** replaces `sameAuthor` wholesale, discarding the anonymous-admin
  adjustment computed above it, and swaps both timestamps for forward dates — but only when *both*
  messages are imported forwards. `importedForwardDate` being non-nil on both sides is the gate; the
  recomputation then uses `forwardAuthorId`/`forwardAuthorSignature`.

Also note `finalEffectiveAuthorId`: the `isRepliesOrSavedMessages` swap happens *after* `sameAuthor`
is computed and affects only the later group-channel gate, which reads the upper message alone.
`isRepliesOrSavedMessages` + `hasForwardInfo` + `forwardAuthorId` reproduce it — including the case
where `forwardInfo` exists but its author is nil, which sets the effective author to nil.

## Migration

164 `ListViewItem` conformers. The diff is large; the thinking surface is not.

| Group | Count | Work |
|---|---|---|
| `ItemListItem` conformers | 110 | one extension on `ItemListItem` supplies `ItemListNeighborFacet`; zero per-item work |
| `ListViewItemWithHeader` conformers | 4 | payload also conforms to `HeaderNeighborFacet` |
| Bespoke sibling-type casts | 11 types | one small facet each |
| Chat items | 6 | `ChatHistoryItemNeighbor`, or `noNeighborInfluence` for the three info items |
| Everything else | ~35 | `noNeighborInfluence`, one line each |

The 11 bespoke types, each currently identified by a concrete-type cast on a neighbor:
`SettingsSearchRecentItem`, `ItemListVenueItem`, `ContactsPeerItem`, `ContactsAddItem`,
`ContactListActionItem`, `ChatListItem`, `CallListGroupCallItem`, `CallListCallItem`,
`ChatListAdditionalCategoryItem`, `BotCheckoutPriceItem`, `BotCheckoutHeaderItem`. These are where
the judgment lies — each needs a facet exposing the 2–4 facts its neighbor actually reads (e.g.
`ContactListActionItem` needs to know whether the item above is a `ContactsPeerItem` or another
`ContactListActionItem`; `BotCheckoutPriceItem` whether the item above is a `BotCheckoutHeaderItem`).

A protocol extension on a refining protocol (`ItemListItem: ListViewItem`) is a valid witness for a
`ListViewItem` requirement, which is what makes the 110-item group free. Concrete types that need
more (e.g. `ContactsPeerItem`, which needs both facets) declare the property themselves and shadow
the extension.

Mechanical sweep alongside: 164 × 2 method signatures; 41 `layoutForParams` overrides (only 3 call
sites, all item-internal — `CallListHoleItem`, `ChatListHoleItem`, `ChatReplyCountItem`); and ~70
external call sites, the majority of which are standalone preview renderers currently passing
`nil, nil` and becoming `.none`.

Deleting the parameters is what makes this safe: every dropped cast becomes a compile error rather
than a silent behavior change.

## `ListViewImpl` invalidation

`ListViewItemNode` gains `appliedNeighbors: ListViewItemNeighbors`, stored whenever a layout computed
with those neighbors is committed — `nodeForItem`'s create and update branches, plus `updateAdjacent`'s
inline `updateNode` call. `ListView` gains a `neighbors(at index: Int) -> ListViewItemNeighbors`
helper that replaces the ~6 inline `index == 0 ? nil : self.items[index - 1]` expressions.

In `deleteAndInsertItemsTransaction`:

```swift
var updateIndices = Set<Int>()
for case let .Node(index, _, referenceNode, _) in updatedState.nodes {
    guard let node = referenceNode?.syncWith({ $0 }) else { continue }
    if node.appliedNeighbors != self.neighbors(at: index) { updateIndices.insert(index) }
}
if widthUpdated { /* all node indices — unchanged */ }
updateIndices.subtract(explicitelyUpdateIndices)   // these relayout via updateNodes anyway
```

This deletes more than it adds: the two loops that build `updateAdjacentItemsIndices` from
`deleteIndexSet`/`insertedIndexSet` go away, and so does the `remappedUpdateAdjacentItemsIndices`
block — the diff runs after remapping, against final indices, so there is nothing to remap.

Behavior delta:

- Neighbors of inserts/deletes: relayout **iff** the descriptor pair changed (was: always). Strictly
  less work.
- Neighbors of updates: relayout iff the descriptor pair changed (was: **never**). This is the
  stale-merge bug fix.
- Explicitly-updated items and `widthUpdated`: unchanged.

This is the change with real risk to the primary scroll surface, and it rests entirely on the
descriptor-completeness invariant. Under the old policy an incomplete descriptor was masked by the
unconditional insert/delete sweep; now it goes stale. Removing `previousItem`/`nextItem` is the
structural mitigation.

Out of scope: `ListView`'s own adjacency reads for accessory items and header accessory items
(`previousItem?.accessoryItem`, `previousItem?.headerAccessoryItem`). `ListView` owns its item array
and may read it directly; only the *item-facing* API changes.

## CoreList wiring

`CoreListEntryItem` gains `neighbors: ListViewItemNeighbors`, computed by the backend from adjacent
entries when it builds the array. `isEqual(to:)` compares it alongside `stableId`/`stableVersion`, so
a row whose neighbors changed is unequal and re-applies. `apply(to:)` hands it to
`CoreListNodeHostView`, whose `rebuild(width:)` passes `neighbors:` in place of today's
`previousItem: nil, nextItem: nil`.

The backend already feeds items in `ListView` index order, so `neighbors(at:)` means the same thing
on both backends and the `isRotated` flip inside `merged(with:isRotated:)` is untouched. See
[`docs/chat/corelist-chat-history-backend.md`](../../chat/corelist-chat-history-backend.md) for the
identity-rotation invariant.

## Verification

1. **Differential unit test.** A new `ios_unit_test` on `ChatMessageItemCommon`. That module is the
   home for the fingerprint precisely because it is light (`Display`, `TelegramCore`, `Emoji`) —
   `ChatMessageItem` would drag in `AccountContext`. The oracle is the current
   `messagesShouldBeMerged` and its two private helpers (`mediaMergeableStyle`,
   `anonymousGroupAdminSignature`), copied **verbatim into the test file**, so production keeps one
   implementation and no reference copy rots in shipping code. `Message` has a public memberwise
   init, so pairs are constructible via a small builder.

   The matrix crosses the axes the traps live on: same/different peer; `SourceReferenceMessageAttribute`
   and `sourceAuthorInfo` overrides; broadcast-with-`messagesShouldHaveProfiles`; group channel with
   and without an anonymous admin signature; monoforum; paid stars on one vs both sides; imported
   forwards on one vs both sides; replies/saved-messages peers; timestamp deltas straddling 600s;
   each `mediaMergeableStyle` branch (sticker, instant round video, action, expired content, story
   mention, plain file, no media); and inline reply markup. Every pair is asserted in **both orders**,
   since the function is asymmetric.

   Run per CLAUDE.md with `Make.py test --target`, with the `ios_test_runner` pinned to a real
   device/OS (`iPhone 17` / `26.5`) — the default runner exits 15. Do not use the default
   `Tests/AllTests` suite, which references a dangling target.

2. **Full build** with `--continueOnError`, so the 164 conformers surface their errors in one pass
   rather than one at a time.

3. **Manual pass on the K1 sim** (`iPhone 17 Pro K1`) over each facet's surface: chat bubble merge
   corners, date headers and the unread bar; settings section insets including the
   `ItemListTextItem` reduced-inset case; contacts list headers (`first` / `last` /
   `firstWithHeader`); call list; bot checkout price rows. Then the chat pass again with the CoreList
   backend enabled, which should now merge bubbles and collapse date headers where the `ListViewImpl`
   backend does — today it does neither.

## Deliberately not in scope

- Caching of `neighborDescriptor`. Computed per access; revisit only under a profile.
- `ListView`'s accessory-item adjacency reads (see above).
- `GridNode`, which has its own item protocol and no neighbor concept.
