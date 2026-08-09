import UIKit

/// `ScrollEngine` driving `CoreVirtualListView` via the owned `ScrollPhysics` core (`.stepped`
/// deceleration). Drives `contentHost.bounds.origin.y` exactly like a `UIScrollView`, so the list's
/// layout math is unchanged — only the driver differs. Touch only; trackpad and `.keyframe`
/// deceleration during virtualization are future increments.
final class PhysicsScrollEngine: NSObject, ScrollEngine {
    private let host = UIView()
    private let core: PhysicsScrollCore
    private let pan = PhysicsPanGestureRecognizer(target: nil, action: nil)
    private var displayLink: CADisplayLink?
    /// Whether the pan recognized a drag this gesture (so a bare-tap touch-up can spring back without
    /// double-handling a real release, which `.ended`/`.cancelled` already handle).
    private var sawDrag = false

    /// Set when `shouldReceive(event:)` forces the pan to `.began` for the trackpad finger-rest catch.
    /// `pan.setTranslation(.zero, in:)` is silently ignored for indirect-scroll, so the recognizer's
    /// translation at our forced `.began` carries the STALE value from the prior gesture and never
    /// decrements — spurious `.changed` events would feed that value into `core.drag` and overscroll the
    /// list far past the catch position. We track our own baseline and subtract it in `.changed` so the
    /// drag math sees the delta SINCE the catch, not the cumulative since the prior gesture. Cleared on
    /// `.ended`/`.cancelled` so a following natural-`.began` gesture sees raw translation as today.
    private var trackpadForcedBegan = false
    private var trackpadTranslationBaseline: CGFloat = 0

    /// How a flick/bounce plays out after release. `.stepped` (default) integrates the physics on the
    /// main thread once per frame (the original behaviour); `.keyframe` precomputes the whole path and
    /// plays it as a render-server `CAKeyframeAnimation` on the host's `bounds.origin.y`, driving the
    /// shared `KeyframeFlight` so the list can re-base its coordinate mid-flight (rebake-and-splice).
    enum DecelerationMode { case stepped, keyframe }
    var decelerationMode: DecelerationMode = .stepped

    // Keyframe-flight state (nil/zero unless a `.keyframe` deceleration is in flight). `flightGeneration`
    // is the ENGINE-owned cross-flight staleness guard (launch/re-emit/catch); `KeyframeFlight.generation`
    // counts rebakes WITHIN a flight only.
    private var flight: KeyframeFlight?
    private var flightGeneration = 0
    private static let flightKey = "listDecelerationFlight"

    /// Layer-LOCAL time (CLAUDE.md gotcha). Equals `CACurrentMediaTime()` only at default layer speed;
    /// reading it via `convertTime` keeps the flight sampler on CA's rendered position under slow-mo.
    private func localNow() -> CFTimeInterval { host.layer.convertTime(CACurrentMediaTime(), from: nil) }

