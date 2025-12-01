import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramUIPreferences
import TelegramCallsUI

public final class GlobalControlPanelsContext {
    public final class MediaPlayback: Equatable {
        public let version: Int
        public let item: SharedMediaPlaylistItem
        public let previousItem: SharedMediaPlaylistItem?
        public let nextItem: SharedMediaPlaylistItem?
        public let playbackOrder: MusicPlaybackSettingsOrder
        public let kind: MediaManagerPlayerType
        public let playlistLocation: SharedMediaPlaylistLocation
        public let account: Account
        
        public init(version: Int, item: SharedMediaPlaylistItem, previousItem: SharedMediaPlaylistItem?, nextItem: SharedMediaPlaylistItem?, playbackOrder: MusicPlaybackSettingsOrder, kind: MediaManagerPlayerType, playlistLocation: SharedMediaPlaylistLocation, account: Account) {
            self.version = version
            self.item = item
            self.previousItem = previousItem
            self.nextItem = nextItem
            self.playbackOrder = playbackOrder
            self.kind = kind
            self.playlistLocation = playlistLocation
            self.account = account
        }
        
        public static func ==(lhs: MediaPlayback, rhs: MediaPlayback) -> Bool {
            if lhs.version != rhs.version {
                return false
            }
            return true
        }
    }
    
    public enum LiveLocationMode {
        case all
        case peer(EnginePeer.Id)
    }
    
    public final class LiveLocation: Equatable {
        public let mode: LiveLocationMode
        public let peers: [EnginePeer]
        public let messages: [EngineMessage.Id: EngineMessage]
        public let canClose: Bool
        public let version: Int
        
        public init(mode: LiveLocationMode, peers: [EnginePeer], messages: [EngineMessage.Id: EngineMessage], canClose: Bool, version: Int) {
            self.mode = mode
            self.peers = peers
            self.messages = messages
            self.canClose = canClose
            self.version = version
        }
        
        public static func ==(lhs: LiveLocation, rhs: LiveLocation) -> Bool {
            if lhs.version != rhs.version {
                return false
            }
            return true
        }
    }

    public final class State {
        public let mediaPlayback: MediaPlayback?
        public let liveLocation: LiveLocation?

        public init(
            mediaPlayback: MediaPlayback?,
            liveLocation: LiveLocation?
        ) {
            self.mediaPlayback = mediaPlayback
            self.liveLocation = liveLocation
        }
    }

    private final class Impl {
        let queue: Queue
        let context: AccountContext
        
        private(set) var stateValue: State
        let statePipe = ValuePipe<State>()
        
        private var nextVersion: Int = 0

        var tempVoicePlaylistEnded: (() -> Void)?
        var tempVoicePlaylistItemChanged: ((SharedMediaPlaylistItem?, SharedMediaPlaylistItem?) -> Void)?
        var tempVoicePlaylistCurrentItem: SharedMediaPlaylistItem?
        
        var playlistStateAndType: (SharedMediaPlaylistItem, SharedMediaPlaylistItem?, SharedMediaPlaylistItem?, MusicPlaybackSettingsOrder, MediaManagerPlayerType, Account, SharedMediaPlaylistLocation, Int)?
        var mediaStatusDisposable: Disposable?
        
        var liveLocationState: (mode: LiveLocationMode, peers: [EnginePeer], messages: [EngineMessage.Id: EngineMessage], canClose: Bool, version: Int)?
        var liveLocationDisposable: Disposable?

