import Foundation
import UIKit
import ComponentFlow
import AccountContext
import TelegramCore
import InstantPageUI
import RichTextEditorUIKit
import MosaicLayout

/// Adapts the rich-text editor's `RichTextMediaItemView` seam to concrete media renderers, by kind:
/// audio (music/voice `.file`) → `StandaloneInstantPageAudioView` (a playable row); location (`.geo`)
/// → `StandaloneInstantPageImageView` (map snapshot + pin); photo/video (ANY count, including 1) → a
/// UNIFIED cell pool of `RichTextMediaContentComponent`s hosted in `ComponentHostView`s.
///
/// **Unified pool (no single↔mosaic mode boundary):** photo/video always renders from `mosaicCells`.
/// count==1 is a single full-bounds cell (the mosaic engine `chatMessageBubbleMosaicLayout` has NO 1-item
/// case, so it is bypassed for count<=1 → the one cell fills `size`); count>=2 uses the album mosaic engine.
/// Removing the mode switch lets `MosaicCellDiff` reuse surviving cells across 1↔2↔3… transitions, so an
/// add-more / delete-one via `updateResolvedItems(_:)` preserves each survivor's bound fetch (no re-flash).
/// Audio/location stay on their `StandaloneInstantPage*` views (always single, never mutate).
///
/// The editor owns/positions/sizes the hosted view via `update(size:)`. `cornerRadius > 0` rounds the
/// container's corners for photo/video/location (audio stays square).
@available(iOS 13.0, *)
public final class MediaItemNodeView: UIView, RichTextMediaItemView {
    private let imageView: StandaloneInstantPageImageView?   // location (.geo) only
    private let audioView: StandaloneInstantPageAudioView?   // audio (music/voice) only
    // Photo/video → a mosaic cell pool. count==1 is a single full-bounds cell (mosaic engine has no 1-item case).
    private var mosaicItems: [(media: EngineMedia, naturalSize: CGSize)] = []
    private var mosaicCells: [MosaicCellDiff.PooledKey: (host: ComponentHostView<Empty>, component: RichTextMediaContentComponent)] = [:]
    private var mosaicOccurrenceCounter: [EngineMedia.Id: Int] = [:]
    private let mosaicContext: AccountContext?   // set for photo/video; nil for audio/location
    private let showsControls: Bool   // forwarded to each photo/video cell's glass "more" button

