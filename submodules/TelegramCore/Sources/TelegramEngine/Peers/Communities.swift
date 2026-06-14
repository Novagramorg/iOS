import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum CreateCommunityError {
    case generic
    case adminRequired
}

public enum CommunityPeerLinkAction: Equatable {
    case link(visible: Bool)
    case unlink
}

public enum CommunityPeerLinkError {
    case generic
    case adminRequired
    case requestCreated
}

public enum CommunityPeerRequestApprovalError {
    case generic
    case adminRequired
}

public enum CommunityParticipantBannedError {
    case generic
    case adminRequired
}

public enum CommunityCollapsedInDialogsError {
    case generic
}

public struct CommunitiesState: Codable, Equatable {
    public let communityIds: [EnginePeer.Id]?

    public static let `default` = CommunitiesState(communityIds: nil)

    public init(communityIds: [EnginePeer.Id]?) {
        self.communityIds = communityIds
    }
}

public struct CommunityPeerRequest: Equatable {
    public let peerId: EnginePeer.Id
    public let requestedBy: EnginePeer.Id
    public let date: Int32
    public let isVisible: Bool

    public init(peerId: EnginePeer.Id, requestedBy: EnginePeer.Id, date: Int32, isVisible: Bool) {
        self.peerId = peerId
        self.requestedBy = requestedBy
        self.date = date
        self.isVisible = isVisible
    }
}

public struct CommunityPeerLinkRequests: Equatable {
    public let totalCount: Int32
    public let requests: [CommunityPeerRequest]
    public let nextOffset: String?
    public let peers: [EnginePeer.Id: EnginePeer]

    public init(totalCount: Int32, requests: [CommunityPeerRequest], nextOffset: String?, peers: [EnginePeer.Id: EnginePeer]) {
        self.totalCount = totalCount
        self.requests = requests
        self.nextOffset = nextOffset
        self.peers = peers
    }
}

public struct CommunityParticipantJoinedChats: Equatable {
    public let creatorChatIds: [EnginePeer.Id]
    public let joinedChatIds: [EnginePeer.Id]
    public let peers: [EnginePeer.Id: EnginePeer]

    public init(creatorChatIds: [EnginePeer.Id], joinedChatIds: [EnginePeer.Id], peers: [EnginePeer.Id: EnginePeer]) {
        self.creatorChatIds = creatorChatIds
        self.joinedChatIds = joinedChatIds
        self.peers = peers
    }
}

private func apiPeer(_ peerId: PeerId) -> Api.Peer? {
    switch peerId.namespace {
    case Namespaces.Peer.CloudUser:
        return .peerUser(.init(userId: peerId.id._internalGetInt64Value()))
    case Namespaces.Peer.CloudGroup:
        return .peerChat(.init(chatId: peerId.id._internalGetInt64Value()))
    case Namespaces.Peer.CloudChannel:
        return .peerChannel(.init(channelId: peerId.id._internalGetInt64Value()))
    default:
        return nil
    }
}

private func communityInputChannel(transaction: Transaction, communityId: PeerId) -> Api.InputChannel? {
    guard let peer = transaction.getPeer(communityId) else {
        return nil
    }
    return apiInputChannel(peer)
}

private func inputPeer(transaction: Transaction, peerId: PeerId) -> Api.InputPeer? {
    guard let peer = transaction.getPeer(peerId) else {
        return nil
    }
    return apiInputPeer(peer)
}

private func communitiesChats(_ result: Api.messages.Chats) -> [Api.Chat] {
    switch result {
    case let .chats(chatsData):
        return chatsData.chats
    case let .chatsSlice(chatsSliceData):
        return chatsSliceData.chats
    }
}

func _internal_updatedCommunitiesState(postbox: Postbox) -> Signal<CommunitiesState, NoError> {
    return postbox.preferencesView(keys: [PreferencesKeys.communitiesState])
    |> map { preferences -> CommunitiesState in
        return preferences.values[PreferencesKeys.communitiesState]?.get(CommunitiesState.self) ?? .default
    }
    |> distinctUntilChanged
}

func _internal_currentCommunitiesState(transaction: Transaction) -> CommunitiesState {
    return transaction.getPreferencesEntry(key: PreferencesKeys.communitiesState)?.get(CommunitiesState.self) ?? .default
}

