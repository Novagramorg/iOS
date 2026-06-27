import Foundation
import UIKit
import AccountContext
import TelegramCore
import InstantPageUI
import RichTextEditorUIKit

/// Adapts InstantPageUI's `StandaloneInstantPageImageView` (renders stills AND video) to the editor's
/// `RichTextMediaItemView` seam. The editor owns/positions/sizes it.
@available(iOS 13.0, *)
public final class MediaItemNodeView: UIView, RichTextMediaItemView {
    private let mediaView: StandaloneInstantPageImageView

    public init(context: AccountContext, media: EngineMedia) {
        let attributes: [InstantPageImageAttribute]
        if case .geo = media {
            // A location renders through InstantPageImageNode's built-in .geo path (snapshot + pin); it needs an
            // InstantPageMapAttribute for the zoom + snapshot dimensions. 600x300 matches the authored naturalSize
            // and the renderer's default-map fallback.
            attributes = [InstantPageMapAttribute(zoom: 15, dimensions: CGSize(width: 600.0, height: 300.0))]
        } else {
            attributes = []
        }
        self.mediaView = StandaloneInstantPageImageView(context: context, media: media, attributes: attributes)
        super.init(frame: .zero)
        self.addSubview(self.mediaView)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func update(size: CGSize) {
        self.mediaView.frame = CGRect(origin: .zero, size: size)
        self.mediaView.update(size: size)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        self.mediaView.frame = self.bounds
    }
}