        init(queue: Queue, context: AccountContext, mediaPlayback: Bool, liveLocationMode: LiveLocationMode?, groupCalls: GroupCallPanelSource?) {
            self.queue = queue
            self.context = context
            
            self.stateValue = State(mediaPlayback: nil, liveLocation: nil)

            if mediaPlayback {
                self.mediaStatusDisposable = (context.sharedContext.mediaManager.globalMediaPlayerState
                |> mapToSignal { playlistStateAndType -> Signal<(Account, SharedMediaPlayerItemPlaybackState, MediaManagerPlayerType)?, NoError> in
                    if let (account, state, type) = playlistStateAndType {
                        switch state {
                        case let .state(state):
                            return .single((account, state, type))
                        case .loading:
                            return .single(nil) |> delay(0.2, queue: .mainQueue())
                        }
                    } else {
                        return .single(nil)
                    }
                }
                |> deliverOnMainQueue).start(next: { [weak self] playlistStateAndType in
                    guard let strongSelf = self else {
                        return
                    }
                    if !arePlaylistItemsEqual(strongSelf.playlistStateAndType?.0, playlistStateAndType?.1.item) ||
                        !arePlaylistItemsEqual(strongSelf.playlistStateAndType?.1, playlistStateAndType?.1.previousItem) ||
                        !arePlaylistItemsEqual(strongSelf.playlistStateAndType?.2, playlistStateAndType?.1.nextItem) ||
                        strongSelf.playlistStateAndType?.3 != playlistStateAndType?.1.order || strongSelf.playlistStateAndType?.4 != playlistStateAndType?.2 {
                        var previousVoiceItem: SharedMediaPlaylistItem?
                        if let playlistStateAndType = strongSelf.playlistStateAndType, playlistStateAndType.4 == .voice {
                            previousVoiceItem = playlistStateAndType.0
                        }
                        
                        var updatedVoiceItem: SharedMediaPlaylistItem?
                        if let playlistStateAndType = playlistStateAndType, playlistStateAndType.2 == .voice {
                            updatedVoiceItem = playlistStateAndType.1.item
                        }
                        
                        strongSelf.tempVoicePlaylistCurrentItem = updatedVoiceItem
                        strongSelf.tempVoicePlaylistItemChanged?(previousVoiceItem, updatedVoiceItem)
                        if let playlistStateAndType = playlistStateAndType {
                            strongSelf.playlistStateAndType = (playlistStateAndType.1.item, playlistStateAndType.1.previousItem, playlistStateAndType.1.nextItem, playlistStateAndType.1.order, playlistStateAndType.2, playlistStateAndType.0, playlistStateAndType.1.playlistLocation, 0)
                        } else {
                            var voiceEnded = false
                            if strongSelf.playlistStateAndType?.4 == .voice {
                                voiceEnded = true
                            }
                            strongSelf.playlistStateAndType = nil
                            if voiceEnded {
                                strongSelf.tempVoicePlaylistEnded?()
                            }
                        }
                        strongSelf.playlistStateAndType?.7 = strongSelf.nextVersion
                        strongSelf.nextVersion += 1
                        strongSelf.notifyStateUpdated()
                    }
                })
            }
            
            if let liveLocationMode, let liveLocationManager = context.liveLocationManager {
                let signal: Signal<([EnginePeer]?, [EngineMessage.Id: EngineMessage]?), NoError>
                switch liveLocationMode {
                case let .peer(peerId):
                    signal = combineLatest(liveLocationManager.summaryManager.peersBroadcastingTo(peerId: peerId), liveLocationManager.summaryManager.broadcastingToMessages())
                    |> map { peersAndMessages, outgoingMessages in
                        var peers = peersAndMessages?.map { $0.0 }
                        for message in outgoingMessages.values {
                            if message.id.peerId == peerId, let author = message.author {
                                if peers == nil {
                                    peers = []
                                }
                                peers?.append(author)
                            }
                        }
                        return (peers, outgoingMessages)
                    }
                case .all:
                    signal = liveLocationManager.summaryManager.broadcastingToMessages()
                    |> map { messages -> ([EnginePeer]?, [EngineMessage.Id: EngineMessage]?) in
                        if messages.isEmpty {
                            return (nil, nil)
                        } else {
                            var peers: [EnginePeer] = []
                            for message in messages.values.sorted(by: { $0.index < $1.index }) {
                                if let peer = message.peers[message.id.peerId] {
                                    peers.append(EnginePeer(peer))
                                }
                            }
                            return (peers, messages)
                        }
                    }
                }
                
                self.liveLocationDisposable = (signal
                |> deliverOnMainQueue).start(next: { [weak self] peers, messages in
                    guard let self else {
                        return
                    }
                    var updated = false
                    if let current = self.liveLocationState?.peers, let peers {
                        updated = current != peers
                    } else if (self.liveLocationState != nil) != (peers != nil) {
                        updated = true
                    }
                    
                    if updated {
                        if let peers, let messages {
                            var canClose = true
                            if case let .peer(peerId) = liveLocationMode {
                                canClose = false
                                for messageId in messages.keys {
                                    if messageId.peerId == peerId {
                                        canClose = true
                                    }
                                }
                            }
                            
                            self.liveLocationState = (
                                mode: liveLocationMode,
                                peers: peers,
                                messages: messages,
                                canClose: canClose,
                                version: self.nextVersion
                            )
                            self.nextVersion += 1
                        } else {
                            self.liveLocationState = nil
                        }
                        self.notifyStateUpdated()
                    }
                })
            }
        }

        deinit {
            self.mediaStatusDisposable?.dispose()
            self.liveLocationDisposable?.dispose()
        }
        
        private func notifyStateUpdated() {
            self.stateValue = State(
                mediaPlayback: self.playlistStateAndType.flatMap { playlistStateAndType in
                    return MediaPlayback(
                        version: playlistStateAndType.7,
                        item: playlistStateAndType.0,
                        previousItem: playlistStateAndType.1,
                        nextItem: playlistStateAndType.2,
                        playbackOrder: playlistStateAndType.3,
                        kind: playlistStateAndType.4,
                        playlistLocation: playlistStateAndType.6,
                        account: playlistStateAndType.5
                    )
                },
                liveLocation: self.liveLocationState.flatMap { liveLocationState in
                    return GlobalControlPanelsContext.LiveLocation(
                        mode: liveLocationState.mode,
                        peers: liveLocationState.peers,
                        messages: liveLocationState.messages,
                        canClose: liveLocationState.canClose,
                        version: liveLocationState.version
                    )
                }
            )
            self.statePipe.putNext(self.stateValue)
        }
    }

    private let impl: QueueLocalObject<Impl>
    public var state: Signal<State, NoError> {
        return self.impl.signalWith { impl, subscriber in
            subscriber.putNext(impl.stateValue)
            return impl.statePipe.signal().start(next: subscriber.putNext)
        }
    }

    public init(context: AccountContext, mediaPlayback: Bool, liveLocationMode: LiveLocationMode?, groupCalls: GroupCallPanelSource?) {
        self.impl = QueueLocalObject(queue: .mainQueue(), generate: {
            return Impl(queue: .mainQueue(), context: context, mediaPlayback: mediaPlayback, liveLocationMode: liveLocationMode, groupCalls: groupCalls)
        })
    }
}
