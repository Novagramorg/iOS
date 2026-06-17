import Foundation
import UIKit
import AccountContext
import TelegramCore
import InstantPageUI
import RichTextEditorUIKit

/// Adapts InstantPageUI's `StandaloneInstantPageImageView` (renders stills AND video) to the editor's
/// `RichTextMediaItemView` seam. The editor owns/positions/sizes it.
@available(iOS 13.0, *)
final class MediaItemNodeView: UIView, RichTextMediaItemView {
    private let mediaView: StandaloneInstantPageImageView

    init(context: AccountContext, media: EngineMedia) {
        self.mediaView = StandaloneInstantPageImageView(context: context, media: media)
        super.init(frame: .zero)
        self.addSubview(self.mediaView)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(size: CGSize) {
        self.mediaView.frame = CGRect(origin: .zero, size: size)
        self.mediaView.update(size: size)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.mediaView.frame = self.bounds
    }
}