func updateCommunitiesState(transaction: Transaction, _ f: (CommunitiesState) -> CommunitiesState) -> CommunitiesState {
    var result: CommunitiesState?
    transaction.updatePreferencesEntry(key: PreferencesKeys.communitiesState, { entry in
        let current = entry?.get(CommunitiesState.self) ?? .default
        let updated = f(current)
        result = updated
        return PreferencesEntry(updated)
    })
    return result ?? .default
}

private func _internal_loadJoinedCommunities(postbox: Postbox, network: Network, accountPeerId: PeerId) -> Signal<[EnginePeer], NoError> {
    return network.request(Api.functions.communities.getJoinedCommunities())
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.messages.Chats?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<[EnginePeer], NoError> in
        guard let result else {
            return .single([])
        }

        let chats = communitiesChats(result)

        return postbox.transaction { transaction -> [EnginePeer] in
            let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: [])
            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)

            var communityIds: [PeerId] = []
            var peers: [EnginePeer] = []
            for chat in chats {
                guard let peer = transaction.getPeer(chat.peerId), peer is TelegramCommunity else {
                    continue
                }
                communityIds.append(peer.id)
                peers.append(EnginePeer(peer))
            }

            let _ = updateCommunitiesState(transaction: transaction, { _ in
                return CommunitiesState(communityIds: communityIds)
            })

            return peers
        }
    }
}

func managedCommunitiesState(postbox: Postbox, network: Network, accountPeerId: PeerId) -> Signal<Never, NoError> {
    return _internal_loadJoinedCommunities(postbox: postbox, network: network, accountPeerId: accountPeerId)
    |> ignoreValues
}

func _internal_createCommunity(account: Account, title: String, about: String?, peerId: PeerId) -> Signal<PeerId, CreateCommunityError> {
    return account.postbox.transaction { transaction -> Signal<PeerId, CreateCommunityError> in
        guard let inputPeer = inputPeer(transaction: transaction, peerId: peerId) else {
            return .fail(.generic)
        }

        var flags: Int32 = 0
        if about != nil {
            flags |= 1 << 0
        }

        return account.network.request(Api.functions.communities.create(flags: flags, title: title, about: about, peer: inputPeer))
        |> mapError { error -> CreateCommunityError in
            if error.errorDescription == "CHAT_ADMIN_REQUIRED" {
                return .adminRequired
            }
            return .generic
        }
        |> mapToSignal { updates -> Signal<PeerId, CreateCommunityError> in
            account.stateManager.addUpdates(updates)
            if let peer = updates.chats.compactMap({ parseTelegramGroupOrChannel(chat: $0) as? TelegramCommunity }).first {
                let communityId = peer.id
                return account.postbox.transaction { transaction -> PeerId in
                    let state = _internal_currentCommunitiesState(transaction: transaction)
                    if var communityIds = state.communityIds, !communityIds.contains(communityId) {
                        communityIds.append(communityId)
                        let _ = updateCommunitiesState(transaction: transaction, { _ in
                            return CommunitiesState(communityIds: communityIds)
                        })
                    }
                    return communityId
                }
                |> castError(CreateCommunityError.self)
            } else {
                return .fail(.generic)
            }
        }
    }
    |> castError(CreateCommunityError.self)
    |> switchToLatest
}

func _internal_joinedCommunities(account: Account) -> Signal<[EnginePeer], NoError> {
    return _internal_loadJoinedCommunities(postbox: account.postbox, network: account.network, accountPeerId: account.peerId)
}

func _internal_toggleCommunityPeerLink(account: Account, communityId: PeerId, peerId: PeerId, action: CommunityPeerLinkAction) -> Signal<Never, CommunityPeerLinkError> {
    return account.postbox.transaction { transaction -> Signal<Never, CommunityPeerLinkError> in
        guard let inputCommunity = communityInputChannel(transaction: transaction, communityId: communityId), let inputPeer = inputPeer(transaction: transaction, peerId: peerId) else {
            return .fail(.generic)
        }

        let flags: Int32
        switch action {
        case let .link(visible):
            flags = visible ? (1 << 0) : (1 << 1)
        case .unlink:
            flags = 1 << 2
        }

        return account.network.request(Api.functions.communities.togglePeerLink(flags: flags, community: inputCommunity, peer: inputPeer))
        |> mapError { error -> CommunityPeerLinkError in
            switch error.errorDescription {
            case "COMMUNITY_REQUEST_CREATED":
                return .requestCreated
            case "CHAT_ADMIN_REQUIRED":
                return .adminRequired
            default:
                return .generic
            }
        }
        |> ignoreValues
    }
    |> castError(CommunityPeerLinkError.self)
    |> switchToLatest
}

