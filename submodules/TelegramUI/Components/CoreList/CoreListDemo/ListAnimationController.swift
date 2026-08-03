import UIKit
import QuartzCore

final class ListAnimationController {
    typealias ScheduleAfter = (_ delay: TimeInterval,
                               _ work: @escaping () -> Void) -> Void
    typealias AnimationInstaller = (_ track: ListAnimationTrack,
                                    _ property: ListAnimatedProperty,
                                    _ layer: CALayer,
                                    _ completion: @escaping () -> Void) -> Void

    let model: ListAnimationModel
    let compiler: CoreAnimationCompiler

    private final class WeakLayer {
        weak var value: CALayer?

        init(_ value: CALayer) {
            self.value = value
        }
    }

    private struct PendingCompletion {
        let owner: ListAnimationOwner
        let property: ListAnimatedProperty
        let generation: UInt64
        let binding: WeakLayer
        let removesOwner: Bool
        let cleanup: (() -> Void)?
    }

    private weak var referenceLayer: CALayer?
    private let mediaTime: () -> CFTimeInterval
    private let durationFactor: () -> Double
    private let scheduleAfter: ScheduleAfter
    private let animationInstaller: AnimationInstaller?
    private var bindings: [ListAnimationOwner: WeakLayer] = [:]
    private var knownOwners: Set<ListAnimationOwner> = []
    private var pendingCompletions: [UInt64: PendingCompletion] = [:]
    private var nextCompletionSerial: UInt64 = 0

