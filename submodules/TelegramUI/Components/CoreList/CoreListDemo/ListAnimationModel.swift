import Foundation
import CoreGraphics

enum ListAnimationOwner: Hashable {
    case viewport
    case live(AnyHashable)
    case exit(UInt64)
    case transient(UInt64)
    case ghostBlock(UInt64)

    var isLive: Bool {
        if case .live = self { return true }
        return false
    }

    var isGhostBlock: Bool {
        if case .ghostBlock = self { return true }
        return false
    }
}

enum ListAnimatedProperty: Hashable {
    case viewportOffset
    case positionX
    case positionY
    case width
    case height
    case opacity
}

public enum ListAnimationCurve: Equatable {
    case smoothstep
    case easeOut

    func value(at phase: Double) -> Double {
        let x = min(max(phase, 0), 1)
        switch self {
        case .smoothstep:
            return x * x * (3 - 2 * x)
        case .easeOut:
            let inverse = 1 - x
            return 1 - inverse * inverse * inverse
        }
    }
}

public struct ListAnimationSpec: Equatable {
    public let duration: TimeInterval
    public let curve: ListAnimationCurve
    
    public init(duration: TimeInterval, curve: ListAnimationCurve) {
        self.duration = duration
        self.curve = curve
    }

    public static func smoothstep(duration: TimeInterval) -> Self {
        Self(duration: duration, curve: .smoothstep)
    }

    public static func easeOut(duration: TimeInterval) -> Self {
        Self(duration: duration, curve: .easeOut)
    }

    public func scaled(by factor: Double) -> Self {
        Self(duration: max(0, duration * factor), curve: curve)
    }
}

struct ListAnimationTrack: Equatable {
    let generation: UInt64
    let from: CGFloat
    let to: CGFloat
    let startTime: TimeInterval
    let duration: TimeInterval
    let curve: ListAnimationCurve

    init(generation: UInt64,
         from: CGFloat,
         to: CGFloat,
         startTime: TimeInterval,
         duration: TimeInterval,
         curve: ListAnimationCurve = .smoothstep) {
        self.generation = generation
        self.from = from
        self.to = to
        self.startTime = startTime
        self.duration = duration
        self.curve = curve
    }

    func value(at time: TimeInterval) -> CGFloat {
        guard duration > 0 else { return to }
        let x = min(max((time - startTime) / duration, 0), 1)
        let eased = curve.value(at: x)
        return from + (to - from) * CGFloat(eased)
    }

    func isComplete(at time: TimeInterval) -> Bool {
        duration <= 0 || time >= startTime + duration
    }
}

enum ListAnimationMutation: Equatable {
    case unchanged
    case immediate(value: CGFloat)
    case started(ListAnimationTrack)
}

struct ListAnimationExit: Equatable {
    let owner: ListAnimationOwner
    let positionX: CGFloat
    let positionY: CGFloat
    let width: CGFloat
    let height: CGFloat
    let opacityMutation: ListAnimationMutation
}

final class ListAnimationModel {
    private struct OwnerState {
        var viewportOffset: CGFloat
        var positionOffsetX: CGFloat
        var positionOffsetY: CGFloat
        var width: CGFloat
        var height: CGFloat
        var opacity: CGFloat
        var tracks: [ListAnimatedProperty: ListAnimationTrack]
    }

    private let positionEpsilon: CGFloat
    private var nextGeneration: UInt64 = 0
    private var nextExitSerial: UInt64 = 0
    private var nextTransientSerial: UInt64 = 0
    private var states: [ListAnimationOwner: OwnerState] = [:]

    var ownerCount: Int { states.count }

    init(positionEpsilon: CGFloat = 1e-6) {
        self.positionEpsilon = positionEpsilon
    }

    func seedViewport() {
        states[.viewport] = OwnerState(viewportOffset: 0,
                                       positionOffsetX: 0,
                                       positionOffsetY: 0,
                                       width: 0,
                                       height: 0,
                                       opacity: 1,
                                       tracks: [:])
    }