func _internal_communityPeerLinkRequests(account: Account, communityId: PeerId, offset: String?, limit: Int32) -> Signal<CommunityPeerLinkRequests, NoError> {
    return account.postbox.transaction { transaction -> Api.InputChannel? in
        return communityInputChannel(transaction: transaction, communityId: communityId)
    }
    |> mapToSignal { inputCommunity -> Signal<Api.communities.PeerLinkRequests?, NoError> in
        guard let inputCommunity else {
            return .single(nil)
        }
        return account.network.request(Api.functions.communities.getPeerLinkRequests(community: inputCommunity, offset: offset ?? "", limit: limit))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.communities.PeerLinkRequests?, NoError> in
            return .single(nil)
        }
    }
    |> mapToSignal { result -> Signal<CommunityPeerLinkRequests, NoError> in
        guard let result else {
            return .single(CommunityPeerLinkRequests(totalCount: 0, requests: [], nextOffset: nil, peers: [:]))
        }

        switch result {
        case let .peerLinkRequests(peerLinkRequestsData):
            let (totalCount, apiRequests, nextOffset, chats, users) = (peerLinkRequestsData.totalCount, peerLinkRequestsData.requests, peerLinkRequestsData.nextOffset, peerLinkRequestsData.chats, peerLinkRequestsData.users)
            return account.postbox.transaction { transaction -> CommunityPeerLinkRequests in
                let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)

                let requests = apiRequests.map { request -> CommunityPeerRequest in
                    switch request {
                    case let .communityPeerRequest(requestData):
                        return CommunityPeerRequest(
                            peerId: requestData.peer.peerId,
                            requestedBy: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(requestData.requestedBy)),
                            date: requestData.date,
                            isVisible: (requestData.flags & (1 << 0)) != 0
                        )
                    }
                }

                var peerIds = Set<PeerId>()
                for request in requests {
                    peerIds.insert(request.peerId)
                    peerIds.insert(request.requestedBy)
                }
                for chat in chats {
                    peerIds.insert(chat.peerId)
                }
                for user in users {
                    peerIds.insert(user.peerId)
                }

                var peers: [EnginePeer.Id: EnginePeer] = [:]
                for peerId in peerIds {
                    if let peer = transaction.getPeer(peerId) {
                        peers[peerId] = EnginePeer(peer)
                    }
                }

                return CommunityPeerLinkRequests(totalCount: totalCount, requests: requests, nextOffset: nextOffset, peers: peers)
            }
        }
    }
}

func _internal_toggleCommunityPeerLinkRequestApproval(account: Account, communityId: PeerId, peerId: PeerId, approve: Bool) -> Signal<Never, CommunityPeerRequestApprovalError> {
    return account.postbox.transaction { transaction -> Signal<Never, CommunityPeerRequestApprovalError> in
        guard let inputCommunity = communityInputChannel(transaction: transaction, communityId: communityId), let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }

        let flags: Int32 = approve ? 0 : (1 << 0)
        return account.network.request(Api.functions.communities.togglePeerLinkRequestApproval(flags: flags, community: inputCommunity, peer: inputPeer))
        |> mapError { error -> CommunityPeerRequestApprovalError in
            if error.errorDescription == "CHAT_ADMIN_REQUIRED" {
                return .adminRequired
            }
            return .generic
        }
        |> ignoreValues
    }
    |> castError(CommunityPeerRequestApprovalError.self)
    |> switchToLatest
}