    init(model: ListAnimationModel = ListAnimationModel(),
         compiler: CoreAnimationCompiler = CoreAnimationCompiler(),
         mediaTime: @escaping () -> CFTimeInterval = { CACurrentMediaTime() },
         durationFactor: @escaping () -> Double = { UIView.animationDurationFactor },
         scheduleAfter: @escaping ScheduleAfter = { delay, work in
             DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay),
                                           execute: work)
         },
         animationInstaller: AnimationInstaller? = nil) {
        self.model = model
        self.compiler = compiler
        self.mediaTime = mediaTime
        self.durationFactor = durationFactor
        self.scheduleAfter = scheduleAfter
        self.animationInstaller = animationInstaller
    }

    func setReferenceLayer(_ layer: CALayer?) {
        referenceLayer = layer
    }

    func now() -> TimeInterval {
        referenceLayer?.convertTime(mediaTime(), from: nil) ?? mediaTime()
    }

    func seedViewport(layer: CALayer) {
        let owner = ListAnimationOwner.viewport
        _ = bind(owner: owner, to: layer)
        knownOwners.insert(owner)
        if model.value(for: owner, property: .viewportOffset, at: now()) == nil {
            model.seedViewport()
        }
    }

    func seedLive(identity: AnyHashable, layer: CALayer) {
        let owner = ListAnimationOwner.live(identity)
        _ = bind(owner: owner, to: layer)
        knownOwners.insert(owner)
        if model.value(for: owner, property: .opacity, at: now()) == nil {
            model.seedLive(owner: owner,
                           positionOffsetX: 0,
                           positionOffsetY: 0,
                           opacity: 1,
                           width: layer.bounds.width,
                           height: layer.bounds.height)
        }
        writeOpacity(1, on: layer)
    }

    /// Seeds a newly created attachment owner's settled geometry without starting any track — the
    /// attachment analogue of `seedLive`, and a near-copy of it: `model.seedLive(owner:…)` accepts any
    /// `ownsLiveElement` owner, so only the owner and the `precondition` differ.
    ///
    /// The `== nil` guard matters: this runs for every serial with no old state, which includes a run
    /// that scrolled into the window while a track from an earlier pass is still live. Seeding
    /// unconditionally would overwrite it.
    func seedAttachment(owner: ListAnimationOwner, layer: CALayer) {
        precondition(owner.isAttachment)
        _ = bind(owner: owner, to: layer)
        knownOwners.insert(owner)
        if model.value(for: owner, property: .opacity, at: now()) == nil {
            model.seedLive(owner: owner,
                           positionOffsetX: 0,
                           positionOffsetY: 0,
                           opacity: 1,
                           width: layer.bounds.width,
                           height: layer.bounds.height)
        }
        writeOpacity(1, on: layer)
    }

    func seedGhostBlock(owner: ListAnimationOwner,
                        layer: CALayer,
                        settledRootY: CGFloat) {
        precondition(owner.isGhostBlock)
        _ = bind(owner: owner, to: layer)
        knownOwners.insert(owner)
        if model.value(for: owner, property: .positionY, at: now()) == nil {
            model.seedGhostBlock(owner: owner)
        }
        writePositionY(settledRootY, on: layer)
    }

    @discardableResult
    func transitionPosition(identity: AnyHashable,
                            layer: CALayer,
                            oldSettledY: CGFloat,
                            newSettledY: CGFloat,
                            transition: CoreListTransition,
                            transactionTime: TimeInterval? = nil,
                            completion: @escaping (UInt64) -> Void = { _ in })
        -> ListAnimationMutation {
        transitionPosition(owner: .live(identity),
                           layer: layer,
                           oldSettledY: oldSettledY,
                           newSettledY: newSettledY,
                           transition: transition,
                           transactionTime: transactionTime,
                           completion: completion)
    }

    @discardableResult
    func transitionPosition(owner: ListAnimationOwner,
                            layer: CALayer,
                            oldSettledY: CGFloat,
                            newSettledY: CGFloat,
                            transition: CoreListTransition,
                            transactionTime: TimeInterval? = nil,
                            completion: @escaping (UInt64) -> Void = { _ in })
        -> ListAnimationMutation {
        let binding = bind(owner: owner, to: layer)
        knownOwners.insert(owner)
        let time = transactionTime ?? now()
        let mutation = model.transitionPosition(
            owner: owner,
            oldSettledY: oldSettledY,
            newSettledY: newSettledY,
            at: time,
            transition: transition.scaled(by: durationFactor())
        )
        let cleanup: (() -> Void)?
        if case let .started(track) = mutation {
            cleanup = { completion(track.generation) }
        } else {
            cleanup = nil
        }
        apply(mutation, owner: owner, property: .positionY,
              layer: layer, binding: binding, removesOwner: false,
              cleanup: cleanup)
        return mutation
    }

    @discardableResult
    func transitionPositionX(identity: AnyHashable,
                             layer: CALayer,
                             oldSettledX: CGFloat,
                             newSettledX: CGFloat,
                             transition: CoreListTransition,
                             transactionTime: TimeInterval? = nil) -> ListAnimationMutation {
        transitionPositionX(owner: .live(identity),
                            layer: layer,
                            oldSettledX: oldSettledX,
                            newSettledX: newSettledX,
                            transition: transition,
                            transactionTime: transactionTime)
    }

    @discardableResult
    func transitionPositionX(owner: ListAnimationOwner,
                             layer: CALayer,
                             oldSettledX: CGFloat,
                             newSettledX: CGFloat,
                             transition: CoreListTransition,
                             transactionTime: TimeInterval? = nil) -> ListAnimationMutation {
        let binding = bind(owner: owner, to: layer)
        knownOwners.insert(owner)
        let mutation = model.transitionPositionX(
            owner: owner,
            oldSettledX: oldSettledX,
            newSettledX: newSettledX,
            at: transactionTime ?? now(),
            transition: transition.scaled(by: durationFactor())
        )
        if mutation != .unchanged {
            writePositionX(newSettledX, on: layer)
        }
        apply(mutation, owner: owner, property: .positionX,
              layer: layer, binding: binding, removesOwner: false,
              cleanup: nil)
        return mutation
    }


    @discardableResult
    func transitionGhostBlock(owner: ListAnimationOwner,
                              layer: CALayer,
                              oldSettledY: CGFloat,
                              newSettledY: CGFloat,
                              transition: CoreListTransition,
                              transactionTime: TimeInterval) -> ListAnimationMutation {
        precondition(owner.isGhostBlock)
        let binding = bind(owner: owner, to: layer)
        knownOwners.insert(owner)
        let mutation = model.transitionGhostBlock(
            owner: owner,
            oldSettledY: oldSettledY,
            newSettledY: newSettledY,
            at: transactionTime,
            transition: transition.scaled(by: durationFactor())
        )
        if mutation != .unchanged {
            writePositionY(newSettledY, on: layer)
        }
        apply(mutation,
              owner: owner,
              property: .positionY,
              layer: layer,
              binding: binding,
              removesOwner: false,
              cleanup: nil)
        return mutation
    }

    @discardableResult
    func transitionViewport(layer: CALayer,
                            oldSettledOffset: CGFloat,
                            newSettledOffset: CGFloat,
                            transition: CoreListTransition,
                            transactionTime: TimeInterval? = nil,
                            completion: @escaping (UInt64) -> Void = { _ in })
        -> ListAnimationMutation {
        let owner = ListAnimationOwner.viewport
        let binding = bind(owner: owner, to: layer)
        knownOwners.insert(owner)
        let mutation = model.transitionViewport(
            oldSettledOffset: oldSettledOffset,
            newSettledOffset: newSettledOffset,
            at: transactionTime ?? now(),
            transition: transition.scaled(by: durationFactor())
        )
        let cleanup: (() -> Void)?
        if case let .started(track) = mutation {
            cleanup = { completion(track.generation) }
        } else {
            cleanup = nil
        }
        apply(mutation, owner: owner, property: .viewportOffset,
              layer: layer, binding: binding, removesOwner: false,
              cleanup: cleanup)
        return mutation
    }


    @discardableResult
    func transitionHeight(identity: AnyHashable,
                          layer: CALayer,
                          oldSettledHeight: CGFloat,
                          newSettledHeight: CGFloat,
                          transition: CoreListTransition,
                          transactionTime: TimeInterval? = nil) -> ListAnimationMutation {
        transitionHeight(owner: .live(identity),
                         layer: layer,
                         oldSettledHeight: oldSettledHeight,
                         newSettledHeight: newSettledHeight,
                         transition: transition,
                         transactionTime: transactionTime)
    }

    @discardableResult
    func transitionHeight(owner: ListAnimationOwner,
                          layer: CALayer,
                          oldSettledHeight: CGFloat,
                          newSettledHeight: CGFloat,
                          transition: CoreListTransition,
                          transactionTime: TimeInterval? = nil) -> ListAnimationMutation {
        let binding = bind(owner: owner, to: layer)
        knownOwners.insert(owner)
        let time = transactionTime ?? now()
        let mutation = model.transitionHeight(
            owner: owner,
            oldSettledHeight: oldSettledHeight,
            newSettledHeight: newSettledHeight,
            at: time,
            transition: transition.scaled(by: durationFactor())
        )
        apply(mutation, owner: owner, property: .height,
              layer: layer, binding: binding, removesOwner: false,
              cleanup: nil)
        return mutation
    }

    @discardableResult
    func transitionWidth(identity: AnyHashable,
                         layer: CALayer,
                         oldSettledWidth: CGFloat,
                         newSettledWidth: CGFloat,
                         transition: CoreListTransition,
                         transactionTime: TimeInterval? = nil) -> ListAnimationMutation {
        transitionWidth(owner: .live(identity),
                        layer: layer,
                        oldSettledWidth: oldSettledWidth,
                        newSettledWidth: newSettledWidth,
                        transition: transition,
                        transactionTime: transactionTime)
    }

    @discardableResult
    func transitionWidth(owner: ListAnimationOwner,
                         layer: CALayer,
                         oldSettledWidth: CGFloat,
                         newSettledWidth: CGFloat,
                         transition: CoreListTransition,
                         transactionTime: TimeInterval? = nil) -> ListAnimationMutation {
        let binding = bind(owner: owner, to: layer)
        knownOwners.insert(owner)
        let mutation = model.transitionWidth(
            owner: owner,
            oldSettledWidth: oldSettledWidth,
            newSettledWidth: newSettledWidth,
            at: transactionTime ?? now(),
            transition: transition.scaled(by: durationFactor())
        )
        apply(mutation, owner: owner, property: .width,
              layer: layer, binding: binding, removesOwner: false,
              cleanup: nil)
        return mutation
    }

    @discardableResult
    func insert(identity: AnyHashable,
                layer: CALayer,
                transition: CoreListTransition,
                transactionTime: TimeInterval? = nil) -> ListAnimationMutation {
        insert(owner: .live(identity),
               layer: layer,
               transition: transition,
               transactionTime: transactionTime)
    }

    @discardableResult
    func insert(owner: ListAnimationOwner,
                layer: CALayer,
                transition: CoreListTransition,
                transactionTime: TimeInterval? = nil) -> ListAnimationMutation {
        let binding = bind(owner: owner, to: layer)
        knownOwners.insert(owner)
        let mutation = model.beginInsertion(
            owner: owner,
            width: layer.bounds.width,
            height: layer.bounds.height,
            at: transactionTime ?? now(),
            transition: transition.scaled(by: durationFactor())
        )
        apply(mutation, owner: owner, property: .opacity,
              layer: layer, binding: binding, removesOwner: false,
              cleanup: nil)
        return mutation
    }

    @discardableResult
    func makeExit(identity: AnyHashable,
                  layer: CALayer,
                  contentY: CGFloat,
                  transition: CoreListTransition,
                  transactionTime: TimeInterval? = nil,
                  fadesOut: Bool = true,
                  completion: @escaping () -> Void) -> ListAnimationOwner {
        makeExit(owner: .live(identity),
                 layer: layer,
                 contentY: contentY,
                 transition: transition,
                 transactionTime: transactionTime,
                 fadesOut: fadesOut,
                 completion: completion)
    }

    @discardableResult
    func makeExit(owner liveOwner: ListAnimationOwner,
                  layer: CALayer,
                  contentY: CGFloat,
                  transition: CoreListTransition,
                  transactionTime: TimeInterval? = nil,
                  fadesOut: Bool = true,
                  completion: @escaping () -> Void) -> ListAnimationOwner {
        _ = bind(owner: liveOwner, to: layer)
        knownOwners.insert(liveOwner)

        let exit = model.beginExit(
            from: liveOwner,
            at: transactionTime ?? now(),
            transition: transition.scaled(by: durationFactor()),
            fadesOut: fadesOut
        )
        // Detached layers store their sampled horizontal position absolutely.
        // Their new owner therefore starts with no additive x correction.
        _ = model.settle(owner: exit.owner, property: .positionX)
        invalidateBinding(for: liveOwner, removeAnimations: true)
        knownOwners.remove(liveOwner)

        let binding = bind(owner: exit.owner, to: layer)
        knownOwners.insert(exit.owner)
        writePositionY(contentY, on: layer)
        writeWidth(exit.width, on: layer)
        writeHeight(exit.height, on: layer)
        apply(exit.opacityMutation, owner: exit.owner, property: .opacity,
              layer: layer, binding: binding, removesOwner: true,
              cleanup: completion)
        return exit.owner
    }

    @discardableResult
    func makeTransient(identity: AnyHashable,
                       layer: CALayer,
                       contentY: CGFloat,
                       transactionTime: TimeInterval? = nil) -> ListAnimationOwner {
        let liveOwner = ListAnimationOwner.live(identity)
        _ = bind(owner: liveOwner, to: layer)
        knownOwners.insert(liveOwner)
        let time = transactionTime ?? now()
        let transientOwner = model.beginTransient(from: liveOwner, at: time)
        let width = model.value(for: transientOwner, property: .width, at: time) ?? 0
        let height = model.value(for: transientOwner, property: .height, at: time) ?? 0
        let opacity = model.value(for: transientOwner, property: .opacity, at: time) ?? 1
        _ = model.settle(owner: transientOwner, property: .positionX)

        unbindPreservingOwner(liveOwner, layer: layer, at: time)
        _ = bind(owner: transientOwner, to: layer)
        knownOwners.insert(transientOwner)
        writePositionY(contentY, on: layer)
        writeWidth(width, on: layer)
        writeHeight(height, on: layer)
        writeOpacity(opacity, on: layer)
        return transientOwner
    }

    func removeTransient(owner: ListAnimationOwner, layer: CALayer) {
        guard case .transient = owner,
              let binding = bindings[owner],
              binding.value === layer
        else { return }
        invalidateBinding(for: owner, removeAnimations: true)
        model.remove(owner)
        knownOwners.remove(owner)
    }

    func removeGhostBlock(owner: ListAnimationOwner, layer: CALayer) {
        guard owner.isGhostBlock,
              let binding = bindings[owner],
              binding.value === layer else { return }
        invalidateBinding(for: owner, removeAnimations: true)
        model.remove(owner)
        knownOwners.remove(owner)
    }

    func unbind(identity: AnyHashable,
                layer: CALayer,
                at time: TimeInterval? = nil) {
        unbind(owner: .live(identity), layer: layer, at: time)
    }

    func unbind(owner: ListAnimationOwner,
                layer: CALayer,
                at time: TimeInterval? = nil) {
        guard let binding = bindings[owner], binding.value === layer else { return }
        removeModelAnimations(from: layer)
        bindings.removeValue(forKey: owner)
        discardPendingCompletions(boundTo: binding)
        let unbindTime = time ?? now()
        scheduleUnboundTrackReaps(for: owner, at: unbindTime)
        pruneUnboundSettledLiveOwner(owner, at: unbindTime)
    }

    func rebind(identity: AnyHashable, layer: CALayer) {
        let owner = ListAnimationOwner.live(identity)
        let freshSettledWidth = layer.bounds.width
        let freshSettledHeight = layer.bounds.height
        let binding = bind(owner: owner, to: layer)
        knownOwners.insert(owner)
        let time = now()

        if model.reconcileWidthForRebind(
            owner: owner,
            freshSettledWidth: freshSettledWidth
        ) {
            discardPendingCompletions(owner: owner, property: .width)
            compiler.remove(property: .width, from: layer)
        }

        if model.reconcileHeightForRebind(
            owner: owner,
            freshSettledHeight: freshSettledHeight
        ) {
            discardPendingCompletions(owner: owner, property: .height)
            compiler.remove(property: .height, from: layer)
        }

        for property in [ListAnimatedProperty.positionX, .positionY, .width, .height, .opacity] {
            guard let track = model.track(for: owner, property: property) else {
                if property != .positionX && property != .positionY,
                   let endpoint = model.value(for: owner, property: property, at: time) {
                    writeEndpoint(endpoint, property: property, on: layer)
                }
                continue
            }
            guard !track.isComplete(at: time) else {
                _ = model.complete(owner: owner, property: property,
                                   generation: track.generation, at: time)
                compiler.remove(property: property, from: layer)
                writeEndpoint(track.to, property: property, on: layer)
                continue
            }
            writeEndpoint(track.to, property: property, on: layer)
            install(track, owner: owner, property: property,
                    layer: layer, binding: binding,
                    removesOwner: false, cleanup: nil)
        }
    }

    func removeLive(identity: AnyHashable) {
        let owner = ListAnimationOwner.live(identity)
        invalidateBinding(for: owner, removeAnimations: true)
        model.remove(owner)
        knownOwners.remove(owner)
    }

    func positionOffset(identity: AnyHashable, at time: TimeInterval) -> CGFloat? {
        model.value(for: .live(identity), property: .positionY, at: time)
    }

    func positionOffsetX(identity: AnyHashable, at time: TimeInterval) -> CGFloat? {
        model.value(for: .live(identity), property: .positionX, at: time)
    }

    func width(identity: AnyHashable, at time: TimeInterval) -> CGFloat? {
        model.value(for: .live(identity), property: .width, at: time)
    }

    func ghostBlockOffset(owner: ListAnimationOwner,
                          at time: TimeInterval) -> CGFloat? {
        guard owner.isGhostBlock else { return nil }
        return model.value(for: owner, property: .positionY, at: time)
    }

    func height(identity: AnyHashable, at time: TimeInterval) -> CGFloat? {
        model.value(for: .live(identity), property: .height, at: time)
    }

    func opacity(owner: ListAnimationOwner, at time: TimeInterval) -> CGFloat? {
        model.value(for: owner, property: .opacity, at: time)
    }

    func positionOffset(owner: ListAnimationOwner, at time: TimeInterval) -> CGFloat? {
        model.value(for: owner, property: .positionY, at: time)
    }

    /// Whether an owner currently has a live layer binding. Test affordance; the pass itself never
    /// needs to ask.
    func isBound(owner: ListAnimationOwner) -> Bool {
        bindings[owner]?.value != nil
    }

    func width(owner: ListAnimationOwner, at time: TimeInterval) -> CGFloat? {
        model.value(for: owner, property: .width, at: time)
    }

    func height(owner: ListAnimationOwner, at time: TimeInterval) -> CGFloat? {
        model.value(for: owner, property: .height, at: time)
    }

    func viewportOffset(at time: TimeInterval) -> CGFloat {
        model.value(for: .viewport, property: .viewportOffset, at: time) ?? 0
    }

    func hasActiveAnimations(at time: TimeInterval) -> Bool {
        knownOwners.contains { owner in
            [ListAnimatedProperty.viewportOffset, .positionX, .positionY,
             .width, .height, .opacity].contains { property in
                guard let track = model.track(for: owner, property: property) else {
                    return false
                }
                return !track.isComplete(at: time)
            }
        }
    }

    func activeUnboundPositionIdentities(at time: TimeInterval) -> [AnyHashable] {
        knownOwners.compactMap { owner in
            guard case let .live(identity) = owner,
                  bindings[owner] == nil,
                  let track = model.track(for: owner, property: .positionY),
                  !track.isComplete(at: time)
            else { return nil }
            return identity
        }
    }

    @discardableResult
    func settleUnboundPosition(identity: AnyHashable,
                               at time: TimeInterval) -> Bool {
        let owner = ListAnimationOwner.live(identity)
        guard bindings[owner] == nil else { return false }
        discardPendingCompletions(owner: owner, property: .positionY)
        let settled = model.settle(owner: owner, property: .positionY)
        pruneUnboundSettledLiveOwner(owner, at: time)
        return settled
    }

    func reapSettledTracks() {
        let time = now()
        let completed = pendingCompletions.compactMap { serial, pending -> UInt64? in
            guard let track = model.track(for: pending.owner, property: pending.property),
                  track.generation == pending.generation,
                  track.isComplete(at: time)
            else { return nil }
            return serial
        }
        for serial in completed.sorted() {
            finalize(serial, at: time)
        }
        model.reap(at: time)
        for owner in Array(knownOwners) {
            pruneUnboundSettledLiveOwner(owner, at: time)
        }
    }

    func reset() {
        for binding in bindings.values {
            if let layer = binding.value {
                removeModelAnimations(from: layer)
            }
        }
        bindings.removeAll()
        knownOwners.removeAll()
        pendingCompletions.removeAll()
        model.reset()
    }

    private func duration(_ logical: TimeInterval) -> TimeInterval {
        max(0, logical * durationFactor())
    }

    private func apply(_ mutation: ListAnimationMutation,
                       owner: ListAnimationOwner,
                       property: ListAnimatedProperty,
                       layer: CALayer,
                       binding: WeakLayer,
                       removesOwner: Bool,
                       cleanup: (() -> Void)?) {
        switch mutation {
        case .unchanged:
            return
        case let .immediate(value):
            discardPendingCompletions(owner: owner, property: property)
            writeEndpoint(value, property: property, on: layer)
            compiler.remove(property: property, from: layer)
            if removesOwner {
                finishOwner(owner, binding: binding, cleanup: cleanup)
            }
        case let .started(track):
            writeEndpoint(track.to, property: property, on: layer)
            install(track, owner: owner, property: property,
                    layer: layer, binding: binding,
                    removesOwner: removesOwner, cleanup: cleanup)
        }
    }

    private func install(_ track: ListAnimationTrack,
                         owner: ListAnimationOwner,
                         property: ListAnimatedProperty,
                         layer: CALayer,
                         binding: WeakLayer,
                         removesOwner: Bool,
                         cleanup: (() -> Void)?) {
        discardPendingCompletions(owner: owner, property: property)
        nextCompletionSerial += 1
        let serial = nextCompletionSerial
        pendingCompletions[serial] = PendingCompletion(
            owner: owner,
            property: property,
            generation: track.generation,
            binding: binding,
            removesOwner: removesOwner,
            cleanup: cleanup
        )
        let completion = { [weak self] in
            guard let self else { return }
            self.finalize(serial, at: self.now())
        }
        if let animationInstaller {
            animationInstaller(track, property, layer, completion)
        } else {
            compiler.install(track, property: property, on: layer,
                             completion: completion)
        }
        if track.deliversNoCoreAnimationCompletion {
            scheduleAnalyticCompletion(serial: serial,
                                       deadline: track.startTime + track.duration)
        }
    }

    /// Drive `finalize` from the analytic deadline for a track Core Animation will never call back
    /// for. **An animation whose `fromValue` equals its `toValue` produces no visual change, so the
    /// render server never runs it and `animationDidStop` is never sent** — the animation just sits
    /// on the layer (`isRemovedOnCompletion = false`) forever.
    ///
    /// That matters because a completion here is not only bookkeeping: it is the teardown trigger for
    /// every tenant of the exit overlay. Three of them ride equal-endpoint tracks by design, and all
    /// three stranded stale rows on top of live content:
    ///
    /// - a **non-fading exit** (`beginExit(fadesOut: false)`, i.e. every departing row of a
    ///   full-replace carousel) installs `opacity: o -> o` purely to own a teardown deadline, so the
    ///   whole outgoing strip stayed parked in `exitOverlay`;
    /// - a **viewport re-target onto the displacement already in flight** yields
    ///   `viewportOffset: 0 -> 0`, and `finishViewportGeneration` never ran — stranding its viewport
    ///   carries and every crossing carry that had migrated onto that generation.
    ///
    /// The model is the presentation authority and the compiler is an output renderer, so a
    /// model-owned completion must not depend on whether Core Animation found the animation worth
    /// running. Scheduled only for the tracks that need it — arming a timer per animated property
    /// would cost dozens of timers per pass for no gain, since a track that moves does get its
    /// callback. `finalize` removes the pending record first, so a later CA callback for the same
    /// serial is an exact no-op and the two paths cannot double-fire.
    private func scheduleAnalyticCompletion(serial: UInt64, deadline: TimeInterval) {
        // One shot: `scheduleAfter` never fires early, so `now()` inside the block is at or past the
        // deadline and `track.isComplete(at:)` therefore holds — the re-arm loop that
        // `scheduleUnboundTrackReap` needs (it races an unbind, not a deadline) has no analogue here.
        scheduleAfter(max(0, deadline - now())) { [weak self] in
            guard let self, self.pendingCompletions[serial] != nil else { return }
            self.finalize(serial, at: self.now())
        }
    }

    private func finalize(_ serial: UInt64, at time: TimeInterval) {
        guard let pending = pendingCompletions.removeValue(forKey: serial),
              bindings[pending.owner] === pending.binding,
              let layer = pending.binding.value
        else { return }

        guard model.complete(owner: pending.owner,
                             property: pending.property,
                             generation: pending.generation,
                             at: time) else {
            if model.track(for: pending.owner, property: pending.property)?.generation
                == pending.generation {
                pendingCompletions[serial] = pending
            }
            return
        }

        compiler.remove(property: pending.property, from: layer)
        if pending.removesOwner {
            finishOwner(pending.owner, binding: pending.binding,
                        cleanup: pending.cleanup)
        } else {
            pending.cleanup?()
        }
    }

    private func finishOwner(_ owner: ListAnimationOwner,
                             binding: WeakLayer,
                             cleanup: (() -> Void)?) {
        if bindings[owner] === binding {
            bindings.removeValue(forKey: owner)
        }
        discardPendingCompletions(boundTo: binding)
        model.remove(owner)
        knownOwners.remove(owner)
        cleanup?()
    }

    @discardableResult
    private func bind(owner: ListAnimationOwner, to layer: CALayer) -> WeakLayer {
        if let current = bindings[owner], current.value === layer {
            return current
        }

        if bindings[owner] != nil {
            invalidateBinding(for: owner, removeAnimations: true)
        }

        let previousOwners = bindings.compactMap { boundOwner, binding in
            binding.value === layer ? boundOwner : nil
        }
        if !previousOwners.isEmpty {
            removeModelAnimations(from: layer)
        }
        for previousOwner in previousOwners {
            invalidateBinding(for: previousOwner, removeAnimations: false)
            if !previousOwner.isLive {
                model.remove(previousOwner)
                knownOwners.remove(previousOwner)
            }
        }

        let binding = WeakLayer(layer)
        bindings[owner] = binding
        return binding
    }

    private func invalidateBinding(for owner: ListAnimationOwner,
                                   removeAnimations: Bool) {
        guard let binding = bindings.removeValue(forKey: owner) else { return }
        if removeAnimations, let layer = binding.value {
            removeModelAnimations(from: layer)
        }
        discardPendingCompletions(boundTo: binding)
    }

    private func unbindPreservingOwner(_ owner: ListAnimationOwner,
                                       layer: CALayer,
                                       at time: TimeInterval) {
        guard let binding = bindings[owner], binding.value === layer else { return }
        removeModelAnimations(from: layer)
        bindings.removeValue(forKey: owner)
        discardPendingCompletions(boundTo: binding)
        scheduleUnboundTrackReaps(for: owner, at: time)
        pruneUnboundSettledLiveOwner(owner, at: time)
    }

    private func discardPendingCompletions(owner: ListAnimationOwner,
                                           property: ListAnimatedProperty) {
        pendingCompletions = pendingCompletions.filter {
            $0.value.owner != owner || $0.value.property != property
        }
    }

    private func discardPendingCompletions(boundTo binding: WeakLayer) {
        pendingCompletions = pendingCompletions.filter { $0.value.binding !== binding }
    }

    private func pruneUnboundSettledLiveOwner(_ owner: ListAnimationOwner,
                                              at time: TimeInterval) {
        // `ownsLiveElement`, not `isLive`: an unbound attachment owner must be pruned on exactly the
        // same terms as an unbound row owner, or its settled state outlives every reference to it.
        guard owner.ownsLiveElement, bindings[owner] == nil else { return }
        model.reap(owner: owner, at: time)
        let hasTrack = [ListAnimatedProperty.positionX, .positionY,
                        .width, .height, .opacity].contains {
            model.track(for: owner, property: $0) != nil
        }
        guard !hasTrack else { return }
        model.remove(owner)
        knownOwners.remove(owner)
    }

    private func scheduleUnboundTrackReaps(for owner: ListAnimationOwner,
                                           at time: TimeInterval) {
        for property in [ListAnimatedProperty.positionX, .positionY,
                         .width, .height, .opacity] {
            guard let track = model.track(for: owner, property: property),
                  !track.isComplete(at: time)
            else { continue }
            scheduleUnboundTrackReap(owner: owner,
                                     property: property,
                                     generation: track.generation,
                                     deadline: track.startTime + track.duration,
                                     from: time)
        }
    }

    private func scheduleUnboundTrackReap(owner: ListAnimationOwner,
                                          property: ListAnimatedProperty,
                                          generation: UInt64,
                                          deadline: TimeInterval,
                                          from time: TimeInterval) {
        scheduleAfter(max(0, deadline - time)) { [weak self] in
            guard let self,
                  self.bindings[owner] == nil,
                  let track = self.model.track(for: owner, property: property),
                  track.generation == generation
            else { return }

            let callbackTime = self.now()
            guard track.isComplete(at: callbackTime) else {
                self.scheduleUnboundTrackReap(owner: owner,
                                              property: property,
                                              generation: generation,
                                              deadline: deadline,
                                              from: callbackTime)
                return
            }

            _ = self.model.complete(owner: owner,
                                    property: property,
                                    generation: generation,
                                    at: callbackTime)
            self.pruneUnboundSettledLiveOwner(owner, at: callbackTime)
        }
    }

    private func removeModelAnimations(from layer: CALayer) {
        compiler.remove(property: .viewportOffset, from: layer)
        compiler.remove(property: .positionX, from: layer)
        compiler.remove(property: .positionY, from: layer)
        compiler.remove(property: .width, from: layer)
        compiler.remove(property: .height, from: layer)
        compiler.remove(property: .opacity, from: layer)
    }

    private func writeEndpoint(_ value: CGFloat,
                               property: ListAnimatedProperty,
                               on layer: CALayer) {
        switch property {
        case .viewportOffset:
            return
        case .positionX:
            return
        case .positionY:
            writePositionY(layer.position.y, on: layer)
        case .width:
            writeWidth(value, on: layer)
        case .height:
            writeHeight(value, on: layer)
        case .opacity:
            writeOpacity(value, on: layer)
        }
    }

    // These five write model-layer settled endpoints. They use `commit` directly rather than
    // `CoreListTransition.immediate.setPositionY(…)` and friends deliberately: those setters clear
    // the matching standard animation key (`position`, `opacity`, `bounds.size.height`) on their
    // immediate path, mirroring ComponentTransition — and the executor installs ITEM-VIEW animations
    // under exactly those keys. A settled write must not cancel a row's own fade or slide.
    //
    // They must also stay immediate for a second reason: this is the model path, whose duration was
    // already scaled by `durationFactor()`, and whose animation the compiler emits. Routing an
    // animated transition through here would scale again inside `CALayer.animate` and put a second
    // animation on the same property.

    private func writePositionY(_ value: CGFloat, on layer: CALayer) {
        layer.position.y = value
    }

    private func writePositionX(_ value: CGFloat, on layer: CALayer) {
        layer.position.x = value
    }

    private func writeOpacity(_ value: CGFloat, on layer: CALayer) {
        layer.opacity = Float(value)
    }

    private func writeHeight(_ value: CGFloat, on layer: CALayer) {
        layer.bounds.size.height = value
    }

    private func writeWidth(_ value: CGFloat, on layer: CALayer) {
        layer.bounds.size.width = value
    }
}