    func seedLive(owner: ListAnimationOwner,
                  positionOffset: CGFloat,
                  opacity: CGFloat,
                  height: CGFloat = 0) {
        seedLive(owner: owner,
                 positionOffsetX: 0,
                 positionOffsetY: positionOffset,
                 opacity: opacity,
                 width: 0,
                 height: height)
    }

    func seedLive(owner: ListAnimationOwner,
                  positionOffsetX: CGFloat,
                  positionOffsetY: CGFloat,
                  opacity: CGFloat,
                  width: CGFloat,
                  height: CGFloat) {
        precondition(owner.isLive)
        states[owner] = OwnerState(viewportOffset: 0,
                                   positionOffsetX: positionOffsetX,
                                   positionOffsetY: positionOffsetY,
                                   width: width,
                                   height: height,
                                   opacity: opacity,
                                   tracks: [:])
    }

    func seedGhostBlock(owner: ListAnimationOwner) {
        precondition(owner.isGhostBlock)
        states[owner] = OwnerState(viewportOffset: 0,
                                   positionOffsetX: 0,
                                   positionOffsetY: 0,
                                   width: 0,
                                   height: 0,
                                   opacity: 1,
                                   tracks: [:])
    }

    func transitionViewport(oldSettledOffset: CGFloat,
                            newSettledOffset: CGFloat,
                            at time: TimeInterval,
                            duration: TimeInterval) -> ListAnimationMutation {
        transitionViewport(oldSettledOffset: oldSettledOffset,
                           newSettledOffset: newSettledOffset,
                           at: time,
                           animation: .smoothstep(duration: duration))
    }

    func transitionViewport(oldSettledOffset: CGFloat,
                            newSettledOffset: CGFloat,
                            at time: TimeInterval,
                            animation: ListAnimationSpec) -> ListAnimationMutation {
        if states[.viewport] == nil { seedViewport() }
        guard abs(newSettledOffset - oldSettledOffset) > positionEpsilon else {
            return .unchanged
        }
        let correction = value(for: .viewport,
                               property: .viewportOffset,
                               at: time) ?? 0
        return replace(owner: .viewport,
                       property: .viewportOffset,
                       from: oldSettledOffset + correction - newSettledOffset,
                       to: 0,
                       at: time,
                       animation: animation)
    }

    func transitionPosition(owner: ListAnimationOwner,
                            oldSettledY: CGFloat,
                            newSettledY: CGFloat,
                            at time: TimeInterval,
                            duration: TimeInterval) -> ListAnimationMutation {
        transitionPosition(owner: owner,
                           oldSettledY: oldSettledY,
                           newSettledY: newSettledY,
                           at: time,
                           animation: .smoothstep(duration: duration))
    }

    func transitionPosition(owner: ListAnimationOwner,
                            oldSettledY: CGFloat,
                            newSettledY: CGFloat,
                            at time: TimeInterval,
                            animation: ListAnimationSpec) -> ListAnimationMutation {
        precondition(owner.isLive)
        ensureLive(owner)
        return transitionPositionOffset(owner: owner,
                                        oldSettledY: oldSettledY,
                                        newSettledY: newSettledY,
                                        at: time,
                                        animation: animation)
    }

    func transitionPositionX(owner: ListAnimationOwner,
                             oldSettledX: CGFloat,
                             newSettledX: CGFloat,
                             at time: TimeInterval,
                             animation: ListAnimationSpec) -> ListAnimationMutation {
        if owner.isLive { ensureLive(owner) }
        guard states[owner] != nil else { return .unchanged }
        guard abs(newSettledX - oldSettledX) > positionEpsilon else { return .unchanged }
        let currentOffset = value(for: owner, property: .positionX, at: time) ?? 0
        return replace(owner: owner,
                       property: .positionX,
                       from: oldSettledX + currentOffset - newSettledX,
                       to: 0,
                       at: time,
                       animation: animation)
    }

