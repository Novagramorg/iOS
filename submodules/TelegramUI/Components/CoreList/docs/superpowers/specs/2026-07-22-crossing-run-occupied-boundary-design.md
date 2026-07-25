# Crossing Run Occupied-Boundary Design

**Status:** IMPLEMENTED / CURRENT

## Problem

An unwitnessed crossing run currently projects its anchorward edge onto the raw viewport-plus-preload
retention threshold. A built window includes the item that straddles that threshold, so its settled occupied
extent can extend beyond the threshold. Projecting the crossing run onto the threshold can therefore overlap
the last loaded row below the anchor, or the first loaded row above it.

In the `H+Size+5` reproduction, the lower retention threshold is `y=767`, while the settled loaded window
occupies through `y=800`. The rigid crossing run preserves its internal 75-point spacing, but its first member
still finishes against `y=767` and overlaps the loaded row by 33 points during the transition.

## Design

`CrossingRetentionBand` will carry the settled occupied extent of the window on the side used by the current
pass. This extent is already known from the built old or new window; computing it performs no additional item
measurement and does not expand loaded membership.

For an unwitnessed rigid fallback run:

- below the anchor, the run's first `minY` is projected to
  `max(retentionMaxY, occupiedMaxY)`;
- above the anchor, the run's last `maxY` is projected to
  `min(retentionMinY, occupiedMinY)`;
- every member receives the same translation, preserving all known internal spacing;
- witnessed endpoints and move participants keep their existing identity-local planning;
- ownership, animation tracks, completion, and virtualization membership remain unchanged.

The old-side occupied extent is used when constructing incoming carries, and the new-side occupied extent is
used when constructing outgoing carries. This makes the rule symmetric for loaded-to-unloaded and
unloaded-to-loaded crossings.

## Alternatives Rejected

Inferring the complete structural displacement from unloaded inserted or resized items would require measuring
geometry outside the settled window. Borrowing a displacement from a survivor in a different structural
region can omit part of a mixed pass. Both violate the established best-effort boundary rule.

Using only the loaded-window edge is also insufficient in the unusual case where known occupied geometry ends
inside the retention threshold. Taking the outer of the threshold and occupied extent preserves both retention
and non-overlap invariants.

## Verification

Planner tests will cover lower and upper occupied extents that protrude beyond the raw retention threshold and
confirm rigid spacing. A list-level `H+Size+5` regression will assert that the first outgoing carry begins at or
beyond the settled loaded window's `maxY`; the symmetric incoming/upper case will be covered at the planner
level unless production setup exposes a smaller direct fixture.

Runtime verification will use launch-argument-gated presentation-frame logging on K2 with a 10x deterministic
animation factor. At every sampled frame, the crossing run must retain its member spacing; at the endpoint its
anchorward edge must not overlap the settled loaded extent. Temporary instrumentation will be removed before
the final serial K2 suite.
