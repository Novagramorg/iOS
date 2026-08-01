import CoreGraphics

/// An attachment's settled Y as a function of the engine offset, in FRAME space (the space of
/// `CoreVirtualListView.Window.Item.frame`).
///
/// The function is piecewise linear with at most two breakpoints, for EITHER edge:
///
///     offset <= lowBreakpoint    ->  lo                              (constant; rides content)
///     between                    ->  anchor + offset - contentBase   (parked; slope +1)
///     offset >= highBreakpoint   ->  hi                              (constant; pushed out)
///
/// This type is the single definition of the sticky math. The per-frame path evaluates
/// `y(atOffset:)`; the baked-keyframe path composes the same map with a scroll trajectory. Writing
/// the math a second time is how this feature rots.
struct AttachmentOffsetMap {
    /// Frame-space low limit: the band's top.
    let lo: CGFloat
    /// Frame-space high limit: the band's bottom minus the attachment's height.
    let hi: CGFloat
    /// The display anchor, in SCREEN space: `displayTop` for `.top`, `displayBottom - height` for
    /// `.bottom`.
    let anchor: CGFloat
    /// Screen y of frame-space 0 at offset 0: `containerOriginY - window.minY`.
    let contentBase: CGFloat
    let edge: CoreListAttachmentEdge
    let isFloating: Bool

    init(bandTop: CGFloat,
         bandBottom: CGFloat,
         height: CGFloat,
         anchor: CGFloat,
         contentBase: CGFloat,
         edge: CoreListAttachmentEdge,
         isFloating: Bool) {
        self.lo = bandTop
        self.hi = bandBottom - height
        self.anchor = anchor
        self.contentBase = contentBase
        self.edge = edge
        self.isFloating = isFloating
    }

    /// The display anchor expressed in frame space at a given engine offset.
    func anchorInFrameSpace(atOffset offset: CGFloat) -> CGFloat {
        anchor + offset - contentBase
    }

    func y(atOffset offset: CGFloat) -> CGFloat {
        guard isFloating else {
            return edge == .top ? lo : hi
        }
        let a = anchorInFrameSpace(atOffset: offset)
        // The clamp ORDER differs by edge and is NOT cosmetic: it decides the degenerate case where
        // the band is shorter than the attachment (hi < lo). `.top` then resolves to hi and
        // `.bottom` to lo — the FAR edge in both, which is the "pushed out" look. This mirrors
        // ListViewImpl exactly (Display/Source/ListView.swift:4019 and :4032). Writing `.bottom` as
        // a naive mirror of `.top` compiles and behaves identically in every non-degenerate case.
        switch edge {
        case .top:
            return min(max(a, lo), hi)
        case .bottom:
            return max(min(a, hi), lo)
        }
    }

    /// Offset at which the anchor reaches `lo`. `nil` when the attachment does not float, because a
    /// non-floating map is one constant segment with no breakpoints.
    var lowBreakpoint: CGFloat? {
        isFloating ? lo + contentBase - anchor : nil
    }

    /// Offset at which the anchor reaches `hi`.
    var highBreakpoint: CGFloat? {
        isFloating ? hi + contentBase - anchor : nil
    }

    /// Composes this map with a baked scroll trajectory, producing the ADDITIVE frame-space
    /// displacement at each of the trajectory's vertices.
    ///
    /// Values are `y(atOffset: sample.offset) - y(atOffset: finalOffset)`, so they resolve to 0 onto
    /// the settled frame the list parks at the destination — the same convention
    /// `Trajectory.boundsOriginKeyframeAnimation` uses.
    ///
    /// Every vertex goes through `y(atOffset:)`, the SAME function the per-frame path evaluates. That
    /// is the whole point: the baked path and the live path cannot disagree because there is one
    /// definition of the sticky math.
    ///
    /// The trajectory's own vertices are reused rather than resampled, so the emitted keyTimes line up
    /// exactly with the content's animation and the two stay in phase.
    /// `coordinateShift` re-bases the trajectory's offsets into CURRENT list coordinates. The
    /// trajectory is baked once; window rebalancing re-bases the container underneath it, so every
    /// sample must be shifted or the composed path describes where the flight would have gone before
    /// the re-base.
    func composedKeyframe(trajectory: Trajectory,
                          coordinateShift: CGFloat = 0)
        -> (values: [CGFloat], keyTimes: [Double]) {
        let settled = y(atOffset: trajectory.finalOffset + coordinateShift)
        let duration = trajectory.duration
        guard duration > 0 else {
            return (values: [0], keyTimes: [0])
        }
        return (
            values: trajectory.samples.map { y(atOffset: $0.offset + coordinateShift) - settled },
            keyTimes: trajectory.samples.map { $0.t / duration }
        )
    }

    /// Points this attachment currently sits from its run's natural, content-riding edge: 0 while it
    /// rides the run, growing as it parks against the display edge, and negative in the degenerate
    /// case where the band is shorter than the attachment.
    ///
    /// `ListViewImpl` computes the same quantity per header, and both of its expressions reduce to
    /// this one: `.top` is `headerFrame.minY - upperBound` (Display/Source/ListView.swift:4023) =
    /// `y - lo`, and `.bottom` is `lowerBound - headerFrame.maxY` (:4033) =
    /// `(hi + height) - (y + height)` = `hi - y`.
    ///
    /// It lives HERE, on the type that is the single definition of the sticky math, for the same
    /// reason `composedKeyframe` does: a second derivation of "how far is it stuck" would be free to
    /// disagree with the position the list actually renders.
    ///
    /// Deliberately unclamped. The normalised 0…1 factor ListViewImpl hands to header nodes is
    /// `max(0.0, min(1.0, distance / height))` (:4024) — the clamp belongs to the consumer, which
    /// knows its own height, and the raw value is what a caller animating a real offset needs.
    func stickDistance(atOffset offset: CGFloat) -> CGFloat {
        let y = self.y(atOffset: offset)
        return edge == .top ? y - lo : hi - y
    }
}