    func transitionGhostBlock(owner: ListAnimationOwner,
                              oldSettledY: CGFloat,
                              newSettledY: CGFloat,
                              at time: TimeInterval,
                              duration: TimeInterval) -> ListAnimationMutation {
        precondition(owner.isGhostBlock)
        if states[owner] == nil { seedGhostBlock(owner: owner) }
        return transitionPositionOffset(owner: owner,
                                        oldSettledY: oldSettledY,
                                        newSettledY: newSettledY,
                                        at: time,
                                        duration: duration)
    }

    private func transitionPositionOffset(owner: ListAnimationOwner,
                                          oldSettledY: CGFloat,
                                          newSettledY: CGFloat,
                                          at time: TimeInterval,
                                          duration: TimeInterval) -> ListAnimationMutation {
        transitionPositionOffset(owner: owner,
                                 oldSettledY: oldSettledY,
                                 newSettledY: newSettledY,
                                 at: time,
                                 animation: .smoothstep(duration: duration))
    }

    private func transitionPositionOffset(owner: ListAnimationOwner,
                                          oldSettledY: CGFloat,
                                          newSettledY: CGFloat,
                                          at time: TimeInterval,
                                          animation: ListAnimationSpec) -> ListAnimationMutation {
        guard abs(newSettledY - oldSettledY) > positionEpsilon else { return .unchanged }
        let currentOffset = value(for: owner, property: .positionY, at: time) ?? 0
        let currentVisibleY = oldSettledY + currentOffset
        return replace(owner: owner,
                       property: .positionY,
                       from: currentVisibleY - newSettledY,
                       to: 0,
                       at: time,
                       animation: animation)
    }

    func transitionHeight(owner: ListAnimationOwner,
                          oldSettledHeight: CGFloat,
                          newSettledHeight: CGFloat,
                          at time: TimeInterval,
                          duration: TimeInterval) -> ListAnimationMutation {
        transitionHeight(owner: owner,
                         oldSettledHeight: oldSettledHeight,
                         newSettledHeight: newSettledHeight,
                         at: time,
                         animation: .smoothstep(duration: duration))
    }

    func transitionHeight(owner: ListAnimationOwner,
                          oldSettledHeight: CGFloat,
                          newSettledHeight: CGFloat,
                          at time: TimeInterval,
                          animation: ListAnimationSpec) -> ListAnimationMutation {
        precondition(owner.isLive)
        ensureLive(owner, height: oldSettledHeight)
        guard abs(newSettledHeight - oldSettledHeight) > positionEpsilon else {
            return .unchanged
        }
        let currentHeight = value(for: owner, property: .height, at: time)
            ?? oldSettledHeight
        return replace(owner: owner, property: .height,
                       from: currentHeight, to: newSettledHeight,
                       at: time, animation: animation)
    }

    func transitionWidth(owner: ListAnimationOwner,
                         oldSettledWidth: CGFloat,
                         newSettledWidth: CGFloat,
                         at time: TimeInterval,
                         animation: ListAnimationSpec) -> ListAnimationMutation {
        if owner.isLive { ensureLive(owner, width: oldSettledWidth) }
        guard states[owner] != nil else { return .unchanged }
        guard abs(newSettledWidth - oldSettledWidth) > positionEpsilon else {
            return .unchanged
        }
        let currentWidth = value(for: owner, property: .width, at: time)
            ?? oldSettledWidth
        return replace(owner: owner,
                       property: .width,
                       from: currentWidth,
                       to: newSettledWidth,
                       at: time,
                       animation: animation)
    }

    func transitionOpacity(owner: ListAnimationOwner,
                           to target: CGFloat,
                           at time: TimeInterval,
                           duration: TimeInterval) -> ListAnimationMutation {
        guard let state = states[owner] else { return .unchanged }
        guard state.opacity != target else { return .unchanged }
        let from = value(for: owner, property: .opacity, at: time) ?? state.opacity
        return replace(owner: owner, property: .opacity, from: from, to: target,
                       at: time, duration: duration)
    }