    override init() {
        core = PhysicsScrollCore(contentHost: host)
        super.init()
        pan.addTarget(self, action: #selector(handlePan(_:)))
        // No catch here any more: when content is moving the pan now recognizes immediately
        // (shouldBeginImmediately below) and the catch runs in handlePan(.began). Catching in
        // onTouchDown would null the motion BEFORE shouldBeginImmediately reads it → no grab, no absorb.
        pan.onTouchDown = { [weak self] in self?.sawDrag = false }
        pan.onTouchUp = { [weak self] in self?.handleTouchUp() }
        // Grab the scroll the instant a finger lands on MOVING content (UIScrollView's no-deadzone feel).
        // The forced .began runs handlePan(.began) → the catch; and because the engine grants no
        // simultaneity, UIKit's plain exclusion FAILS the content recognizer as the pan begins, so the
        // stopping tap is absorbed instead of falling through to the row. At rest the closure is
        // false → normal hysteresis, and the content recognizer wins on its own.
        pan.shouldBeginImmediately = { [weak self] in
            guard let self else { return false }
            return self.flight != nil || self.core.isDecelerating
        }
        pan.delegate = self
        host.addGestureRecognizer(pan)
    }

    // MARK: - ScrollEngine

    var onScroll: ((CGFloat) -> Void)? {
        get { core.onScroll }
        set { core.onScroll = newValue }
    }

    /// Published only in `.keyframe` mode, where the render server plays the trajectory.
    var onFlightChanged: ((ScrollFlight?) -> Void)?
    var onWillBeginDragging: (() -> Void)?
    var onDidEndDragging: (() -> Void)?
    /// The physics scroll position, advanced once per frame by whichever driver is running — NEVER a sample of
    /// the flight. Consumers may read this as many times as they like within a frame and get one coherent
    /// value; a consumer that reads it twice around its own work (the list does, three times per mutation
    /// pass) must not observe the scroll position moving underneath it. Sampling the flight here instead made
    /// every mid-flight `applyChanges` re-place the content where it was when the pass started — a backward
    /// lurch of `velocity × pass duration`, up to 185pt measured. See
    /// docs/superpowers/specs/2026-07-26-clock-free-mutation-pass-design.md.
    ///
    /// The instantaneous position is deliberately NOT exposed: `catchFlight` samples
    /// `flight.liveOffset(now: localNow())` directly, which is the one operation that genuinely needs it.
    var offset: CGFloat { core.offset }
    var contentHost: UIView { host }

    func setOffset(_ y: CGFloat) {
        // The list's one-viewport delta-clamp routes here; during a flight, catch first (plain catch —
        // the clamp is unreachable at realistic flick speeds, so a relaunch is unnecessary). After
        // halting the drivers (catchFlight removes the CA animation; stopDisplayLink invalidates the
        // sampling/stepping link), also idle the core's phase via `cancelDeceleration` so the post-
        // setOffset state is fully halted (not just driverless-with-stale-phase). Matches the
        // analogous `finalizeFlight` and TestScrollEngine.setOffset; required by the
        // 4c §4(b) halt idiom `engine.setOffset(engine.offset)`, where Tasks 4-6 (and the §4(b)
        // halt sites in CoreVirtualListView) rely on this call to halt motion fully.
        if flight != nil { catchFlight() }
        stopDisplayLink()
        core.cancelDeceleration()
        core.setOffset(y)
    }
    func haltMotionInPlace() {
        // Same teardown as `setOffset` minus the offset write: `catchFlight` already snaps the physics and
        // the layer model to the live position and removes the animation, so the content does not move.
        if flight != nil { catchFlight() }
        stopDisplayLink()
        core.cancelDeceleration()
    }
    func syncToPresentedPosition() {
        // Exactly what a sampling tick does first: reseed the physics at the flight's live sample. The CA
        // animation is untouched, so the flight keeps playing — only the value the list reads becomes current.
        flight?.beginTick(now: localNow())
    }
    func applyShift(_ dy: CGFloat) {
        if flight != nil {
            // With two open edges this is a rigid coordinate translation and needs no re-emit. A finite
            // edge stays fixed while the offset moves, however, so its relative geometry changes and the
            // translated old bounce is no longer authoritative — unless the translated path still cannot
            // reach that edge, which `noteEdgesChanged` filters out.
            let changesShape = core.hasFiniteEdge
            host.bounds.origin.y += dy
            core.applyShiftPhysicsOnly(dy)
            flight?.noteShift(dy)
            // Republish: a consumer composing against the trajectory must learn the new base, or it
            // keeps positioning against where the flight WOULD have landed before the re-base.
            if let f = flight {
                onFlightChanged?(ScrollFlight(trajectory: f.trajectory,
                                              beginTime: f.startTime,
                                              coordinateShift: f.coordinateShift))
            }
            if changesShape {
                noteFlightEdgesChanged()
            }
        } else {
            core.applyShift(dy)
        }
    }
    func setEdges(min: CGFloat?, max: CGFloat?) {
        if core.setEdges(min: min, max: max) {
            noteFlightEdgesChanged()
        }
    }
    func containerOrigin(windowHeight: CGFloat, topLoaded: Bool, bottomLoaded: Bool) -> CGFloat {
        core.containerOrigin(windowHeight: windowHeight, topLoaded: topLoaded, bottomLoaded: bottomLoaded)
    }

    // MARK: - Driver

    /// Route a declared-edge change (or a coordinate re-base against a fixed edge) into the live flight.
    /// `noteEdgesChanged` ignores a change that cannot reach its baked path — that flight keeps playing the
    /// animation it already has, so the generation bump is gated on an invalidation ACTUALLY being pending:
    /// bumping it unconditionally would kill the completion block of an animation we then never replace.
    private func noteFlightEdgesChanged() {
        guard let flight else { return }
        flight.noteEdgesChanged()
        if flight.hasPendingEdgeRebake { flightGeneration &+= 1 }
    }

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        switch gr.state {
        case .began:
            sawDrag = true
            onWillBeginDragging?()
            // Trackpad-style indirect scroll delivers no touch-down, so `onTouchDown` never catches an
            // in-flight keyframe flight — catch it here. Idempotent for touch (onTouchDown nulled it).
            // Braking: this is a finger landing on moving content, the one catch a user watches happen.
            if flight != nil { catchFlight(braking: true) }
            stopDisplayLink()
            refreshScale()                 // round the upcoming decel to DEVICE PIXELS, not whole points
            // Trackpad (indirect) overscroll uses a looser rubber-band than touch (0.715 vs 0.55).
            // isIndirectScroll is correct by .began (touch's touchesBegan cleared it; trackpad leaves it
            // true) and resets per gesture, so the coefficient never leaks into a following touch gesture.
            core.updateRubberBandCoefficient(pan.isIndirectScroll ? RubberBand.trackpadCoefficient
                                                                   : RubberBand.touchCoefficient)
            core.beginDrag()
            // Trackpad forced-.began baseline (see trackpadForcedBegan): capture the recognizer's stale
            // translation NOW so subsequent .changed events compute the delta since this catch. For the
            // touch path (trackpadForcedBegan == false) we use raw translation as today.
            if trackpadForcedBegan { trackpadTranslationBaseline = gr.translation(in: host).y }
        case .changed:
            let rawTr = gr.translation(in: host).y
            let tr = trackpadForcedBegan ? rawTr - trackpadTranslationBaseline : rawTr
            let v = gr.velocity(in: host).y
            // Skip no-movement .changed events on the forced-began path: UIKit fires .changed with the
            // stale-but-unchanging translation after our forced .began (delta=0, vel=0), and calling
            // core.drag(0, 0) would re-apply the rubber-band on top of the already-rubber-banded live
            // offset, compressing further. Skipping keeps the caught offset stable until real movement.
            if trackpadForcedBegan, tr == 0, v == 0 { break }
            core.drag(translation: tr, velocity: v)
        case .ended, .cancelled:
            if core.endDrag() { startDeceleration() }
            trackpadForcedBegan = false
            trackpadTranslationBaseline = 0
            // Paired with the `.began` notification above: the pan can only reach `.ended`/`.cancelled`
            // after `.began`, so the two callbacks always bracket the finger-down interval. Fired AFTER
            // deceleration is launched so an observer reading motion state sees the post-release truth.
            onDidEndDragging?()
        default:
            break
        }
    }

