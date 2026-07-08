import Foundation
import UIKit
import ComponentFlow
import AccountContext
import TelegramCore
import InstantPageUI
import RichTextEditorUIKit

/// Adapts the rich-text editor's `RichTextMediaItemView` seam to concrete media renderers, by kind:
/// audio (music/voice `.file`) → `StandaloneInstantPageAudioView` (a playable row); location (`.geo`)
/// → `StandaloneInstantPageImageView` (map snapshot + pin); photo/video → the composable
/// `RichTextMediaContentComponent` hosted in a `ComponentHostView`. The editor owns/positions/sizes
/// the hosted view via `update(size:)`.
@available(iOS 13.0, *)
public final class MediaItemNodeView: UIView, RichTextMediaItemView {
    private let imageView: StandaloneInstantPageImageView?
    private let audioView: StandaloneInstantPageAudioView?
    private let contentHost: ComponentHostView<Empty>?
    private let contentComponent: RichTextMediaContentComponent?

    public init(context: AccountContext, media: EngineMedia, audioColorOverride: InstantPageAudioColorOverride? = nil, cornerRadius: CGFloat = 0) {
        if case let .file(file) = media, file.isMusic || file.isVoice {
            // `audioColorOverride` (host-supplied) themes the row to the editor's accent/text scheme; nil falls
            // back to the outgoing-bubble palette.
            self.audioView = StandaloneInstantPageAudioView(context: context, file: file, colorOverride: audioColorOverride)
            self.imageView = nil
            self.contentHost = nil
            self.contentComponent = nil
            super.init(frame: .zero)
            self.addSubview(self.audioView!)
        } else if case .geo = media {
            // A location renders through InstantPageImageNode's built-in .geo path (snapshot + pin); it
            // needs an InstantPageMapAttribute for the zoom + snapshot dimensions. 600x300 matches the
            // authored naturalSize and the renderer's default-map fallback.
            let attributes: [InstantPageImageAttribute] = [InstantPageMapAttribute(zoom: 15, dimensions: CGSize(width: 600.0, height: 300.0))]
            self.imageView = StandaloneInstantPageImageView(context: context, media: media, attributes: attributes)
            self.audioView = nil
            self.contentHost = nil
            self.contentComponent = nil
            super.init(frame: .zero)
            self.addSubview(self.imageView!)
        } else {
            // Photo / video → the composable ComponentFlow renderer.
            let host = ComponentHostView<Empty>()
            self.contentHost = host
            self.contentComponent = RichTextMediaContentComponent(context: context, media: media)
            self.imageView = nil
            self.audioView = nil
            super.init(frame: .zero)
            self.addSubview(host)
        }

        // Round VISUAL media (photo/video/location) corners when the host requests it (chat composer → 10pt).
        // Audio rows (audioView) stay square; the article editor passes 0 (no rounding). Applied on this
        // container's layer — its single child fills `bounds`, so masksToBounds clips it to the rounded rect.
        if cornerRadius > 0, self.audioView == nil {
            self.layer.cornerRadius = cornerRadius
            self.layer.masksToBounds = true
        }
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func update(size: CGSize) {
        self.imageView?.frame = CGRect(origin: .zero, size: size)
        self.imageView?.update(size: size)
        self.audioView?.frame = CGRect(origin: .zero, size: size)
        self.audioView?.update(size: size)
        if let host = self.contentHost, let component = self.contentComponent {
            host.frame = CGRect(origin: .zero, size: size)
            _ = host.update(transition: .immediate, component: AnyComponent(component), environment: {}, containerSize: size)
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        self.imageView?.frame = self.bounds
        self.audioView?.frame = self.bounds
        self.contentHost?.frame = self.bounds
    }

    /// The editor treats media as non-interactive EXCEPT for the interactive controls the photo/video
    /// renderer exposes (the more button). Only a hit that resolves to such a control claims the touch;
    /// everything else — the poster area, and the audio/location branches entirely — returns nil so the
    /// touch falls through to the editor's own tap handling. `RichTextMediaContentComponent.View` already
    /// returns the button-or-nil, so a hit that merely bottoms out on the hosting container is treated as
    /// "no control touched". Guarded by the standard visibility/point-inside checks so a culled (hidden)
    /// media view never claims a touch.
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !self.isHidden, self.isUserInteractionEnabled, self.alpha > 0.01,
              self.point(inside: point, with: event) else {
            return nil
        }
        guard let host = self.contentHost else {
            return nil   // audio / location — non-interactive, as before
        }
        let inHost = host.convert(point, from: self)
        guard let hit = host.hitTest(inHost, with: event), hit !== host else {
            return nil   // poster area (no control under the touch)
        }
        return hit
    }
}