    func beginInsertion(owner: ListAnimationOwner,
                        width: CGFloat,
                        height: CGFloat,
                        at time: TimeInterval,
                        duration: TimeInterval) -> ListAnimationMutation {
        precondition(owner.isLive)
        seedLive(owner: owner,
                 positionOffsetX: 0,
                 positionOffsetY: 0,
                 opacity: 0,
                 width: width,
                 height: height)
        return replace(owner: owner, property: .opacity, from: 0, to: 1,
                       at: time, duration: duration)
    }

    func beginExit(from owner: ListAnimationOwner,
                   at time: TimeInterval,
                   duration: TimeInterval) -> ListAnimationExit {
        precondition(owner.isLive)
        ensureLive(owner)

        let positionX = value(for: owner, property: .positionX, at: time) ?? 0
        let positionY = value(for: owner, property: .positionY, at: time) ?? 0
        let width = value(for: owner, property: .width, at: time) ?? 0
        let height = value(for: owner, property: .height, at: time) ?? 0
        let opacity = value(for: owner, property: .opacity, at: time) ?? 1
        states.removeValue(forKey: owner)

        nextExitSerial += 1
        let exitOwner = ListAnimationOwner.exit(nextExitSerial)
        states[exitOwner] = OwnerState(viewportOffset: 0,
                                       positionOffsetX: positionX,
                                       positionOffsetY: positionY,
                                       width: width,
                                       height: height,
                                       opacity: opacity,
                                       tracks: [:])
        let mutation = replace(owner: exitOwner, property: .opacity,
                               from: opacity, to: 0,
                               at: time, duration: duration)
        return ListAnimationExit(owner: exitOwner,
                                 positionX: positionX,
                                 positionY: positionY,
                                 width: width,
                                 height: height,
                                 opacityMutation: mutation)
    }

    func beginTransient(from owner: ListAnimationOwner,
                        at time: TimeInterval) -> ListAnimationOwner {
        precondition(owner.isLive)
        ensureLive(owner)

        let positionX = value(for: owner, property: .positionX, at: time) ?? 0
        let positionY = value(for: owner, property: .positionY, at: time) ?? 0
        let width = value(for: owner, property: .width, at: time) ?? 0
        let height = value(for: owner, property: .height, at: time) ?? 0
        let opacity = value(for: owner, property: .opacity, at: time) ?? 1
        nextTransientSerial += 1
        let transientOwner = ListAnimationOwner.transient(nextTransientSerial)
        states[transientOwner] = OwnerState(viewportOffset: 0,
                                            positionOffsetX: positionX,
                                            positionOffsetY: positionY,
                                            width: width,
                                            height: height,
                                            opacity: opacity,
                                            tracks: [:])
        return transientOwner
    }

    func track(for owner: ListAnimationOwner,
               property: ListAnimatedProperty) -> ListAnimationTrack? {
        states[owner]?.tracks[property]
    }

    func value(for owner: ListAnimationOwner,
               property: ListAnimatedProperty,
               at time: TimeInterval) -> CGFloat? {
        guard let state = states[owner] else { return nil }
        if let track = state.tracks[property] {
            return track.value(at: time)
        }
        switch property {
        case .viewportOffset: return state.viewportOffset
        case .positionX: return state.positionOffsetX
        case .positionY: return state.positionOffsetY
        case .width: return state.width
        case .height: return state.height
        case .opacity: return state.opacity
        }
    }

    @discardableResult
    func complete(owner: ListAnimationOwner,
                  property: ListAnimatedProperty,
                  generation: UInt64,
                  at time: TimeInterval) -> Bool {
        guard let track = states[owner]?.tracks[property],
              track.generation == generation,
              track.isComplete(at: time)
        else { return false }
        states[owner]?.tracks.removeValue(forKey: property)
        return true
    }

    func reap(at time: TimeInterval) {
        let completed = states.flatMap { owner, state in
            state.tracks.compactMap { property, track in
                track.isComplete(at: time) ? (owner, property, track.generation) : nil
            }
        }
        for (owner, property, generation) in completed {
            _ = complete(owner: owner, property: property,
                         generation: generation, at: time)
        }
    }