    /// Route a release that should decelerate/spring to the active mode's driver.
    private func startDeceleration() {
        switch decelerationMode {
        case .stepped:  startSteppingLink()
        case .keyframe: launchFlight()
        }
    }

    /// A bare tap (no drag) lifted: if it left the content overscrolled, resume the spring-back via the
    /// active mode's driver (so a tap during a `.keyframe` bounce springs back as a keyframe flight too).
    private func handleTouchUp() {
        guard !sawDrag else { return }
        resumeBounceIfOverscrolled()
    }

    /// Resume the edge bounce if the content was left overscrolled by a catch-and-hold (touch tap or
    /// trackpad finger-rest). Shared by `handleTouchUp` (touch) and the `.ended`/`.cancelled` UIScrollEvent
    /// branch in `shouldReceive(event:)` (trackpad). No-op when at rest within the edges.
    private func resumeBounceIfOverscrolled() {
        refreshScale()
        if core.resumeBounceIfOverscrolled() { startDeceleration() }
    }

    /// Match the deceleration's pixel-rounding to the device's real display scale, like
    /// `PhysicsScrollView.makePhysics`. Read at gesture start (the host is in a window then, so the
    /// trait collection is valid). Window-guarded: a detached host — e.g. in unit tests — keeps the
    /// deterministic default scale 1, so the physics-core test fixtures stay byte-identical.
    private func refreshScale() {
        guard host.window != nil else { return }
        core.updateScale(Swift.max(host.traitCollection.displayScale, 1))
    }

    // MARK: - Stepped driver (default)

