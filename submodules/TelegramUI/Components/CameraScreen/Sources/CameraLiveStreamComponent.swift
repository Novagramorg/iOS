import Foundation
import UIKit
import Display
import ComponentFlow
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramCallsUI
import TelegramPresentationData
import StoryContainerScreen
import ChatEntityKeyboardInputNode
import AvatarNode
import MultilineTextComponent

final class CameraLiveStreamComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peerId: EnginePeer.Id
    let story: EngineStoryItem?
    let statusBarHeight: CGFloat
    let inputHeight: CGFloat
    let safeInsets: UIEdgeInsets
    let metrics: LayoutMetrics
    let deviceMetrics: DeviceMetrics
    let didSetupMediaStream: (PresentationGroupCall) -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        peerId: EnginePeer.Id,
        story: EngineStoryItem?,
        statusBarHeight: CGFloat,
        inputHeight: CGFloat,
        safeInsets: UIEdgeInsets,
        metrics: LayoutMetrics,
        deviceMetrics: DeviceMetrics,
        didSetupMediaStream: @escaping (PresentationGroupCall) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peerId = peerId
        self.story = story
        self.statusBarHeight = statusBarHeight
        self.inputHeight = inputHeight
        self.safeInsets = safeInsets
        self.metrics = metrics
        self.deviceMetrics = deviceMetrics
        self.didSetupMediaStream = didSetupMediaStream
    }
    
    static func ==(lhs: CameraLiveStreamComponent, rhs: CameraLiveStreamComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.story != rhs.story {
            return false
        }
        if lhs.statusBarHeight != rhs.statusBarHeight {
            return false
        }
        if lhs.inputHeight != rhs.inputHeight {
            return false
        }
        if lhs.safeInsets != rhs.safeInsets {
            return false
        }
        if lhs.metrics != rhs.metrics {
            return false
        }
        if lhs.deviceMetrics != rhs.deviceMetrics {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var liveChat: ComponentView<Empty>?
        
        private var storyContent: SingleStoryContentContextImpl?
        private var storyContentState: StoryContentContextState?
        private var storyContentDisposable: Disposable?
        
        private let externalState = StoryItemSetContainerComponent.ExternalState()
        private let storyItemSharedState = StoryContentItem.SharedState()
        
        private let inputMediaNodeDataPromise = Promise<ChatEntityKeyboardInputNode.InputData>()
        private let closeFriendsPromise = Promise<[EnginePeer]>()
        private var blockedPeers: BlockedPeersContext?
        
        private var component: CameraLiveStreamComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.storyContentDisposable?.dispose()
        }
        
        var mediaStreamCall: PresentationGroupCall? {
            if let view = self.liveChat?.view as? StoryItemSetContainerComponent.View {
                return view.mediaStreamCall
            }
            return nil
        }
                
        func update(component: CameraLiveStreamComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
                        
            if let story = component.story {
                if self.storyContentDisposable == nil {
                    let storyContent = SingleStoryContentContextImpl(context: component.context, storyId: StoryId(peerId: component.peerId, id: story.id), storyItem: story, readGlobally: false)
                    self.storyContent = storyContent
                    self.storyContentDisposable = (storyContent.state
                    |> deliverOnMainQueue).start(next: { [weak self] state in
                        guard let self else {
                            return
                        }
                        self.storyContentState = state
                        self.state?.updated()
                    })
                }
                
                if let storyContentState = self.storyContentState, let slice = storyContentState.slice {
                    var mediaStreamTransition = transition
                    
                    let liveChat: ComponentView<Empty>
                    if let current = self.liveChat {
                        liveChat = current
                    } else {
                        mediaStreamTransition = .immediate
                        liveChat = ComponentView()
                        self.liveChat = liveChat
                    }
                    
                    let itemSetContainerInsets = UIEdgeInsets(top: component.statusBarHeight + 5.0, left: 0.0, bottom: 0.0, right: 0.0)
                    let itemSetContainerSafeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 0.0)
                             
                    let _ = liveChat.update(
                        transition: mediaStreamTransition,
                        component: AnyComponent(StoryItemSetContainerComponent(
                            context: component.context,
                            externalState: self.externalState,
                            storyItemSharedState: self.storyItemSharedState,
                            availableReactions: nil,
                            slice: slice,
                            theme: defaultDarkColorPresentationTheme,
                            strings: component.strings,
                            containerInsets: itemSetContainerInsets,
                            safeInsets: itemSetContainerSafeInsets,
                            statusBarHeight: component.statusBarHeight,
                            inputHeight: component.inputHeight,
                            metrics: component.metrics,
                            deviceMetrics: component.deviceMetrics,
                            isEmbeddedInCamera: true,
                            isProgressPaused: false,
                            isAudioMuted: false,
                            audioMode: .off,
                            hideUI: false,
                            visibilityFraction: 1.0,
                            isPanning: false,
                            isCentral: true,
                            pinchState: nil,
                            presentController: { c, a in
                                //                            guard let self, let environment = self.environment else {
                                //                                return
                                //                            }
                                //                            if c is UndoOverlayController || c is TooltipScreen {
                                //                                environment.controller()?.present(c, in: .current)
                                //                            } else {
                                //                                environment.controller()?.present(c, in: .window(.root), with: a)
                                //                            }
                            },
                            presentInGlobalOverlay: { c, a in
                                //                            guard let self, let environment = self.environment else {
                                //                                return
                                //                            }
                                //                            environment.controller()?.presentInGlobalOverlay(c, with: a)
                            },
                            close: {
                            },
                            navigate: { _ in
                            },
                            delete: {
                            },
                            markAsSeen: { _ in
                            },
                            reorder: {
                            },
                            createToFolder: { _, _ in
                            },
                            addToFolder: { _ in
                            },
                            controller: {
                                return nil //self?.environment?.controller()
                            },
                            toggleAmbientMode: {
                            },
                            keyboardInputData: self.inputMediaNodeDataPromise.get(),
                            closeFriends: self.closeFriendsPromise,
                            blockedPeers: self.blockedPeers,
                            sharedViewListsContext: StoryItemSetViewListComponent.SharedListsContext(),
                            stealthModeTimeout: nil,
                            isDismissed: false
                        )),
                        environment: {},
                        containerSize: availableSize
                    )
                    let liveChatFrame = CGRect(origin: CGPoint(), size: availableSize)
                    if let liveChatView = liveChat.view as? StoryItemSetContainerComponent.View {
                        if liveChatView.superview == nil {
                            liveChatView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                            
                            liveChat.parentState = state
                            self.addSubview(liveChatView)
                        }
                        mediaStreamTransition.setFrame(view: liveChatView, frame: liveChatFrame)
                        
                        if let mediaStreamCall = liveChatView.mediaStreamCall {
                            component.didSetupMediaStream(mediaStreamCall)
                        }
                    }
                }
            } else {
                if let liveChat = self.liveChat {
                    self.liveChat = nil
                    liveChat.view?.removeFromSuperview()
                }
            }
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class StreamAsComponent: Component {
    let context: AccountContext
    let peerId: EnginePeer.Id

    public init(
        context: AccountContext,
        peerId: EnginePeer.Id
    ) {
        self.context = context
        self.peerId = peerId
    }

    public static func ==(lhs: StreamAsComponent, rhs: StreamAsComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let avatarNode: AvatarNode
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private var arrow = UIImageView()
        
        private var component: StreamAsComponent?
        private weak var state: EmptyComponentState?
        
        private var peer: EnginePeer?
        
        public override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 18.0))
            self.arrow.image = generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: UIColor(white: 1.0, alpha: 0.8))
            
            super.init(frame: frame)
                        
            self.addSubnode(self.avatarNode)
            self.addSubview(self.arrow)
        }
        
        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func update(component: StreamAsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            if self.peer?.id != component.peerId {
                let _ = (component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: component.peerId))
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    guard let self, let peer else {
                        return
                    }
                    self.peer = peer
                    self.state?.updated()
                })
            }
            
            self.avatarNode.frame = CGRect(origin: .zero, size: CGSize(width: 32.0, height: 32.0))
            if let peer = self.peer {
                self.avatarNode.setPeer(
                    context: component.context,
                    theme: component.context.sharedContext.currentPresentationData.with({ $0 }).theme,
                    peer: peer,
                    synchronousLoad: true
                )
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: self.peer?.compactDisplayTitle ?? "", font: Font.semibold(14.0), textColor: .white, paragraphAlignment: .left))
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 38.0, height: availableSize.height)
            )
            let titleFrame = CGRect(origin: CGPoint(x: 42.0, y: 1.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: "change", font: Font.regular(11.0), textColor: UIColor(white: 1.0, alpha: 0.8), paragraphAlignment: .left))
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 50.0, height: availableSize.height)
            )
            let subtitleFrame = CGRect(origin: CGPoint(x: 42.0, y: titleFrame.maxY + 2.0), size: subtitleSize)
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.addSubview(subtitleView)
                }
                subtitleView.frame = subtitleFrame
            }
            
            if let icon = self.arrow.image {
                self.arrow.frame = CGRect(origin: CGPoint(x: subtitleFrame.maxX + 1.0, y: floorToScreenPixels(subtitleFrame.midY - icon.size.height / 2.0) + 1.0), size: icon.size).insetBy(dx: 1.0, dy: 1.0)
            }
            
            return CGSize(width: max(titleFrame.maxX, subtitleFrame.maxX + 16.0), height: 32.0)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