    func reap(owner: ListAnimationOwner, at time: TimeInterval) {
        guard let state = states[owner] else { return }
        let completed = state.tracks.compactMap { property, track in
            track.isComplete(at: time) ? (property, track.generation) : nil
        }
        for (property, generation) in completed {
            _ = complete(owner: owner, property: property,
                         generation: generation, at: time)
        }
    }

    func contains(_ owner: ListAnimationOwner) -> Bool {
        states[owner] != nil
    }

    func remove(_ owner: ListAnimationOwner) {
        states.removeValue(forKey: owner)
    }

    @discardableResult
    func settle(owner: ListAnimationOwner,
                property: ListAnimatedProperty) -> Bool {
        guard states[owner] != nil else { return false }
        let removed = states[owner]?.tracks.removeValue(forKey: property) != nil
        if property == .viewportOffset {
            states[owner]?.viewportOffset = 0
        } else if property == .positionX {
            states[owner]?.positionOffsetX = 0
        } else if property == .positionY {
            states[owner]?.positionOffsetY = 0
        }
        return removed
    }

    @discardableResult
    func reconcileHeightForRebind(owner: ListAnimationOwner,
                                  freshSettledHeight: CGFloat) -> Bool {
        guard let state = states[owner],
              abs(state.height - freshSettledHeight) > positionEpsilon
        else { return false }
        states[owner]?.height = freshSettledHeight
        states[owner]?.tracks.removeValue(forKey: .height)
        return true
    }

    @discardableResult
    func reconcileWidthForRebind(owner: ListAnimationOwner,
                                 freshSettledWidth: CGFloat) -> Bool {
        guard let state = states[owner],
              abs(state.width - freshSettledWidth) > positionEpsilon
        else { return false }
        states[owner]?.width = freshSettledWidth
        states[owner]?.tracks.removeValue(forKey: .width)
        return true
    }

    func reset() {
        states.removeAll()
    }

    private func ensureLive(_ owner: ListAnimationOwner,
                            width: CGFloat = 0,
                            height: CGFloat = 0) {
        guard states[owner] == nil else { return }
        states[owner] = OwnerState(viewportOffset: 0,
                                   positionOffsetX: 0,
                                   positionOffsetY: 0,
                                   width: width,
                                   height: height,
                                   opacity: 1,
                                   tracks: [:])
    }

    private func replace(owner: ListAnimationOwner,
                         property: ListAnimatedProperty,
                         from: CGFloat,
                         to: CGFloat,
                         at time: TimeInterval,
                         duration: TimeInterval) -> ListAnimationMutation {
        replace(owner: owner,
                property: property,
                from: from,
                to: to,
                at: time,
                animation: .smoothstep(duration: duration))
    }

    private func replace(owner: ListAnimationOwner,
                         property: ListAnimatedProperty,
                         from: CGFloat,
                         to: CGFloat,
                         at time: TimeInterval,
                         animation: ListAnimationSpec) -> ListAnimationMutation {
        nextGeneration += 1
        setStoredValue(to, for: owner, property: property)

        guard animation.duration > 0 else {
            states[owner]?.tracks.removeValue(forKey: property)
            return .immediate(value: to)
        }

        let track = ListAnimationTrack(generation: nextGeneration,
                                       from: from,
                                       to: to,
                                       startTime: time,
                                       duration: animation.duration,
                                       curve: animation.curve)
        states[owner]?.tracks[property] = track
        return .started(track)
    }

    private func setStoredValue(_ value: CGFloat,
                                for owner: ListAnimationOwner,
                                property: ListAnimatedProperty) {
        switch property {
        case .viewportOffset: states[owner]?.viewportOffset = value
        case .positionX: states[owner]?.positionOffsetX = value
        case .positionY: states[owner]?.positionOffsetY = value
        case .width: states[owner]?.width = value
        case .height: states[owner]?.height = value
        case .opacity: states[owner]?.opacity = value
        }
    }
}