func _internal_toggleAllCommunityPeerLinkRequestApproval(account: Account, communityId: PeerId, approve: Bool) -> Signal<Never, CommunityPeerRequestApprovalError> {
    return account.postbox.transaction { transaction -> Signal<Never, CommunityPeerRequestApprovalError> in
        guard let inputCommunity = communityInputChannel(transaction: transaction, communityId: communityId) else {
            return .fail(.generic)
        }

        let flags: Int32 = approve ? 0 : (1 << 0)
        return account.network.request(Api.functions.communities.toggleAllPeerLinkRequestApproval(flags: flags, community: inputCommunity))
        |> mapError { error -> CommunityPeerRequestApprovalError in
            if error.errorDescription == "CHAT_ADMIN_REQUIRED" {
                return .adminRequired
            }
            return .generic
        }
        |> ignoreValues
    }
    |> castError(CommunityPeerRequestApprovalError.self)
    |> switchToLatest
}

func _internal_toggleCommunityParticipantBanned(account: Account, communityId: PeerId, participantId: PeerId, banned: Bool) -> Signal<Never, CommunityParticipantBannedError> {
    return account.postbox.transaction { transaction -> Signal<Never, CommunityParticipantBannedError> in
        guard let inputCommunity = communityInputChannel(transaction: transaction, communityId: communityId), let inputParticipant = inputPeer(transaction: transaction, peerId: participantId) else {
            return .fail(.generic)
        }

        let flags: Int32 = banned ? 0 : (1 << 0)
        return account.network.request(Api.functions.communities.toggleParticipantBanned(flags: flags, community: inputCommunity, participant: inputParticipant))
        |> mapError { error -> CommunityParticipantBannedError in
            if error.errorDescription == "CHAT_ADMIN_REQUIRED" {
                return .adminRequired
            }
            return .generic
        }
        |> ignoreValues
    }
    |> castError(CommunityParticipantBannedError.self)
    |> switchToLatest
}

func _internal_toggleCommunityCollapsedInDialogs(account: Account, communityId: PeerId, collapsed: Bool) -> Signal<Never, CommunityCollapsedInDialogsError> {
    return account.postbox.transaction { transaction -> Signal<Never, CommunityCollapsedInDialogsError> in
        guard let inputCommunity = communityInputChannel(transaction: transaction, communityId: communityId) else {
            return .fail(.generic)
        }

        let flags: Int32 = collapsed ? (1 << 0) : 0
        return account.network.request(Api.functions.communities.toggleCommunityCollapsedInDialogs(flags: flags, community: inputCommunity))
        |> mapError { _ -> CommunityCollapsedInDialogsError in
            return .generic
        }
        |> mapToSignal { updates -> Signal<Never, CommunityCollapsedInDialogsError> in
            let updatedUpdates: Api.Updates
            let communityIdValue = communityId.id._internalGetInt64Value()
            let updatedCollapsedInDialogs: Api.Bool = collapsed ? .boolTrue : .boolFalse
            switch updates {
            case let .updates(updatesData):
                let updatedChats = updatesData.chats.map { chat -> Api.Chat in
                    if case let .community(communityData) = chat, communityData.id == communityIdValue {
                        return .community(Api.Chat.Cons_community(
                            flags: communityData.flags,
                            flags2: communityData.flags2 | (1 << 20),
                            collapsedInDialogs: updatedCollapsedInDialogs,
                            id: communityData.id,
                            accessHash: communityData.accessHash,
                            title: communityData.title,
                            photo: communityData.photo,
                            date: communityData.date,
                            adminRights: communityData.adminRights,
                            defaultBannedRights: communityData.defaultBannedRights
                        ))
                    }
                    return chat
                }
                updatedUpdates = .updates(Api.Updates.Cons_updates(
                    updates: updatesData.updates,
                    users: updatesData.users,
                    chats: updatedChats,
                    date: updatesData.date,
                    seq: updatesData.seq
                ))
            case let .updatesCombined(updatesData):
                let updatedChats = updatesData.chats.map { chat -> Api.Chat in
                    if case let .community(communityData) = chat, communityData.id == communityIdValue {
                        return .community(Api.Chat.Cons_community(
                            flags: communityData.flags,
                            flags2: communityData.flags2 | (1 << 20),
                            collapsedInDialogs: updatedCollapsedInDialogs,
                            id: communityData.id,
                            accessHash: communityData.accessHash,
                            title: communityData.title,
                            photo: communityData.photo,
                            date: communityData.date,
                            adminRights: communityData.adminRights,
                            defaultBannedRights: communityData.defaultBannedRights
                        ))
                    }
                    return chat
                }
                updatedUpdates = .updatesCombined(Api.Updates.Cons_updatesCombined(
                    updates: updatesData.updates,
                    users: updatesData.users,
                    chats: updatedChats,
                    date: updatesData.date,
                    seqStart: updatesData.seqStart,
                    seq: updatesData.seq
                ))
            default:
                updatedUpdates = updates
            }
            account.stateManager.addUpdates(updatedUpdates)
            return account.postbox.transaction { transaction -> Void in
                if var community = transaction.getPeer(communityId) as? TelegramCommunity {
                    community = community.withUpdatedCollapsedInDialogs(collapsed)
                    transaction.updatePeersInternal([community]) { _, peer in
                        return peer
                    }
                    updateCommunityChatListInclusion(transaction: transaction, community: community, minTimestamp: minTimestampForPeerInclusion(community))
                }
                if let cachedData = transaction.getPeerCachedData(peerId: communityId) as? CachedCommunityData {
                    var linkedPeerIds = Set<PeerId>()
                    for linkedPeer in cachedData.linkedPeers {
                        if linkedPeer.peerId != communityId {
                            linkedPeerIds.insert(linkedPeer.peerId)
                        }
                    }
                    for peerId in linkedPeerIds {
                        if collapsed {
                            transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
                        } else if shouldExcludePeerFromChatListDueToCollapsedCommunity(transaction: transaction, peerId: peerId) {
                            transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
                        } else if let peer = transaction.getPeer(peerId) {
                            transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(
                                groupId: .root,
                                pinningIndex: transaction.getPeerChatListIndex(peerId)?.1.pinningIndex,
                                minTimestamp: minTimestampForPeerInclusion(peer)
                            ))
                        }
                    }
                }
            }
            |> castError(CommunityCollapsedInDialogsError.self)
            |> ignoreValues
        }
    }
    |> castError(CommunityCollapsedInDialogsError.self)
    |> switchToLatest
}

