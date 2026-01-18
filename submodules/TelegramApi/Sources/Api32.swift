public extension Api.bots {
    enum BotInfo: TypeConstructorDescription {
        public class Cons_botInfo {
            public var name: String
            public var about: String
            public var description: String
            public init(name: String, about: String, description: String) {
                self.name = name
                self.about = about
                self.description = description
            }
        }
        case botInfo(Cons_botInfo)

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
        public class Cons_popularAppBots {
            public var flags: Int32
            public var nextOffset: String?
            public var users: [Api.User]
            public init(flags: Int32, nextOffset: String?, users: [Api.User]) {
                self.flags = flags
                self.nextOffset = nextOffset
                self.users = users
            }
        }
        case popularAppBots(Cons_popularAppBots)

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
        public class Cons_previewInfo {
            public var media: [Api.BotPreviewMedia]
            public var langCodes: [String]
            public init(media: [Api.BotPreviewMedia], langCodes: [String]) {
                self.media = media
                self.langCodes = langCodes
            }
        }
        case previewInfo(Cons_previewInfo)

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
        public class Cons_adminLogResults {
            public var events: [Api.ChannelAdminLogEvent]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(events: [Api.ChannelAdminLogEvent], chats: [Api.Chat], users: [Api.User]) {
                self.events = events
                self.chats = chats
                self.users = users
            }
        }
        case adminLogResults(Cons_adminLogResults)

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
        public class Cons_channelParticipant {
            public var participant: Api.ChannelParticipant
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(participant: Api.ChannelParticipant, chats: [Api.Chat], users: [Api.User]) {
                self.participant = participant
                self.chats = chats
                self.users = users
            }
        }
        case channelParticipant(Cons_channelParticipant)

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
        public class Cons_channelParticipants {
            public var count: Int32
            public var participants: [Api.ChannelParticipant]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(count: Int32, participants: [Api.ChannelParticipant], chats: [Api.Chat], users: [Api.User]) {
                self.count = count
                self.participants = participants
                self.chats = chats
                self.users = users
            }
        }
        case channelParticipants(Cons_channelParticipants)
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
        public class Cons_sendAsPeers {
            public var peers: [Api.SendAsPeer]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(peers: [Api.SendAsPeer], chats: [Api.Chat], users: [Api.User]) {
                self.peers = peers
                self.chats = chats
                self.users = users
            }
        }
        case sendAsPeers(Cons_sendAsPeers)

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
        public class Cons_sponsoredMessageReportResultChooseOption {
            public var title: String
            public var options: [Api.SponsoredMessageReportOption]
            public init(title: String, options: [Api.SponsoredMessageReportOption]) {
                self.title = title
                self.options = options
            }
        }
        case sponsoredMessageReportResultAdsHidden
        case sponsoredMessageReportResultChooseOption(Cons_sponsoredMessageReportResultChooseOption)
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
        public class Cons_chatlistInvite {
            public var flags: Int32
            public var title: Api.TextWithEntities
            public var emoticon: String?
            public var peers: [Api.Peer]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, title: Api.TextWithEntities, emoticon: String?, peers: [Api.Peer], chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.title = title
                self.emoticon = emoticon
                self.peers = peers
                self.chats = chats
                self.users = users
            }
        }
        public class Cons_chatlistInviteAlready {
            public var filterId: Int32
            public var missingPeers: [Api.Peer]
            public var alreadyPeers: [Api.Peer]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(filterId: Int32, missingPeers: [Api.Peer], alreadyPeers: [Api.Peer], chats: [Api.Chat], users: [Api.User]) {
                self.filterId = filterId
                self.missingPeers = missingPeers
                self.alreadyPeers = alreadyPeers
                self.chats = chats
                self.users = users
            }
        }
        case chatlistInvite(Cons_chatlistInvite)
        case chatlistInviteAlready(Cons_chatlistInviteAlready)

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
        public class Cons_chatlistUpdates {
            public var missingPeers: [Api.Peer]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(missingPeers: [Api.Peer], chats: [Api.Chat], users: [Api.User]) {
                self.missingPeers = missingPeers
                self.chats = chats
                self.users = users
            }
        }
        case chatlistUpdates(Cons_chatlistUpdates)

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
        public class Cons_exportedChatlistInvite {
            public var filter: Api.DialogFilter
            public var invite: Api.ExportedChatlistInvite
            public init(filter: Api.DialogFilter, invite: Api.ExportedChatlistInvite) {
                self.filter = filter
                self.invite = invite
            }
        }
        case exportedChatlistInvite(Cons_exportedChatlistInvite)

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
