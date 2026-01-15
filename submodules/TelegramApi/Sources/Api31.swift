public extension Api.bots {
    enum BotInfo: TypeConstructorDescription {
        case botInfo(name: String, about: String, description: String)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_botInfo(_ reader: BufferReader) -> BotInfo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.bots {
    enum PopularAppBots: TypeConstructorDescription {
        case popularAppBots(flags: Int32, nextOffset: String?, users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_popularAppBots(_ reader: BufferReader) -> PopularAppBots? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.bots {
    enum PreviewInfo: TypeConstructorDescription {
        case previewInfo(media: [Api.BotPreviewMedia], langCodes: [String])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_previewInfo(_ reader: BufferReader) -> PreviewInfo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.channels {
    enum AdminLogResults: TypeConstructorDescription {
        case adminLogResults(events: [Api.ChannelAdminLogEvent], chats: [Api.Chat], users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_adminLogResults(_ reader: BufferReader) -> AdminLogResults? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.channels {
    enum ChannelParticipant: TypeConstructorDescription {
        case channelParticipant(participant: Api.ChannelParticipant, chats: [Api.Chat], users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_channelParticipant(_ reader: BufferReader) -> ChannelParticipant? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.channels {
    enum ChannelParticipants: TypeConstructorDescription {
        case channelParticipants(count: Int32, participants: [Api.ChannelParticipant], chats: [Api.Chat], users: [Api.User])
        case channelParticipantsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_channelParticipants(_ reader: BufferReader) -> ChannelParticipants? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelParticipantsNotModified(_ reader: BufferReader) -> ChannelParticipants? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.channels {
    enum SendAsPeers: TypeConstructorDescription {
        case sendAsPeers(peers: [Api.SendAsPeer], chats: [Api.Chat], users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_sendAsPeers(_ reader: BufferReader) -> SendAsPeers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.channels {
    enum SponsoredMessageReportResult: TypeConstructorDescription {
        case sponsoredMessageReportResultAdsHidden
        case sponsoredMessageReportResultChooseOption(title: String, options: [Api.SponsoredMessageReportOption])
        case sponsoredMessageReportResultReported

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_sponsoredMessageReportResultAdsHidden(_ reader: BufferReader) -> SponsoredMessageReportResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sponsoredMessageReportResultChooseOption(_ reader: BufferReader) -> SponsoredMessageReportResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sponsoredMessageReportResultReported(_ reader: BufferReader) -> SponsoredMessageReportResult? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.chatlists {
    enum ChatlistInvite: TypeConstructorDescription {
        case chatlistInvite(flags: Int32, title: Api.TextWithEntities, emoticon: String?, peers: [Api.Peer], chats: [Api.Chat], users: [Api.User])
        case chatlistInviteAlready(filterId: Int32, missingPeers: [Api.Peer], alreadyPeers: [Api.Peer], chats: [Api.Chat], users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_chatlistInvite(_ reader: BufferReader) -> ChatlistInvite? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_chatlistInviteAlready(_ reader: BufferReader) -> ChatlistInvite? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.chatlists {
    enum ChatlistUpdates: TypeConstructorDescription {
        case chatlistUpdates(missingPeers: [Api.Peer], chats: [Api.Chat], users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_chatlistUpdates(_ reader: BufferReader) -> ChatlistUpdates? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.chatlists {
    enum ExportedChatlistInvite: TypeConstructorDescription {
        case exportedChatlistInvite(filter: Api.DialogFilter, invite: Api.ExportedChatlistInvite)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_exportedChatlistInvite(_ reader: BufferReader) -> ExportedChatlistInvite? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.chatlists {
    enum ExportedInvites: TypeConstructorDescription {
        case exportedInvites(invites: [Api.ExportedChatlistInvite], chats: [Api.Chat], users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_exportedInvites(_ reader: BufferReader) -> ExportedInvites? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.contacts {
    enum Blocked: TypeConstructorDescription {
        case blocked(blocked: [Api.PeerBlocked], chats: [Api.Chat], users: [Api.User])
        case blockedSlice(count: Int32, blocked: [Api.PeerBlocked], chats: [Api.Chat], users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_blocked(_ reader: BufferReader) -> Blocked? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_blockedSlice(_ reader: BufferReader) -> Blocked? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.contacts {
    enum ContactBirthdays: TypeConstructorDescription {
        case contactBirthdays(contacts: [Api.ContactBirthday], users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_contactBirthdays(_ reader: BufferReader) -> ContactBirthdays? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.contacts {
    enum Contacts: TypeConstructorDescription {
        case contacts(contacts: [Api.Contact], savedCount: Int32, users: [Api.User])
        case contactsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_contacts(_ reader: BufferReader) -> Contacts? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_contactsNotModified(_ reader: BufferReader) -> Contacts? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.contacts {
    enum Found: TypeConstructorDescription {
        case found(myResults: [Api.Peer], results: [Api.Peer], chats: [Api.Chat], users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_found(_ reader: BufferReader) -> Found? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.contacts {
    enum ImportedContacts: TypeConstructorDescription {
        case importedContacts(imported: [Api.ImportedContact], popularInvites: [Api.PopularContact], retryContacts: [Int64], users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_importedContacts(_ reader: BufferReader) -> ImportedContacts? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.contacts {
    enum ResolvedPeer: TypeConstructorDescription {
        case resolvedPeer(peer: Api.Peer, chats: [Api.Chat], users: [Api.User])

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_resolvedPeer(_ reader: BufferReader) -> ResolvedPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.contacts {
    enum SponsoredPeers: TypeConstructorDescription {
        case sponsoredPeers(peers: [Api.SponsoredPeer], chats: [Api.Chat], users: [Api.User])
        case sponsoredPeersEmpty

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_sponsoredPeers(_ reader: BufferReader) -> SponsoredPeers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_sponsoredPeersEmpty(_ reader: BufferReader) -> SponsoredPeers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.contacts {
    enum TopPeers: TypeConstructorDescription {
        case topPeers(categories: [Api.TopPeerCategoryPeers], chats: [Api.Chat], users: [Api.User])
        case topPeersDisabled
        case topPeersNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_topPeers(_ reader: BufferReader) -> TopPeers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_topPeersDisabled(_ reader: BufferReader) -> TopPeers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_topPeersNotModified(_ reader: BufferReader) -> TopPeers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.fragment {
    enum CollectibleInfo: TypeConstructorDescription {
        case collectibleInfo(purchaseDate: Int32, currency: String, amount: Int64, cryptoCurrency: String, cryptoAmount: Int64, url: String)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_collectibleInfo(_ reader: BufferReader) -> CollectibleInfo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.help {
    enum AppConfig: TypeConstructorDescription {
        case appConfig(hash: Int32, config: Api.JSONValue)
        case appConfigNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }

        public static func parse_appConfig(_ reader: BufferReader) -> AppConfig? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_appConfigNotModified(_ reader: BufferReader) -> AppConfig? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