func _internal_communityParticipantJoinedChats(account: Account, communityId: PeerId, participantId: PeerId) -> Signal<CommunityParticipantJoinedChats, NoError> {
    return account.postbox.transaction { transaction -> (Api.InputChannel?, Api.InputPeer?) in
        return (
            communityInputChannel(transaction: transaction, communityId: communityId),
            inputPeer(transaction: transaction, peerId: participantId)
        )
    }
    |> mapToSignal { inputCommunity, inputParticipant -> Signal<Api.communities.ParticipantJoinedChats?, NoError> in
        guard let inputCommunity, let inputParticipant else {
            return .single(nil)
        }
        return account.network.request(Api.functions.communities.getParticipantJoinedChats(community: inputCommunity, participant: inputParticipant))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.communities.ParticipantJoinedChats?, NoError> in
            return .single(nil)
        }
    }
    |> mapToSignal { result -> Signal<CommunityParticipantJoinedChats, NoError> in
        guard let result else {
            return .single(CommunityParticipantJoinedChats(creatorChatIds: [], joinedChatIds: [], peers: [:]))
        }

        switch result {
        case let .participantJoinedChats(participantJoinedChatsData):
            let (creatorChatIds, joinedChatIds, chats, users) = (participantJoinedChatsData.creatorChatIds, participantJoinedChatsData.joinedChatIds, participantJoinedChatsData.chats, participantJoinedChatsData.users)
            return account.postbox.transaction { transaction -> CommunityParticipantJoinedChats in
                let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)

                let mappedCreatorChatIds = creatorChatIds.map { PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value($0)) }
                let mappedJoinedChatIds = joinedChatIds.map { PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value($0)) }
                let allPeerIds = Set(mappedCreatorChatIds + mappedJoinedChatIds)

                var peers: [EnginePeer.Id: EnginePeer] = [:]
                for peerId in allPeerIds {
                    if let peer = transaction.getPeer(peerId) {
                        peers[peerId] = EnginePeer(peer)
                    }
                }

                return CommunityParticipantJoinedChats(creatorChatIds: mappedCreatorChatIds, joinedChatIds: mappedJoinedChatIds, peers: peers)
            }
        }
    }
}
