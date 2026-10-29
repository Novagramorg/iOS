# Neighbor descriptors

> Moved verbatim from the root `CLAUDE.md` on 2026-10-29, which had passed the 150k-character limit. The root file keeps a short summary under the same heading. "Above", "below" and section names refer to the root `CLAUDE.md` unless the section is in this file.

## Neighbor descriptors

A `ListViewItem` does not see its neighbors. It sees `ListViewItemNeighbors` — two `AnyEquatable`
descriptors that the adjacent items published via `neighborDescriptor`, read through facet protocols
(`ItemListNeighborFacet`, `HeaderNeighborFacet`, and module-local ones). `previousItem:`/`nextItem:`
no longer exist on `nodeConfiguredForParams`, `updateNode`, or `ListViewItemNode.layoutForParams`.

**A descriptor must encode everything a neighbor reads.** `ListViewImpl` relayouts a row exactly
when its `ListViewItemNeighbors` value changes (`ListViewItemNode.appliedNeighbors` vs
`ListView.neighbors(at:)`), so a fact omitted from a descriptor goes stale on screen. When adding a
neighbor-dependent behavior, add the fact to the neighbor's payload — never widen the API back to
passing items.

`neighborDescriptor` has **no default implementation**, deliberately. A conservative default would
compile everywhere while making un-migrated items force a relayout on every transaction — worse
than the policy it replaced, and silent. `AnyEquatable.noNeighborInfluence` is the one-line answer
for items whose neighbors read nothing about them.

`nil` on a side means *no neighbor*; a non-nil descriptor whose facet does not resolve means *a
neighbor that publishes nothing relevant*. Several items depend on that distinction
(`ContactsPeerItem` renders `first` and `firstWithHeader` differently).

**Header families.** Most bespoke neighbor logic was a concrete-type cast asking "does this
neighbor participate in my header runs". That is a `ListViewItemHeaderFamily` tag on
`HeaderNeighborFacet`; consumers that group with any header-bearing neighbor ignore it, narrow ones
compare it. This also removes cross-module type coupling — `ContactListActionItem` checks
`.contactList` rather than importing `ContactsPeerItem`.

**When migrating a new item, grep for more than `previousItem as?`.** The original sweep found eight
neighbor reads only after the parameters were deleted, because they used `is <Type>`, helper
parameters named `(top:bottom:)`, or bare `== nil` presence checks. Note also that `previousItem` is
an overloaded name in this codebase: `let previousItem = self.item` inside a node's `asyncLayout`
means the node's *previous item state*, nothing to do with neighbors.

Types: `Display/AnyEquatable.swift`, `Display/ListViewItemNeighbors.swift`,
`ItemListUI/ItemListNeighborFacet.swift`,
`ChatMessageItemCommon/{ChatHistoryItemNeighbors,ChatMessageMergeFingerprint}.swift`.