    public init(context: AccountContext,
                items: [(media: EngineMedia, naturalSize: CGSize)],
                audioColorOverride: InstantPageAudioColorOverride? = nil,
                cornerRadius: CGFloat = 0,
                showsControls: Bool = true) {
        self.showsControls = showsControls
        if items.count == 1, case let .file(file) = items[0].media, file.isMusic || file.isVoice {
            self.audioView = StandaloneInstantPageAudioView(context: context, file: file, colorOverride: audioColorOverride)
            self.imageView = nil
            self.mosaicContext = nil
            super.init(frame: .zero)
            self.addSubview(self.audioView!)
        } else if items.count == 1, case .geo = items[0].media {
            let attributes: [InstantPageImageAttribute] = [InstantPageMapAttribute(zoom: 15, dimensions: CGSize(width: 600.0, height: 300.0))]
            self.imageView = StandaloneInstantPageImageView(context: context, media: items[0].media, attributes: attributes)
            self.audioView = nil
            self.mosaicContext = nil
            super.init(frame: .zero)
            self.addSubview(self.imageView!)
        } else {
            // Photo/video (any count) — the mosaic cell pool. count==1 fills bounds.
            self.imageView = nil
            self.audioView = nil
            self.mosaicContext = context
            super.init(frame: .zero)
            self.mosaicItems = items
        }
        // Round photo/video/location corners on request; audio stays square.
        if cornerRadius > 0, self.audioView == nil {
            self.layer.cornerRadius = cornerRadius
            self.layer.masksToBounds = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Editor-set control-tap hook `(kind, itemIndex, anchorView, sourceRect)`. For a single-item container the
    /// cell reports `itemIndex == nil` (whole block — byte-identical to pre-container behavior); a ≥2 mosaic
    /// reports the touched cell's index. Audio/location are non-interactive (no cells wire it).
    public var onControlTapped: ((RichTextMediaControlKind, Int?, UIView, CGRect) -> Void)?

    /// Re-render with a NEW resolved item list (add-more / delete-one), reusing surviving cells via
    /// `MosaicCellDiff` so their bound fetch is preserved (no re-flash). No-op for audio/location.
    public func updateResolvedItems(_ items: [(media: EngineMedia, naturalSize: CGSize)]) {
        guard self.mosaicContext != nil else { return }
        self.mosaicItems = items
        self.updateMosaic(size: self.bounds.size)
    }

    public func update(size: CGSize) {
        self.imageView?.frame = CGRect(origin: .zero, size: size)
        self.imageView?.update(size: size)
        self.audioView?.frame = CGRect(origin: .zero, size: size)
        self.audioView?.update(size: size)
        if self.mosaicContext != nil {
            self.updateMosaic(size: size)
        }
    }

    /// Lays out photo/video cells, reusing an existing cell wherever `MosaicCellDiff` finds a matching pooled
    /// occurrence for the incoming media ids (bound fetch preserved). count==1 fills `size`; count>=2 uses the
    /// album mosaic engine.
    ///
    /// `EngineMedia.id` is `EngineMedia.Id?` on the general enum (some kinds carry no stable identity); the
    /// pool only ever holds photo/video (`.image`/`.file`), whose `.id` is non-nil in practice, so the
    /// `compactMap` below is a defensive guard. An id-less item is skipped entirely (no cell rendered) rather
    /// than force-unwrapped or given a synthetic key — there is no stable identity to pool/reuse it by.
    private func updateMosaic(size: CGSize) {
        guard let context = self.mosaicContext else { return }
        let frames: [CGRect]
        if self.mosaicItems.count <= 1 {
            frames = [CGRect(origin: .zero, size: size)]
        } else {
            // Same cap the box reserves (MediaBlockBox.mosaicSize): pack within width × min(1000,width),
            // then scale-to-fit + center when the width-driven pack still exceeds the cap.
            let cap = min(1000.0, size.width)
            let (rawFrames, naturalSize) = chatMessageBubbleMosaicLayout(
                maxSize: CGSize(width: size.width, height: cap),
                itemSizes: self.mosaicItems.map { $0.naturalSize })
            let scale: CGFloat = naturalSize.height > cap ? cap / naturalSize.height : 1.0
            let xOffset = floor((size.width - naturalSize.width * scale) / 2.0)
            frames = rawFrames.map { frame, _ in
                CGRect(x: xOffset + frame.minX * scale, y: frame.minY * scale,
                       width: frame.width * scale, height: frame.height * scale)
            }
        }
        // Diff by media identity so surviving cells are reused (fetch bound once), not rebuilt.
        let incomingIds: [EngineMedia.Id] = self.mosaicItems.compactMap { $0.media.id }
        let plan = MosaicCellDiff.plan(poolKeys: Array(self.mosaicCells.keys), incoming: incomingIds)
        // Tear down removed cells.
        for key in plan.removed {
            self.mosaicCells[key]?.host.removeFromSuperview()
            self.mosaicCells[key] = nil
        }
        let reportNilIndex = self.mosaicItems.count == 1   // single container → whole-block control (nil), as before
        let usesAspectFit = self.mosaicItems.count == 1   // lone photo/video → fit + blur; mosaic cells → fill
        // `reuseIndex` walks `plan.reuse` in lockstep with `incomingIds` — both were built by iterating
        // `mosaicItems` in order and skipping id-less items identically, so the two stay aligned.
        var reuseIndex = 0
        for (index, item) in self.mosaicItems.enumerated() {
            guard let mediaId = item.media.id else { continue }
            let frame = index < frames.count ? frames[index] : CGRect(origin: .zero, size: size)
            let host: ComponentHostView<Empty>
            let component: RichTextMediaContentComponent
            if let reusedKey = plan.reuse[reuseIndex], let existing = self.mosaicCells[reusedKey] {
                host = existing.host; component = existing.component
            } else {
                // Fresh cell: unique occurrence key so duplicate media get distinct pool slots.
                let occurrence = self.mosaicOccurrenceCounter[mediaId, default: 0]
                self.mosaicOccurrenceCounter[mediaId] = occurrence + 1
                let key = MosaicCellDiff.PooledKey(id: mediaId, occurrence: occurrence)
                let newHost = ComponentHostView<Empty>()
                let newComponent = RichTextMediaContentComponent(context: context, media: item.media, showsMoreButton: self.showsControls)
                self.addSubview(newHost)
                self.mosaicCells[key] = (newHost, newComponent)
                host = newHost; component = newComponent
            }
            reuseIndex += 1
            component.usesAspectFit = usesAspectFit   // set every pass — a cell reused across 1↔2 switches mode
            // Refresh every pass (reused AND fresh) so a reused cell forwards the CURRENT loop `index` (or nil
            // for a single container), not the stale index captured when it was first created.
            let reportedIndex: Int? = reportNilIndex ? nil : index
            component.onControlTapped = { [weak self] kind, anchorView, rect in
                self?.onControlTapped?(kind, reportedIndex, anchorView, rect)
            }
            host.frame = frame
            _ = host.update(transition: .immediate, component: AnyComponent(component),
                            environment: {}, containerSize: frame.size)
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        self.imageView?.frame = self.bounds
        self.audioView?.frame = self.bounds
        if self.mosaicContext != nil {
            self.updateMosaic(size: self.bounds.size)
        }
    }

    /// The editor treats media as non-interactive EXCEPT for the interactive controls the photo/video
    /// renderer exposes (the more button). Only a hit that resolves to such a control claims the touch;
    /// everything else — the poster area, and the audio/location branches entirely — returns nil so the
    /// touch falls through to the editor's own tap handling. Guarded by the standard visibility/point-inside
    /// checks so a culled (hidden) media view never claims a touch.
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !self.isHidden, self.isUserInteractionEnabled, self.alpha > 0.01,
              self.point(inside: point, with: event) else {
            return nil
        }
        if self.mosaicContext != nil {
            for (_, cell) in self.mosaicCells {
                let inHost = cell.host.convert(point, from: self)
                if cell.host.point(inside: inHost, with: event),
                   let hit = cell.host.hitTest(inHost, with: event), hit !== cell.host {
                    return hit
                }
            }
            return nil
        }
        return nil   // audio / location — non-interactive
    }
}
