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
        public class Cons_exportedInvites {
            public var invites: [Api.ExportedChatlistInvite]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(invites: [Api.ExportedChatlistInvite], chats: [Api.Chat], users: [Api.User]) {
                self.invites = invites
                self.chats = chats
                self.users = users
            }
        }
        case exportedInvites(Cons_exportedInvites)

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
        public class Cons_blocked {
            public var blocked: [Api.PeerBlocked]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(blocked: [Api.PeerBlocked], chats: [Api.Chat], users: [Api.User]) {
                self.blocked = blocked
                self.chats = chats
                self.users = users
            }
        }
        public class Cons_blockedSlice {
            public var count: Int32
            public var blocked: [Api.PeerBlocked]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(count: Int32, blocked: [Api.PeerBlocked], chats: [Api.Chat], users: [Api.User]) {
                self.count = count
                self.blocked = blocked
                self.chats = chats
                self.users = users
            }
        }
        case blocked(Cons_blocked)
        case blockedSlice(Cons_blockedSlice)

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
        public class Cons_contactBirthdays {
            public var contacts: [Api.ContactBirthday]
            public var users: [Api.User]
            public init(contacts: [Api.ContactBirthday], users: [Api.User]) {
                self.contacts = contacts
                self.users = users
            }
        }
        case contactBirthdays(Cons_contactBirthdays)

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
        public class Cons_contacts {
            public var contacts: [Api.Contact]
            public var savedCount: Int32
            public var users: [Api.User]
            public init(contacts: [Api.Contact], savedCount: Int32, users: [Api.User]) {
                self.contacts = contacts
                self.savedCount = savedCount
                self.users = users
            }
        }
        case contacts(Cons_contacts)
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
        public class Cons_found {
            public var myResults: [Api.Peer]
            public var results: [Api.Peer]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(myResults: [Api.Peer], results: [Api.Peer], chats: [Api.Chat], users: [Api.User]) {
                self.myResults = myResults
                self.results = results
                self.chats = chats
                self.users = users
            }
        }
        case found(Cons_found)

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
        public class Cons_importedContacts {
            public var imported: [Api.ImportedContact]
            public var popularInvites: [Api.PopularContact]
            public var retryContacts: [Int64]
            public var users: [Api.User]
            public init(imported: [Api.ImportedContact], popularInvites: [Api.PopularContact], retryContacts: [Int64], users: [Api.User]) {
                self.imported = imported
                self.popularInvites = popularInvites
                self.retryContacts = retryContacts
                self.users = users
            }
        }
        case importedContacts(Cons_importedContacts)

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
        public class Cons_resolvedPeer {
            public var peer: Api.Peer
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(peer: Api.Peer, chats: [Api.Chat], users: [Api.User]) {
                self.peer = peer
                self.chats = chats
                self.users = users
            }
        }
        case resolvedPeer(Cons_resolvedPeer)

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
        public class Cons_sponsoredPeers {
            public var peers: [Api.SponsoredPeer]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(peers: [Api.SponsoredPeer], chats: [Api.Chat], users: [Api.User]) {
                self.peers = peers
                self.chats = chats
                self.users = users
            }
        }
        case sponsoredPeers(Cons_sponsoredPeers)
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
        public class Cons_topPeers {
            public var categories: [Api.TopPeerCategoryPeers]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(categories: [Api.TopPeerCategoryPeers], chats: [Api.Chat], users: [Api.User]) {
                self.categories = categories
                self.chats = chats
                self.users = users
            }
        }
        case topPeers(Cons_topPeers)
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
        public class Cons_collectibleInfo {
            public var purchaseDate: Int32
            public var currency: String
            public var amount: Int64
            public var cryptoCurrency: String
            public var cryptoAmount: Int64
            public var url: String
            public init(purchaseDate: Int32, currency: String, amount: Int64, cryptoCurrency: String, cryptoAmount: Int64, url: String) {
                self.purchaseDate = purchaseDate
                self.currency = currency
                self.amount = amount
                self.cryptoCurrency = cryptoCurrency
                self.cryptoAmount = cryptoAmount
                self.url = url
            }
        }
        case collectibleInfo(Cons_collectibleInfo)

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
        public class Cons_appConfig {
            public var hash: Int32
            public var config: Api.JSONValue
            public init(hash: Int32, config: Api.JSONValue) {
                self.hash = hash
                self.config = config
            }
        }
        case appConfig(Cons_appConfig)
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
