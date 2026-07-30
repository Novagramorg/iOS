# Demo Auto Edge Loading

**Status:** IMPLEMENTED / CURRENT

## Goal

Add an opt-in Demo mode that simulates bidirectional infinite loading. While the mode is enabled,
arriving at the currently known top or bottom edge adds five fresh rows on that side without moving
the settled visible content.

This is a Demo data-loading policy. `CoreVirtualListView` reports edge arrivals but does not create,
request, or own data.

## Demo behavior

- Add an `Auto Load` toggle to the top control panel, following the existing `Chaos` toggle style.
- The mode defaults to off.
- Enabling the mode immediately evaluates the list's current settled edge contact. Consequently,
  enabling it immediately after launch loads at the top without requiring the user to scroll away
  and return.
- Reaching the top prepends five fresh `DemoListItem` identities.
- Reaching the bottom appends five fresh `DemoListItem` identities.
- Each load is one `applyChanges` pass with
  `anchorMode: .preserveVisibleContent` and zero animation duration.
- Loading continues in five-row batches until the completed transaction leaves neither load line
  reached. Adding a batch usually moves that collection boundary away from the line in one pass, while
  underfilled or unusually short content receives further batches on later main-queue turns.
- Turning the mode off suppresses queued or future loads.
- Rebuilding the list to change scroll engines preserves the toggle state and immediately
  reevaluates edge contact on the replacement list.

The existing manual `Load +5` and `Load -5` controls remain unchanged.

## List edge observation

`CoreVirtualListView` exposes:

- a read-only set of loaded edges currently reached by the settled viewport; and
- an edge-arrival callback that reports only transitions from not-reached to reached; and
- `loadedEdgeMargin: CGFloat = 0`, a symmetric signed load-line margin.

Load lines use list-local viewport coordinates and are independent of content insets:

- top line: `loadedEdgeMargin`;
- bottom line: `logicalSize.height - loadedEdgeMargin`.

Positive margins move both lines inward and therefore load later. Negative margins move both lines
outward and load earlier.

The top is reached when collection item zero is loaded and the settled screen-space top of the
collection is greater than or equal to the top line. The bottom is reached when the last collection
item is loaded and the settled screen-space bottom of the collection is less than or equal to the
bottom line. These screen positions are derived from the settled window/container geometry minus
the settled engine offset; active visual animation is not sampled.

Content insets continue to define row layout, finite engine limits, clamping, and bounce, but do not
move the load lines. Rubber-band overscroll does not create repeated arrivals while an edge remains
reached. A short list may report both edges.

The list recomputes this state after initial construction, user-scroll rebalancing, and after an
`applyChanges` transaction writes its new settled endpoint; it does not wait for visual animation
completion. Programmatic scrolling and direct user scrolling use the same observation path. Merely
receiving repeated scroll callbacks while still against an edge does not emit repeated arrivals.
Changing `loadedEdgeMargin` immediately recomputes the reached set and emits only newly reached
transitions.

The callback is informational. It must not alter anchor resolution, window construction, animation,
or the `ScrollEngine` interface.

## Re-entrancy and loading flow

The controller owns an `autoLoadEnabled` flag and a pending-edge set.

1. An edge arrival is recorded only while the mode is enabled.
2. The controller schedules processing onto the next main-queue turn rather than mutating data from
   inside the list's scroll or settlement callback.
3. Before processing, it verifies that the mode is still enabled and consumes each pending edge at
   most once.
4. It builds one new item array for the edge and submits the zero-duration preserved-content pass.
5. After `applyChanges` synchronously writes the new logical items, settled window, edge limits, and
   engine offset, the controller reads `reachedLoadedEdges`.
6. Any edge that remains reached is queued for the next main-queue turn. The loop stops when neither
   edge is reached or the mode is disabled.

If both edges are reached in an underfilled list, the controller processes both additions in a
single `applyChanges` pass: five prepended and five appended rows. This avoids ordering-dependent
intermediate loads while preserving the visible witness once. If both remain reached, both continue
together in the next turn.

The continuation is deliberately asynchronous rather than a synchronous loop. Each transaction has
one bounded five-row batch, allowing cancellation and preventing underfilled content from monopolizing
one run-loop turn.

## Testing

List-level tests verify:

- initial settled top contact is readable;
- repeated callbacks at the same edge are deduplicated;
- leaving and returning to an edge emits a new arrival;
- bottom arrivals work symmetrically;
- programmatic and user-driven edge arrivals share the same behavior;
- overscroll does not emit additional arrivals;
- nonzero content insets do not move either load line;
- positive margin delays top and bottom arrival;
- negative margin advances top and bottom arrival;
- changing the margin recomputes and deduplicates edge state.

Demo interaction tests verify:

- the toggle defaults off;
- enabling it at the launch position prepends exactly five rows with stable settled content;
- reaching the bottom appends exactly five rows;
- disabling it prevents loading;
- engine replacement preserves the enabled mode;
- a simultaneous two-edge contact adds one batch at each side in one transaction;
- an edge that remains reached after the first batch receives later batches until it clears;
- disabling the mode between continuation turns cancels the remaining loop.

Validation uses deterministic tests and, when manual runtime inspection is useful, temporary Demo
instrumentation and captured logs. No screenshot or video testing is required.
