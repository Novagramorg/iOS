import CoreGraphics
import Foundation

/// Replays a recorded gesture against the pure ScrollPhysics core. Pure (no UIKit).
enum ScrollReplay {
    /// Build a 2-axis ScrollPhysics from recorded geometry, anchored at `startOffset`.
    /// `c` is the rubber-band coefficient (0.55 touch / 0.715 trackpad — see `replay`).
    static func makePhysics(_ g: GestureRecording.Geometry, startOffset: CGPoint,
                            c: CGFloat = RubberBand.touchCoefficient) -> ScrollPhysics {
        let minX = OffsetMath.minOffset(insetLeadingTop: g.insetLeft, scale: g.scale)
        let maxX = OffsetMath.maxOffset(contentSize: g.contentWidth, insetTrailingBottom: g.insetRight,
                                        boundsSize: g.boundsWidth, minOffset: minX, scale: g.scale)
        let minY = OffsetMath.minOffset(insetLeadingTop: g.insetTop, scale: g.scale)
        let maxY = OffsetMath.maxOffset(contentSize: g.contentHeight, insetTrailingBottom: g.insetBottom,
                                        boundsSize: g.boundsHeight, minOffset: minY, scale: g.scale)
        return ScrollPhysics(
            x: ScrollAxis(offset: startOffset.x, min: minX, max: maxX, range: g.boundsWidth,
                          rate: g.decelerationRate, scale: g.scale, c: c),
            y: ScrollAxis(offset: startOffset.y, min: minY, max: maxY, range: g.boundsHeight,
                          rate: g.decelerationRate, scale: g.scale, c: c))
    }

    /// The replayable span: frames from the first `.dragging` frame onward. Leading idle frames
    /// (captured between tapping Record and the gesture actually starting) carry no input and
    /// must be dropped, or the fold would `endDrag` before any drag occurred.
    static func replayableFrames(_ rec: GestureRecording) -> ArraySlice<GestureRecording.Frame> {
        guard let start = rec.frames.firstIndex(where: { $0.phase == .dragging }) else { return [] }
        return rec.frames[start...]
    }

    /// Drive ScrollPhysics through the replayable frames; return the replayed offset per frame
    /// (index-aligned with `replayableFrames(rec)`).
    static func replay(_ rec: GestureRecording) -> [CGPoint] {
        let frames = replayableFrames(rec)
        guard let first = frames.first else { return [] }
        // translationInView is cumulative from touch-down: offset₀ = anchor − translation₀
        // ⇒ anchor = offset₀ + translation₀.
        let anchor = CGPoint(x: first.groundTruthOffset.x + first.translation.x,
                             y: first.groundTruthOffset.y + first.translation.y)
        // Indirect (trackpad) gestures deliver no touches and use a looser overscroll rubber-band.
        // The signal is `touches.isEmpty`: every trackpad recording has `touches == 0`, every touch
        // recording has many. (Caveat: a pre-`touches`-field recording also decodes to `[]` — see
        // GestureRecording's `decodeIfPresent ?? []`; none are committed, and the touch fixtures'
        // c=0.55 replay bounds in ScrollPhysicsRegressionTests would break loudly if one slipped in.)
        let c = rec.touches.isEmpty ? RubberBand.trackpadCoefficient : RubberBand.touchCoefficient
        var p = makePhysics(rec.geometry, startOffset: anchor, c: c)
        p.beginDrag()
        var released = false
        var prevT = first.t
        let firstDecelStepMs = decelFrameDurationMs(frames)
        var out: [CGPoint] = []
        out.reserveCapacity(frames.count)
        for f in frames {
            switch f.phase {
            case .dragging:
                p.drag(translation: f.translation, recognizerVelocity: f.recognizerVelocity)
                out.append(CGPoint(x: p.x.offset, y: p.y.offset))
            case .decelerating:
                // UIScrollView's first decel step always integrates exactly one display frame:
                // `_endPanNormal` sets lastUpdateTime = now − 1/maxFPS then steps to now, regardless of
                // the actual release-to-first-frame gap. That one-frame decay (`rate^(1/maxFPS)`, ≈0.967
                // at 60Hz) scales the hand-off velocity before the bulk of the decel — without it the
                // landing overshoots ~3%. So the first step uses the steady decel-frame cadence, NOT
                // the recorded gap.
                let dtMs: CGFloat
                if !released {
                    _ = p.endDrag()
                    released = true
                    dtMs = firstDecelStepMs
                } else {
                    dtMs = CGFloat((f.t - prevT) * 1000)
                }
                out.append(p.step(dtMs: dtMs).written)
            }
            prevT = f.t
        }
        return out
    }

    /// The steady deceleration-frame cadence (≈ 1/maxFPS) — the median dt between consecutive
    /// decelerating frames. Used for the first decel step (see `replay`). Falls back to 1/60s.
    private static func decelFrameDurationMs(_ frames: ArraySlice<GestureRecording.Frame>) -> CGFloat {
        var dts: [CGFloat] = []
        var prev: GestureRecording.Frame?
        for f in frames {
            if let p = prev, p.phase == .decelerating, f.phase == .decelerating {
                dts.append(CGFloat((f.t - p.t) * 1000))
            }
            prev = f
        }
        guard !dts.isEmpty else { return 1000.0 / 60.0 }
        dts.sort()
        return dts[dts.count / 2]
    }

    /// Per-axis maximum absolute divergence between replay and recorded ground truth, over the
    /// replayable span (leading idle frames excluded).
    static func maxDivergence(_ rec: GestureRecording) -> CGPoint {
        let frames = replayableFrames(rec)
        let replayed = replay(rec)
        var mx: CGFloat = 0, my: CGFloat = 0
        for (f, r) in zip(frames, replayed) {
            mx = Swift.max(mx, abs(r.x - f.groundTruthOffset.x))
            my = Swift.max(my, abs(r.y - f.groundTruthOffset.y))
        }
        return CGPoint(x: mx, y: my)
    }
}
