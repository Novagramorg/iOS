# Topic-header stacking on the CoreList chat-history backend

**Status:** design approved 2026-08-03, not implemented.

## Problem

Monoforum and thread separators do not render under the CoreList backend. `CoreListEntryItem`'s
attachment builder skips any header with a non-nil `stackingId`
(`CoreListChatHistoryBackend.swift`, the `attachedItems` loop), so a whole class of chat header is
simply absent.

The skip exists because those headers need a behavior CoreList has no notion of. In a monoforum two
header spaces coexist:

| | space | key | `stackingId` |
|---|---|---|---|
| date pill | 2 | rounded timestamp | nil |
| topic header | 3 | `separableThreadId`, timestamp zeroed | space 2, that day's key |

`ChatMessageDateHeader.init` (`ChatMessageDateHeader.swift:80-88`) builds both from the same type,
switching on `displayHeader`. The `stackingId` means "I coexist with the space-2 header for this day
and must not overlap it."

`ListViewImpl` resolves that in `updateItemHeaders` (`ListView.swift:4036-4086`), in the `.bottom`
stick branch only: z-order the topic header below, find the space-2 node it most overlaps, push its
`y` to `min(y, other.minY - 27)`, clamp to `upperBound`, repeat twice, then recompute the stick
distance against an adjusted natural bound.

**The gap is not the second space.** `attachedItems` is already a dictionary keyed per header id, so
an item can publish several attachments and CoreList forms an independent run per key. Dropping the
skip would render topic headers today. What is missing is that the constraint is *header-to-header*:
one attachment's position depends on another's solved position, and CoreList solves each run
independently.

## The constraint that dominates the design

`composedKeyframe` **samples** `y(atOffset:)` along the scroll trajectory
(`AttachmentSolve.swift:103`) and `installAttachmentFlightTracks` installs the result as an additive
`CAKeyframeAnimation` on `position.y`. During momentum the attachment is carried by the render
server, and nothing there can consult another attachment.

So a post-solve fix-up over view frames — the obvious implementation — would be **absent from the
baked track**. The topic header would ride un-nudged for the whole deceleration and snap into place
when the flight ended.

The nudge must therefore live *inside* the solve function. It can, because the partner's position is
`AttachmentOffsetMap.y(atOffset:)`, also pure, and `composedKeyframe` samples rather than solving
analytically — so a piecewise, conditional function bakes exactly as well as a linear one.

## Design

### 1. CoreList API — yield groups

Two defaulted members on `CoreListAttachedItem`:

```swift
/// The group this attachment belongs to for stacking purposes. Default nil — participates in none.
var stackingGroup: AnyHashable? { get }

/// The group this attachment defers to, and the minimum gap it keeps from any member of it.
/// Default nil — yields to nothing.
var stackingYield: (group: AnyHashable, gap: CGFloat)? { get }
```

An attachment tags itself into a group; a yielding attachment names the group it defers to. This is
deliberately a tag rather than a type: the same shape as `ListViewItemHeaderFamily` on
`HeaderNeighborFacet`, and for the same reason — the engine must not learn what a date pill is.

### 2. The solve

`AttachmentOffsetMap` gains the partner maps and the gap. `y(atOffset:)` composes:

```
own    = ownY(offset)
result = own
repeat until stable (bounded by partner count):
    for p in partners where p's rect at `offset` overlaps `result`'s rect:
        result = min(result, p.y(atOffset: offset) - gap)
    result = max(bandTop, result)
```

Three properties, each load-bearing:

- **It bakes.** `composedKeyframe` samples this, so the flight track carries the nudge with no new
  animation code and no second derivation.
- **It is deterministic.** Taking the min over *all* overlapping partners needs no tie-break.
  `ListViewImpl`'s pick is order-dependent — its selector compares `headerFrame.minY`, invariant
  across the loop, against the incumbent, never against the `intersectionHeight` it computes, and it
  iterates a `Dictionary`. We implement the evident intent instead. **`ListViewImpl` is not
  changed**; the divergence is confined to inputs where its own result is arbitrary.
- **The overlap test is required.** Without it a partner far above drags the header up with it,
  because `partnerY - gap` would win the `min` unconditionally.

The fixed-point iteration replaces `for _ in 0 ..< 2` (`ListView.swift:4054`). Pushing up can bring
the header into overlap with a partner it did not previously overlap — which is exactly what that
second pass catches — so iterating to stability is the same idea without the magic count.

**One level only.** A map that yields must not itself be a yield target, or the composition needs
cycle detection. Enforced by assertion, not documentation alone.

### 3. Stick distance

A yielding attachment measures its stick distance against the adjusted bound, mirroring
`naturalOverlapLowerBound` (`ListView.swift:4039-4052`, `:4084`). This stays on
`AttachmentOffsetMap` for the reason already recorded there: a second derivation of "how far is it
stuck" would be free to disagree with the position the list actually renders.

### 4. Chat wiring

- Drop the `stackingId != nil` skip in `CoreListEntryItem`'s attachment builder.
- `CoreListHeaderAttachedItem.stackingGroup` → the header's `id.space`.
- `stackingYield` → `(group: stackingId.space, gap: 27.0)`.

The 27 stays chat-side as a named constant. It is `7 + 20` — gap plus the date pill's visual height
inside its 34pt band — which is a chat visual fact, not an engine concept.

### 5. Z-order

`insertItemBelowOtherHeaders` (`ListView.swift:4037`) falls out for free: an attachment that yields
sorts below its target group in the attachment order. No new API.

## Rejected alternatives

**Post-solve pass plus a matching adjustment in the flight baking.** Leaves `AttachmentOffsetMap`
untouched at the cost of deriving the nudged position twice, once per frame and once when baking.
This is precisely what the existing comment on `stickDistance` warns against — "a second derivation
of 'how far is it stuck' would be free to disagree with the position the list actually renders" —
one field over.

**Composite attachment holding pill and topic header in one view.** No interaction needed because
there is one solve. But the two have genuinely different runs: the date pill's members are a day,
the topic header's are a thread. They do not share a member range, so they cannot be one attachment
without breaking run formation. Fundamental rather than awkward.

## Tests

`CoreListDemoTests`, with a fixture publishing two attachment groups where one yields:

1. The nudge engages only on overlap — a partner far above leaves the yielding attachment alone.
2. It clamps at the band top.
3. Among several overlapping partners it settles on the topmost, deterministically, regardless of
   the order partners are supplied in.
4. It converges past the case `ListViewImpl`'s two passes were needed for: a push that creates a new
   overlap.
5. A two-level yield trips the assertion.
6. Keyframe parity — `composedKeyframe` of a yielding map matches per-frame `y(atOffset:)` sampled
   along the same trajectory, extending the existing `AttachmentKeyframeParityTests` pattern. This
   is the test that would have caught the rejected design.

## Non-goals

- `ListViewImpl` is not modified, including its order-dependent pick.
- No other deferred item is addressed: per-item animation selectivity and `stationaryItemRange`
  bounds remain open.

## Risks and verification

The suite carries correctness here. Runtime verification needs a real monoforum with topics spanning
a day boundary, which cannot be synthesized on the simulator, so the on-screen check is manual and
comes last. Note the precedent recorded in this backend's own doc: of six chat behaviors verified
during the scroll-to-item work, **two failed on first contact and neither failure was visible to a
green suite** — so a green run here is necessary and not sufficient.
