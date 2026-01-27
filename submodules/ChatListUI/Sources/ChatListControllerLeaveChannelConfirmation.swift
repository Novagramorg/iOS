import Foundation
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ComponentFlow
import AlertComponent
import AlertTransferHeaderComponent
import AvatarComponent
import PeerInfoUI
import OwnershipTransferController

extension ChatListControllerImpl {
    func presentLeaveChannelConfirmation(peer: EnginePeer, nextCreator: EnginePeer, completion: @escaping (Bool) -> Void) {
        Task { @MainActor in
            let accountPeer = await (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))).get()
            
            guard let accountPeer else {
                completion(false)
                return
            }
            
            var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
            content.append(AnyComponentWithIdentity(
                id: "header",
                component: AnyComponent(
                    AlertTransferHeaderComponent(
                        fromComponent: AnyComponentWithIdentity(id: "account", component: AnyComponent(
                            AvatarComponent(
                                context: self.context,
                                theme: self.presentationData.theme,
                                peer: accountPeer
                            )
                        )),
                        toComponent: AnyComponentWithIdentity(id: "user", component: AnyComponent(
                            AvatarComponent(
                                context: self.context,
                                theme: self.presentationData.theme,
                                peer: nextCreator,
                                icon: AnyComponent(
                                    AvatarComponent(
                                        context: self.context,
                                        theme: self.presentationData.theme,
                                        peer: peer
                                    )
                                )
                            )
                        )),
                        type: .transfer
                    )
                )
            ))
            //TODO:localize
            content.append(AnyComponentWithIdentity(
                id: "title",
                component: AnyComponent(
                    AlertTitleComponent(title: "Leave \(peer.compactDisplayTitle)")
                )
            ))
            content.append(AnyComponentWithIdentity(
                id: "text",
                component: AnyComponent(
                    AlertTextComponent(content: .plain("If you leave, **\(nextCreator.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder))** will become the owner of **\(peer.compactDisplayTitle)** in **1 week**."))
                )
            ))
            
            let alertController = AlertScreen(
                context: self.context,
                configuration: .init(actionAlignment: .vertical),
                content: content,
                actions: [
                    .init(title: "Appoint Another Owner", action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.presentOwnershipTransfer(chatPeer: peer)
                    }),
                    .init(title: "Cancel", action: {
                        completion(false)
                    }),
                    .init(title: "Leave Group", type: .destructive, action: {
                        completion(true)
                    })
                ]
            )
            if let topController = self.navigationController?.topViewController as? ViewController {
                topController.present(alertController, in: .window(.root))
            }
        }
    }
    
    func presentOwnershipTransfer(chatPeer: EnginePeer) {
        let presentController: (ViewController) -> Void = { [weak self] c in
            if let topController = self?.navigationController?.topViewController as? ViewController {
                topController.present(c, in: .window(.root))
            }
        }
        let pushController: (ViewController) -> Void = { [weak self] c in
            if let topController = self?.navigationController?.topViewController as? ViewController {
                topController.push(c)
            }
        }
        
        var dismissController: (() -> Void)?
        let controller = ChannelMembersSearchControllerImpl(
            params: ChannelMembersSearchControllerParams(
                context: self.context,
                peerId: chatPeer.id,
                mode: .ownershipTransfer,
                filters: [],
                openPeer: { [weak self] peer, participant in
                    guard let self else {
                        return
                    }
                    if peer.id == self.context.account.peerId {
                        return
                    }
                    if let participant {
                        switch participant.participant {
                        case .creator:
                            return
                        case let .member(_, _, adminInfo, _, _, _):
                            let _ = adminInfo
                            
                            let _ = (self.context.engine.peers.checkOwnershipTranfserAvailability(memberId: peer.id) |> deliverOnMainQueue).start(error: { [weak self] error in
                                guard let self, case let .user(user) = peer else {
                                    return
                                }
                                let controller = channelOwnershipTransferController(
                                    context: self.context,
                                    updatedPresentationData: nil,
                                    peer: chatPeer,
                                    member: user,
                                    initialError: error,
                                    present: { c, a in
                                        presentController(c)
                                    },
                                    push: { c in
                                        pushController(c)
                                    },
                                    completion: { _ in
                                        dismissController?()
                                    }
                                )
                                presentController(controller)
                            })
                        }
                    }
                })
        )
        dismissController = { [weak controller] in
            controller?.dismiss()
        }
        pushController(controller)
    }
}
