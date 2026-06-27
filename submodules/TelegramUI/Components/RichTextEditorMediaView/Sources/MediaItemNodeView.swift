import Foundation
import UIKit
import AccountContext
import TelegramCore
import InstantPageUI
import RichTextEditorUIKit

/// Adapts InstantPageUI's standalone media views to the editor's `RichTextMediaItemView` seam. An audio
/// `.file` (music or voice) renders through `StandaloneInstantPageAudioView` (a playable row); everything
/// else renders through `StandaloneInstantPageImageView` (stills, video, and the `.geo` map snapshot). The
/// editor owns/positions/sizes the hosted view.
@available(iOS 13.0, *)
public final class MediaItemNodeView: UIView, RichTextMediaItemView {
    private let imageView: StandaloneInstantPageImageView?
    private let audioView: StandaloneInstantPageAudioView?

    public init(context: AccountContext, media: EngineMedia, audioColorOverride: InstantPageAudioColorOverride? = nil) {
        if case let .file(file) = media, file.isMusic || file.isVoice {
            // `audioColorOverride` (host-supplied) themes the row to the editor's accent/text scheme; nil falls
            // back to the outgoing-bubble palette. Images/maps ignore it.
            self.audioView = StandaloneInstantPageAudioView(context: context, file: file, colorOverride: audioColorOverride)
            self.imageView = nil
            super.init(frame: .zero)
            self.addSubview(self.audioView!)
        } else {
            let attributes: [InstantPageImageAttribute]
            if case .geo = media {
                // A location renders through InstantPageImageNode's built-in .geo path (snapshot + pin); it
                // needs an InstantPageMapAttribute for the zoom + snapshot dimensions. 600x300 matches the
                // authored naturalSize and the renderer's default-map fallback.
                attributes = [InstantPageMapAttribute(zoom: 15, dimensions: CGSize(width: 600.0, height: 300.0))]
            } else {
                attributes = []
            }
            self.imageView = StandaloneInstantPageImageView(context: context, media: media, attributes: attributes)
            self.audioView = nil
            super.init(frame: .zero)
            self.addSubview(self.imageView!)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func update(size: CGSize) {
        self.imageView?.frame = CGRect(origin: .zero, size: size)
        self.imageView?.update(size: size)
        self.audioView?.frame = CGRect(origin: .zero, size: size)
        self.audioView?.update(size: size)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        self.imageView?.frame = self.bounds
        self.audioView?.frame = self.bounds
    }
}
