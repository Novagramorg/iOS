import Foundation
import UIKit
import ComponentFlow
import Display
import AccountContext
import TelegramCore
import SwiftSignalKit
import PhotoResources
import RadialStatusNode

/// A composable ComponentFlow renderer for ONE rich-text still image or video poster. Owns its
/// own `TransformImageNode` + media-fetch signal + aspect-fill layout, decoupled from
/// `InstantPageImageNode`. Non-interactive today (auto-fetch, no tap); built as a plain
/// `Component` so tap/long-press and a future mosaic/slideshow wrapper can compose it without
/// structural change. Location (`.geo`) and audio are handled by `MediaItemNodeView`, not here.
@available(iOS 13.0, *)
public final class RichTextMediaContentComponent: Component {
    public let context: AccountContext
    public let media: EngineMedia

    public init(context: AccountContext, media: EngineMedia) {
        self.context = context
        self.media = media
    }

    public static func ==(lhs: RichTextMediaContentComponent, rhs: RichTextMediaContentComponent) -> Bool {
        // Identity, NOT a per-layout-changing value: resizes (the editor's per-pass update)
        // must not rebind the signal. Only a media change rebinds.
        if lhs.context !== rhs.context { return false }
        if lhs.media.id != rhs.media.id { return false }
        return true
    }

    public final class View: UIView {
        private let imageNode = TransformImageNode()
        private var statusNode: RadialStatusNode?
        private let fetchDisposable = MetaDisposable()

        private var boundMediaId: EngineMedia.Id?
        private var didBind = false
        private var dimensions: PixelDimensions?
        private var isVideo = false
        private var currentSize: CGSize?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.isUserInteractionEnabled = false
            self.addSubview(self.imageNode.view)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        deinit { self.fetchDisposable.dispose() }

        func update(component: RichTextMediaContentComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            if !self.didBind || self.boundMediaId != component.media.id {
                self.bind(component: component)
                self.didBind = true
                self.boundMediaId = component.media.id
                self.currentSize = nil   // force a re-layout against the new media's aspect
            }

            if self.currentSize != availableSize {
                self.currentSize = availableSize
                self.layoutContent(availableSize: availableSize, component: component)
            }
            return availableSize
        }

        private func bind(component: RichTextMediaContentComponent) {
            let context = component.context
            self.fetchDisposable.set(nil)
            self.statusNode?.view.removeFromSuperview()
            self.statusNode = nil
            self.isVideo = false
            self.dimensions = nil

            if case let .image(image) = component.media, let largest = largestImageRepresentation(image.representations) {
                self.dimensions = largest.dimensions
                let imageReference = ImageMediaReference.standalone(media: image)
                self.imageNode.setSignal(chatMessagePhoto(postbox: context.account.postbox, userLocation: .other, photoReference: imageReference))
                self.fetchDisposable.set(chatMessagePhotoInteractiveFetched(context: context, userLocation: .other, photoReference: imageReference, displayAtSize: nil, storeToDownloadsPeerId: nil).start())
            } else if case let .file(file) = component.media {
                self.dimensions = file.dimensions
                let fileReference = FileMediaReference.standalone(media: file)
                if file.mimeType.hasPrefix("image/") {
                    _ = freeMediaFileInteractiveFetched(account: context.account, userLocation: .other, fileReference: fileReference).start()
                    self.imageNode.setSignal(instantPageImageFile(account: context.account, userLocation: .other, fileReference: fileReference, fetched: true))
                } else {
                    self.imageNode.setSignal(chatMessageVideo(postbox: context.account.postbox, userLocation: .other, videoReference: fileReference))
                    self.isVideo = true
                }
            }
            // else: unexpected media kind (.geo / audio reach here only by misuse) — leave the
            // node blank rather than crash.
        }

        private func layoutContent(availableSize: CGSize, component: RichTextMediaContentComponent) {
            self.imageNode.frame = CGRect(origin: .zero, size: availableSize)

            let emptyColor = component.context.sharedContext.currentPresentationData.with { $0 }.theme.list.mediaPlaceholderColor
            if let dimensions = self.dimensions {
                let imageSize = dimensions.cgSize.aspectFilled(availableSize)
                let apply = self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: availableSize, intrinsicInsets: UIEdgeInsets(), emptyColor: emptyColor))
                apply()
            }

            if self.isVideo {
                let statusNode: RadialStatusNode
                if let existing = self.statusNode {
                    statusNode = existing
                } else {
                    statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.6))
                    statusNode.transitionToState(.play(.white), animated: false, completion: {})
                    self.addSubview(statusNode.view)   // RadialStatusNode is an ASControlNode; host its .view
                    self.statusNode = statusNode
                }
                let statusSize: CGFloat = max(18.0, min(50.0, floor(min(availableSize.width, availableSize.height) * 0.7)))
                statusNode.frame = CGRect(x: floorToScreenPixels((availableSize.width - statusSize) / 2.0), y: floorToScreenPixels((availableSize.height - statusSize) / 2.0), width: statusSize, height: statusSize)
            }
        }

        override public func layoutSubviews() {
            super.layoutSubviews()
            self.imageNode.frame = self.bounds
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