    @objc private func step(_ link: CADisplayLink) {
        let dtMs = CGFloat((link.targetTimestamp - link.timestamp) * 1000)
        if core.step(dtMs: dtMs) { stopDisplayLink() }
    }

    private func startSteppingLink() {
        stopDisplayLink()
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    // MARK: - Keyframe driver (increment 4a)

    /// Bake the released decel state into a `KeyframeFlight`, park the host model at the settled offset,
    /// and hand the visual path to the render server. The sampling link reports the live offset (and
    /// drives the list's mid-flight rebalance → rebake); the CA completion finalises.
    private func launchFlight() {
        let now = localNow()
        let f = KeyframeFlight(core: core, startTime: now)
        guard f.trajectory.samples.count >= 2, f.trajectory.duration > 0 else {
            // Degenerate (unreachable in practice — endDrag only decelerates with real motion, and
            // Trajectory.build always appends ≥1 post-t0 sample). Snap + settle, and idle the core so
            // isDecelerating doesn't stay stale (matches .stepped's settle + TestScrollEngine).
            core.setOffset(f.trajectory.finalOffset)
            core.cancelDeceleration()
            onFlightChanged?(nil)
            onScroll?(f.trajectory.finalOffset)
            return
        }
        flight = f
        host.bounds.origin.y = f.trajectory.finalOffset            // model at settled (sync)
        flightGeneration &+= 1
        let g = flightGeneration
        // disablingImplicitActions: false — this site never disabled them, and doing so now would
        // change what the flight install does.
        let flightAnim = f.trajectory.boundsOriginKeyframeAnimation(beginTime: now)
        flightAnim.preferHighRefreshRate()
        if #available(iOS 15.0, *), let r = maxRefreshRange() { flightAnim.preferredFrameRateRange = r }   // pin the floor: hold the rate
        flightAnim.setCoreListCompletion { [weak self] _ in
            guard let self, self.flightGeneration == g else { return }   // ignore stale completions
            self.finalizeFlight()
        }
        host.layer.add(flightAnim, forKey: Self.flightKey)
        onFlightChanged?(ScrollFlight(trajectory: f.trajectory, beginTime: now))
        startSamplingLink()
    }

    /// Per-tick protocol (order is load-bearing — `KeyframeFlight` asserts the core is `.decelerating`):
    /// FIRST the `isComplete` finalize check; else `beginTick` (reseed core to the live sample), THEN
    /// `onScroll(liveOffset)` (the list rebalances → applyShift/setEdges → noteShift/noteEdgesChanged),
    /// THEN `rebakeIfNeeded`; on a rebake, re-emit the CA animation from the spliced trajectory.
    @objc private func sampleTick(_ link: CADisplayLink) {
        guard let f = flight else { stopDisplayLink(); return }
        let now = localNow()
        if f.isComplete(now: now), !f.hasPendingEdgeRebake {
            finalizeFlight()
            return
        }
        f.beginTick(now: now)
        onScroll?(f.liveOffset(now: now))                          // list rebalances → applyShift (model-bump) / setEdges
        if f.rebakeIfNeeded(now: now) {
            if f.isComplete(now: now) {
                finalizeFlight()
            } else {
                reemitFlightAnimation()
            }
        }
    }

    /// Re-emit the CA animation after a mid-flight rebake/splice — now ONLY an edge/shape change (a pure
    /// coordinate shift rides the model translation in `applyShift` instead). Snap the model to the new
    /// settled offset and play the spliced trajectory from its startTime.
    private func reemitFlightAnimation() {
        guard let f = flight else { return }   // re-entrant catch (setOffset during onScroll) nulled flight → no-op, no stray anim
        host.layer.removeAnimation(forKey: Self.flightKey)
        host.bounds.origin.y = f.trajectory.finalOffset
        flightGeneration &+= 1
        let g = flightGeneration
        let flightAnim = f.trajectory.boundsOriginKeyframeAnimation(beginTime: f.startTime)
        flightAnim.preferHighRefreshRate()
        if #available(iOS 15.0, *), let r = maxRefreshRange() { flightAnim.preferredFrameRateRange = r }   // pin the floor: hold the rate
        flightAnim.setCoreListCompletion { [weak self] _ in
            guard let self, self.flightGeneration == g else { return }
            self.finalizeFlight()
        }
        host.layer.add(flightAnim, forKey: Self.flightKey)
        onFlightChanged?(ScrollFlight(trajectory: f.trajectory, beginTime: f.startTime))
    }

    /// Catch an in-flight `.keyframe` deceleration: snap the model (physics + host bounds) to the offset
    /// the flight stops at BEFORE touching the animation (so the swap/removal reveals that position, no
    /// flash), and invalidate `flight`/`flightGeneration` first so the CA completion's stale-
    /// generation guard fires for both async AND synchronous completion paths. Pre-fix the bump+nil
    /// happened AFTER `removeAnimation`: async completion was guarded fine (the original tap-stop path),
    /// but trackpad Option A (catch from `shouldReceive(event:)`) hit a synchronous completion window
    /// where `finalizeFlight` ran during `removeAnimation` — `core.setOffset(f.settledOffset)` then
    /// jumped the list to the post-animation rest position at the moment of catch. With the bump first,
    /// the completion's `flightGeneration == g` guard catches the stale fire; `flight = nil` is the
    /// secondary belt-and-suspenders (finalizeFlight's own `guard let f = flight` also short-circuits).
    ///
    /// `braking` picks WHICH instant the flight stops at, and it is the difference between a clean stop
    /// and a visible backward jerk. A catch takes effect only when its transaction is presented — after
    /// the rest of this main-thread turn and the commit-to-display delay — and the render server plays the
    /// flight until then, so `liveOffset(now:)` is a value the screen has already passed by the time it
    /// lands (40pt one frame late, 79pt two frames late, off a 3000 pt/s release; see
    /// `FlightCatchContinuityTests`). A braking catch instead stops the flight at `brakeStopTime()` and
    /// swaps in the same path truncated there (`KeyframeFlight.braked`), which presents identically until
    /// that instant — so the content coasts the last couple of frames along the path it was already on and
    /// stops, instead of snapping back. INTERACTIVE catches brake; the programmatic ones
    /// (`setOffset`, `haltMotionInPlace`, `tearDown`) do not, because each of them immediately imposes its
    /// own position or tears the engine down, and a residual brake would ride on top of that write.
    private func catchFlight(braking: Bool = false) {
        guard let f = flight else { return }
        let brake = braking ? f.braked(stoppingAt: brakeStopTime()) : nil
        let live = brake?.offset ?? f.liveOffset(now: localNow())
        core.setOffset(live)                          // also writes host.bounds.origin.y = live (via core.writeOffset)
        host.bounds.origin.y = live                   // redundant but explicit: model == live BEFORE the swap (no flash)
        flight = nil
        flightGeneration &+= 1
        if let brake {
            // Same key ⇒ this REPLACES the flight animation rather than leaving the layer bare, and it
            // rides the flight's own `startTime` (a past explicit origin, exactly as `reemitFlightAnimation`
            // does) so its already-played history lines up frame for frame with what is on screen. No
            // completion: there is no flight left to finalize, and the generation bump above has already
            // disarmed the animation this one displaces.
            let brakeAnim = brake.trajectory.boundsOriginKeyframeAnimation(beginTime: f.startTime)
            brakeAnim.preferHighRefreshRate()
            if #available(iOS 15.0, *), let r = maxRefreshRange() { brakeAnim.preferredFrameRateRange = r }
            host.layer.add(brakeAnim, forKey: Self.flightKey)
        } else {
            host.layer.removeAnimation(forKey: Self.flightKey)
        }
        onFlightChanged?(nil)
    }

    /// Layer-local instant a braking catch should come to rest: the first frame this turn's commit can
    /// realistically be PRESENTED at, plus one frame of headroom. `targetTimestamp` is the vsync the
    /// transaction we are about to commit is aiming at, so it is the estimate; the extra frame is because
    /// the two errors are not symmetric — landing early just means the flight coasts a few more
    /// milliseconds along the path the eye is already tracking, while landing late is the backward step
    /// this whole mechanism exists to remove. `max` with `localNow()` covers a turn that has already
    /// overrun its frame (the link's timestamps only refresh in its callback, so they can be in the past).
    /// Both link timestamps are converted through the layer, so the headroom stays a real frame under a
    /// non-unit layer speed.
    private func brakeStopTime() -> CFTimeInterval {
        let now = localNow()
        // `timestamp == 0` means the sampling link has not fired yet (a catch in the same turn as the
        // launch), so its window is meaningless — fall back to the display's nominal frame.
        guard let link = displayLink, link.timestamp > 0 else {
            let frame = 1.0 / Double(Swift.max(UIScreen.main.maximumFramesPerSecond, 60))
            return now + 2 * frame
        }
        let lastFrame = host.layer.convertTime(link.timestamp, from: nil)
        let nextFrame = host.layer.convertTime(link.targetTimestamp, from: nil)
        let frame = Swift.max(nextFrame - lastFrame, 1.0 / 120.0)
        return Swift.max(now, nextFrame) + frame
    }

    /// Catch an in-flight deceleration when fingers REST on the list. Trackpad delivers no touch-down,
    /// so `shouldBeginImmediately`/`handlePan(.began)` only fire on the first MOVEMENT, never on a pure
    /// finger-rest — this is the trackpad finger-rest stop (see `shouldReceive(event:)`). Handles both
    /// modes: a keyframe flight catches to its live offset; a stepped decel stops its link and idles the
    /// core, holding the content where it caught (no `onScroll` — nothing moved). The caller gates this
    /// to `state == .possible`, so it never fires mid-drag.
    private func catchMotionForFingerRest() {
        if flight != nil {
            catchFlight(braking: true)      // interactive, same as the touch catch — see `catchFlight`
        } else if core.isDecelerating {
            stopDisplayLink()
            core.cancelDeceleration()
        }
    }

    /// Authoritative end-of-flight (CA completion OR the sampler reaching `duration`). The model is
    /// already at the settled offset; tear down and report the settled position.
    private func finalizeFlight() {
        guard let f = flight else { return }          // idempotent
        stopDisplayLink()
        core.setOffset(f.settledOffset)            // settle at the LIST-coord rest (finalOffset + accrued shift)
        core.cancelDeceleration()                  // idle the core (phase → .idle) — matches TestScrollEngine
        flight = nil
        onFlightChanged?(nil)                      // BEFORE onScroll: a consumer re-entering must see no flight
        onScroll?(core.offset)
    }

    private func startSamplingLink() {
        stopDisplayLink()
        let link = CADisplayLink(target: self, selector: #selector(sampleTick(_:)))
        if #available(iOS 15.0, *), let r = maxRefreshRange() { link.preferredFrameRateRange = r }   // hold the ProMotion rate (residual-hitch fix)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    /// A FIXED max-refresh range (`min == max == preferred`) for ProMotion, or nil on ≤60Hz. Diagnosis:
    /// the residual scroll hitch was the DISPLAY rate dropping (sampling display-link callbacks skipped
    /// while our main thread sat idle at ~0.5ms, no re-emit). The flight animation requested
    /// `(min: 30, max, max)` — that low floor let the system throttle the display to ~80Hz and
    /// intermittently halve it. Pinning the floor on the link AND the flight animation holds the rate.
    @available(iOS 15.0, *)
    private func maxRefreshRange() -> CAFrameRateRange? {
        let maxFps = Float(UIScreen.main.maximumFramesPerSecond)
        guard maxFps > 61 else { return nil }   // no-op on ≤60Hz (incl. Simulator)
        return CAFrameRateRange(minimum: maxFps, maximum: maxFps, preferred: maxFps)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    /// Stop the display link so an engine that is being discarded (e.g. the demo swapping engines)
    /// doesn't keep stepping/sampling a detached host until its in-flight deceleration settles. A live
    /// `.keyframe` flight is caught first so its CA animation is removed (the link retains its target,
    /// so without this the engine lingers — and keeps firing — until the decel ends on its own).
    func tearDown() {
        if flight != nil { catchFlight() }
        stopDisplayLink()
    }

    deinit { displayLink?.invalidate() }
}

extension PhysicsScrollEngine: UIGestureRecognizerDelegate {
    /// **Never grant simultaneity to a content recognizer.** UIKit resolves simultaneity as *either
    /// delegate says yes*, so a grant here overrides a refusal written in a file this one never
    /// mentions — a nested scroll view's UIKit default, or `ContextGesture`'s explicit
    /// `other is UIPanGestureRecognizer -> false` (`Display/Source/ContextGesture.swift:66`). Our pan
    /// IS a pan, so anything refusing pans is refusing us, and neither refusal can be seen from here.
    /// That is what makes a grant unfindable from the content side, and it shipped twice: first as an
    /// in-bubble carousel and the chat history both scrolling on one diagonal drag, then as a bubble's
    /// long-press running its press animation and never activating.
    ///
    /// Denying leaves plain UIKit exclusion, which is the whole of `ListViewImpl`'s mechanism
    /// (`ListViewScroller` denies everything but `ListViewTapGestureRecognizer`,
    /// `Display/Source/ListViewScroller.swift:15`). Exclusion is also what absorbs the stopping tap:
    /// a pan force-begun on moving content FAILS the content recognizer at touch-down. There is
    /// deliberately no `shouldBeRequiredToFailBy` counterpart — a failure dependency HOLDS a
    /// recognizer instead of failing it, and a pan that force-began never fails until lift, so the
    /// held recognizer sits in `.possible` while its own timer-driven animation runs to completion.
    ///
    /// `false` is UIKit's default, so this method is redundant in the strict sense. It stays as the
    /// marker in the exact spot both bugs were introduced, and because the policy tests need
    /// something to call.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return false
    }

    /// Ported from `ListViewScroller.gestureRecognizerShouldBegin`
    /// (`Display/Source/ListViewScroller.swift:22`), the delegate that governs `ListViewImpl`'s scroll
    /// pan. Two deferrals:
    ///
    /// - a two-touch pan on the same view wins while two fingers are down. Currently inert — nothing
    ///   else attaches to `host` — but it is the rule, and it costs nothing to keep true;
    /// - a `UIControl` already tracking keeps the touch. This one is live: chat's inline bot keyboards
    ///   put real `UIButton`s inside the list (`ChatMessageActionButtonsNode`).
    ///
    /// Note this also gates the forced-immediate `.began`: writing `state = .began` runs the same
    /// transition machinery as a natural begin, so a tracking control can deny a grab on moving
    /// content. `ListViewImpl` behaves identically — `UIScrollView`'s decelerating-grab passes
    /// through this same override.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === pan, let view = pan.view else { return true }
        if let recognizers = view.gestureRecognizers {
            for other in recognizers where other !== pan {
                if let otherPan = other as? UIPanGestureRecognizer, otherPan.minimumNumberOfTouches == 2 {
                    return pan.numberOfTouches < 2
                }
            }
        }
        if let hit = view.hitTest(pan.location(in: view), with: nil) as? UIControl {
            return !hit.isTracking
        }
        return true
    }

    /// Trackpad two-finger scroll delivers no `UITouch`, so `touchesBegan`/`onTouchDown`/
    /// `shouldBeginImmediately` never fire for it and there is no `onTouchUp` either. UIKit consults
    /// this delegate (the `UIEvent` overload) only once per gesture, at finger-down, while the
    /// recognizer is still `.possible` — the trackpad equivalent of `touchesBegan`. We catch any
    /// in-flight motion AND force `state = .began` (the public-API analogue of touch's
    /// `shouldBeginImmediately` path): the existing `handlePan(.began)` then runs (sawDrag, second
    /// catch as a no-op, `core.beginDrag` at the caught offset), and on natural finger-lift UIKit
    /// transitions the recognizer through `.ended` → `handlePan(.ended)` → `core.endDrag()`. Per
    /// `ScrollAxis.endDrag`, an overscrolled offset returns `.decelerate` regardless of a prior
    /// `beginDrag`, so a trackpad rest-then-lift over a bounce resumes the bounce — exactly as touch
    /// does. Gated on motion (mirrors `shouldBeginImmediately`'s condition) so a finger-rest on idle
    /// content lets the recognizer transition naturally on the user's first movement. The catch runs
    /// even if UIKit silently no-ops the state write (safety net). Always returns `true`. Touch is
    /// unaffected — UIKit consults this overload only for scroll events.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool {
        guard gestureRecognizer.state == .possible, flight != nil || core.isDecelerating else { return true }
        catchMotionForFingerRest()
        // Mark the forced-began path so handlePan(.began) captures the recognizer's stale translation as
        // a baseline (the indirect-scroll recognizer ignores setTranslation, so we subtract our own
        // baseline in .changed to make drag math see the delta since the catch, not the cumulative
        // translation that leaked from the prior gesture). See `trackpadForcedBegan` for the full why.
        trackpadForcedBegan = true
        gestureRecognizer.state = .began
        return true
    }
}
