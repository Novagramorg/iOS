# Delayed Auto-Load Response Design

**Date:** 2026-07-24
**Status:** IMPLEMENTED / CURRENT

## Goal

Make the Demo's automatic top and bottom loading behave like an asynchronous data source: each
accepted request receives its response after 0.2 seconds, and the controller never issues a
duplicate request for an edge that is already queued or in flight.

This remains Demo/controller policy. `CoreVirtualListView` continues to expose only settled edge
state and transition callbacks; it does not own requests, delays, or deduplication.

## Request State

`ViewController` owns two disjoint edge sets:

- **queued edges** have arrived and are waiting for the existing next-main-turn coalescing step;
- **in-flight edges** belong to a captured request whose delayed response has not yet been applied.

`enqueueAutoLoad(edges:)` subtracts both sets before accepting new work. Repeated callbacks, margin
recomputation, list replacement, or manual reevaluation therefore cannot duplicate an edge while
its request is queued or in flight.

The next-main-turn step moves all queued edges into one captured request. This preserves the
existing behavior in which simultaneous top and bottom contact produces one response transaction
that prepends and appends five rows together.

## Delayed Response

Each captured request schedules one response exactly 0.2 seconds later through an injected response
scheduler. Production uses `DispatchQueue.main.asyncAfter`; deterministic tests use a manual
scheduler and advance virtual time without sleeping.

When the response fires:

1. verify that Auto Load is still enabled and that the request generation is current;
2. remove the captured edges from the in-flight set;
3. add five fresh rows for each captured edge in one zero-duration
   `.preserveVisibleContent` transaction;
4. inspect the new settled `reachedLoadedEdges` and enqueue any still-reached edge as the next
   delayed request.

An accepted response is applied even if the user moves away from its edge during the delay. This
matches a real request whose response remains useful after navigation. Leaving the edge does not
cancel or duplicate the request.

Every continuation batch is a new request and therefore receives its own full 0.2-second delay.

## Cancellation and List Replacement

Disabling Auto Load:

- increments a request-generation token;
- clears queued and in-flight edge sets; and
- makes already scheduled response closures inert.

Re-enabling starts from the current list's settled edge set under the new generation.

Changing scroll engines preserves enabled state and any in-flight request. Binding the replacement
list and reevaluating its edge state cannot duplicate edges already in flight. When the captured
response arrives, it applies to the controller's current list instance.

## Scheduler Boundary

Add a small controller-facing response-scheduler protocol:

```swift
protocol AutoLoadResponseScheduling: AnyObject {
    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void)
}
```

`MainQueueAutoLoadResponseScheduler` dispatches on the main queue after the requested delay.
`ViewController` receives the scheduler through an internal initializer with the production
scheduler as its default. Storyboard decoding also uses the production scheduler.

The existing next-main-turn request coalescing remains `DispatchQueue.main.async`; only the simulated
response is delayed.

## Testing

Demo interaction tests use a manual response scheduler and verify:

- enabling at launch forms a request but changes no items before 0.2 seconds;
- advancing from 0.199 to 0.2 seconds applies exactly one five-row response;
- repeated arrival/reevaluation for an in-flight edge still produces exactly one response;
- simultaneous top and bottom contact remains one response transaction;
- moving away during the delay does not cancel the accepted response;
- an edge that remains reached schedules another response with a fresh 0.2-second delay;
- disabling before the deadline suppresses the response and future loads;
- engine replacement preserves the in-flight request without duplicating it.

Existing anchor preservation, zero-duration application, edge-observation, and full serial K2 tests
remain green. No screenshot or video validation is required; runtime diagnostics use logs if needed.

## Alternatives Rejected

- **List-owned request deduplication:** mixes external data-source policy into the list's passive
  observation seam.
- **One global debounce timer:** a later edge could inherit an earlier request's deadline and receive
  less than 0.2 seconds.
- **Independent per-edge response timers:** simultaneous top/bottom contact would split into two
  mutations and lose the existing one-pass preservation behavior.
