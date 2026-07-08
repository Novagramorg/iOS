import Foundation
import UIKit
import ComponentFlow
import Display
import RichTextEditorUIKit
import AccountContext
import TelegramCore
import SwiftSignalKit
import PhotoResources
import RadialStatusNode
import LottieComponent
import GlassBackgroundComponent

/// A composable ComponentFlow renderer for ONE rich-text still image or video poster. Owns its
/// own `TransformImageNode` + media-fetch signal + aspect-fill layout, decoupled from
/// `InstantPageImageNode`. Carries a glass "more" button; interaction is **control-scoped** — the
/// `View.hitTest` returns a control ONLY when the touch lands on it (the poster passes through to the
/// editor's own tap handling), which is how the button is tappable without stealing caret/media-select
/// taps. Built as a plain `Component` so a future mosaic/slideshow wrapper can compose it without
/// structural change. Location (`.geo`) and audio are handled by `MediaItemNodeView`, not here.
@available(iOS 13.0, *)
public final class RichTextMediaContentComponent: Component {
    public let context: AccountContext
    public let media: EngineMedia
    /// Whether the glass "more" button is shown. Constant per usage (composer vs. article editor); not
    /// part of `==` for the same reason `onControlTapped` isn't — identity equality must hold across
    /// resizes so the fetch binds once.
    public let showsMoreButton: Bool

    /// Set by `MediaItemNodeView`; fired when an interactive control is tapped. Not part of `==` (identity
    /// equality must hold across resizes so the fetch binds once).
    var onControlTapped: ((RichTextMediaControlKind, UIView, CGRect) -> Void)?

    public init(context: AccountContext, media: EngineMedia, showsMoreButton: Bool = true) {
        self.context = context
        self.media = media
        self.showsMoreButton = showsMoreButton
    }

    public static func ==(lhs: RichTextMediaContentComponent, rhs: RichTextMediaContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.media.id != rhs.media.id {
            return false
        }
        return true
    }
    
    private final class ButtonView: UIView {
        
    }

    public final class View: UIView {
        private let imageNode = TransformImageNode()
        private var statusNode: RadialStatusNode?
        private let fetchDisposable = MetaDisposable()
        
        private let moreButtonBackgroundContainer: GlassBackgroundContainerView
        private let moreButton: HighlightTrackingButton
        private let moreButtonBackground: GlassBackgroundView
        private let moreButtonIcon = ComponentView<Empty>()

        private var boundMediaId: EngineMedia.Id?
        private var didBind = false
        private var dimensions: PixelDimensions?
        private var isVideo = false
        private var currentSize: CGSize?
        
        private var component: RichTextMediaContentComponent?
        private weak var state: EmptyComponentState?

        override init(frame: CGRect) {
            self.moreButton = HighlightTrackingButton()
            self.moreButtonBackgroundContainer = GlassBackgroundContainerView()
            self.moreButtonBackground = GlassBackgroundView()
            
            super.init(frame: frame)
            
            self.addSubview(self.imageNode.view)
            
            self.moreButtonBackground.isUserInteractionEnabled = false
            self.moreButton.addSubview(self.moreButtonBackground)
            self.moreButtonBackgroundContainer.contentView.addSubview(self.moreButton)
            self.addSubview(self.moreButtonBackgroundContainer)
            
            self.moreButton.addTarget(self, action: #selector(self.moreButtonPressed), for: .touchUpInside)
            self.moreButton.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                let transition: ComponentTransition = highlighted ? .immediate : .easeInOut(duration: 0.25)
                transition.setAlpha(view: self.moreButton, alpha: highlighted ? 0.6 : 1.0)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.fetchDisposable.dispose()
        }

        /// Only the interactive chrome (the more button) claims a touch; the image/video poster area
        /// returns nil so the touch passes through to the editor, which runs its own tap handling
        /// (caret placement / media-select highlight). Routes through the button's
        /// `GlassBackgroundContainerView`, whose own `hitTest` already returns the button when hit and
        /// nil otherwise. Add any future interactive controls to this override.
        public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let inButton = self.moreButtonBackgroundContainer.convert(point, from: self)
            return self.moreButtonBackgroundContainer.hitTest(inButton, with: event)
        }

        @objc private func moreButtonPressed() {
            self.component?.onControlTapped?(.more, self.moreButtonBackgroundContainer,
                                             self.moreButtonBackgroundContainer.bounds)
        }
        
        func update(component: RichTextMediaContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
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
            
            let buttonSize = CGSize(width: 36.0, height: 36.0)
            let buttonHorizontalInset: CGFloat = 8.0
            let buttonVerticalInset: CGFloat = 8.0
            
            let moreButtonFrame = CGRect(origin: CGPoint(x: buttonHorizontalInset, y: buttonVerticalInset), size: buttonSize)
            
            transition.setFrame(view: self.moreButtonBackgroundContainer, frame: moreButtonFrame)
            self.moreButtonBackgroundContainer.update(size: buttonSize, isDark: true, transition: transition)
            
            transition.setFrame(view: self.moreButtonBackground, frame: CGRect(origin: CGPoint(), size: moreButtonFrame.size))
            self.moreButtonBackground.update(size: moreButtonFrame.size, cornerRadius: moreButtonFrame.height * 0.5, isDark: true, tintColor: .init(kind: .panel), transition: transition)
            
            transition.setFrame(view: self.moreButton, frame: CGRect(origin: CGPoint(), size: moreButtonFrame.size))
            
            let buttonIconSize = self.moreButtonIcon.update(
                transition: transition,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "anim_baremoredots"),
                    color: .white,
                    startingPosition: .begin
                )),
                environment: {},
                containerSize: buttonSize
            )
            if let moreButtonIconView = self.moreButtonIcon.view {
                if moreButtonIconView.superview == nil {
                    self.moreButtonBackground.contentView.addSubview(moreButtonIconView)
                }
                transition.setFrame(view: moreButtonIconView, frame: buttonIconSize.centered(in: CGRect(origin: CGPoint(), size: buttonSize)))
            }

            self.moreButtonBackgroundContainer.isHidden = !component.showsMoreButton

            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
