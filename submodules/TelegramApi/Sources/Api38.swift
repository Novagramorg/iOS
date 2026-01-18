public extension Api.phone {
    enum JoinAsPeers: TypeConstructorDescription {
        public class Cons_joinAsPeers {
            public var peers: [Api.Peer]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(peers: [Api.Peer], chats: [Api.Chat], users: [Api.User]) {
                self.peers = peers
                self.chats = chats
                self.users = users
            }
        }
        case joinAsPeers(Cons_joinAsPeers)

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

        public static func parse_joinAsPeers(_ reader: BufferReader) -> JoinAsPeers? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.phone {
    enum PhoneCall: TypeConstructorDescription {
        public class Cons_phoneCall {
            public var phoneCall: Api.PhoneCall
            public var users: [Api.User]
            public init(phoneCall: Api.PhoneCall, users: [Api.User]) {
                self.phoneCall = phoneCall
                self.users = users
            }
        }
        case phoneCall(Cons_phoneCall)

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

        public static func parse_phoneCall(_ reader: BufferReader) -> PhoneCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.photos {
    enum Photo: TypeConstructorDescription {
        public class Cons_photo {
            public var photo: Api.Photo
            public var users: [Api.User]
            public init(photo: Api.Photo, users: [Api.User]) {
                self.photo = photo
                self.users = users
            }
        }
        case photo(Cons_photo)

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

        public static func parse_photo(_ reader: BufferReader) -> Photo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.photos {
    enum Photos: TypeConstructorDescription {
        public class Cons_photos {
            public var photos: [Api.Photo]
            public var users: [Api.User]
            public init(photos: [Api.Photo], users: [Api.User]) {
                self.photos = photos
                self.users = users
            }
        }
        public class Cons_photosSlice {
            public var count: Int32
            public var photos: [Api.Photo]
            public var users: [Api.User]
            public init(count: Int32, photos: [Api.Photo], users: [Api.User]) {
                self.count = count
                self.photos = photos
                self.users = users
            }
        }
        case photos(Cons_photos)
        case photosSlice(Cons_photosSlice)

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

        public static func parse_photos(_ reader: BufferReader) -> Photos? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_photosSlice(_ reader: BufferReader) -> Photos? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.premium {
    enum BoostsList: TypeConstructorDescription {
        public class Cons_boostsList {
            public var flags: Int32
            public var count: Int32
            public var boosts: [Api.Boost]
            public var nextOffset: String?
            public var users: [Api.User]
            public init(flags: Int32, count: Int32, boosts: [Api.Boost], nextOffset: String?, users: [Api.User]) {
                self.flags = flags
                self.count = count
                self.boosts = boosts
                self.nextOffset = nextOffset
                self.users = users
            }
        }
        case boostsList(Cons_boostsList)

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

        public static func parse_boostsList(_ reader: BufferReader) -> BoostsList? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.premium {
    enum BoostsStatus: TypeConstructorDescription {
        public class Cons_boostsStatus {
            public var flags: Int32
            public var level: Int32
            public var currentLevelBoosts: Int32
            public var boosts: Int32
            public var giftBoosts: Int32?
            public var nextLevelBoosts: Int32?
            public var premiumAudience: Api.StatsPercentValue?
            public var boostUrl: String
            public var prepaidGiveaways: [Api.PrepaidGiveaway]?
            public var myBoostSlots: [Int32]?
            public init(flags: Int32, level: Int32, currentLevelBoosts: Int32, boosts: Int32, giftBoosts: Int32?, nextLevelBoosts: Int32?, premiumAudience: Api.StatsPercentValue?, boostUrl: String, prepaidGiveaways: [Api.PrepaidGiveaway]?, myBoostSlots: [Int32]?) {
                self.flags = flags
                self.level = level
                self.currentLevelBoosts = currentLevelBoosts
                self.boosts = boosts
                self.giftBoosts = giftBoosts
                self.nextLevelBoosts = nextLevelBoosts
                self.premiumAudience = premiumAudience
                self.boostUrl = boostUrl
                self.prepaidGiveaways = prepaidGiveaways
                self.myBoostSlots = myBoostSlots
            }
        }
        case boostsStatus(Cons_boostsStatus)

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

        public static func parse_boostsStatus(_ reader: BufferReader) -> BoostsStatus? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.premium {
    enum MyBoosts: TypeConstructorDescription {
        public class Cons_myBoosts {
            public var myBoosts: [Api.MyBoost]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(myBoosts: [Api.MyBoost], chats: [Api.Chat], users: [Api.User]) {
                self.myBoosts = myBoosts
                self.chats = chats
                self.users = users
            }
        }
        case myBoosts(Cons_myBoosts)

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

        public static func parse_myBoosts(_ reader: BufferReader) -> MyBoosts? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.smsjobs {
    enum EligibilityToJoin: TypeConstructorDescription {
        public class Cons_eligibleToJoin {
            public var termsUrl: String
            public var monthlySentSms: Int32
            public init(termsUrl: String, monthlySentSms: Int32) {
                self.termsUrl = termsUrl
                self.monthlySentSms = monthlySentSms
            }
        }
        case eligibleToJoin(Cons_eligibleToJoin)

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

        public static func parse_eligibleToJoin(_ reader: BufferReader) -> EligibilityToJoin? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.smsjobs {
    enum Status: TypeConstructorDescription {
        public class Cons_status {
            public var flags: Int32
            public var recentSent: Int32
            public var recentSince: Int32
            public var recentRemains: Int32
            public var totalSent: Int32
            public var totalSince: Int32
            public var lastGiftSlug: String?
            public var termsUrl: String
            public init(flags: Int32, recentSent: Int32, recentSince: Int32, recentRemains: Int32, totalSent: Int32, totalSince: Int32, lastGiftSlug: String?, termsUrl: String) {
                self.flags = flags
                self.recentSent = recentSent
                self.recentSince = recentSince
                self.recentRemains = recentRemains
                self.totalSent = totalSent
                self.totalSince = totalSince
                self.lastGiftSlug = lastGiftSlug
                self.termsUrl = termsUrl
            }
        }
        case status(Cons_status)

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

        public static func parse_status(_ reader: BufferReader) -> Status? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.stats {
    enum BroadcastStats: TypeConstructorDescription {
        public class Cons_broadcastStats {
            public var period: Api.StatsDateRangeDays
            public var followers: Api.StatsAbsValueAndPrev
            public var viewsPerPost: Api.StatsAbsValueAndPrev
            public var sharesPerPost: Api.StatsAbsValueAndPrev
            public var reactionsPerPost: Api.StatsAbsValueAndPrev
            public var viewsPerStory: Api.StatsAbsValueAndPrev
            public var sharesPerStory: Api.StatsAbsValueAndPrev
            public var reactionsPerStory: Api.StatsAbsValueAndPrev
            public var enabledNotifications: Api.StatsPercentValue
            public var growthGraph: Api.StatsGraph
            public var followersGraph: Api.StatsGraph
            public var muteGraph: Api.StatsGraph
            public var topHoursGraph: Api.StatsGraph
            public var interactionsGraph: Api.StatsGraph
            public var ivInteractionsGraph: Api.StatsGraph
            public var viewsBySourceGraph: Api.StatsGraph
            public var newFollowersBySourceGraph: Api.StatsGraph
            public var languagesGraph: Api.StatsGraph
            public var reactionsByEmotionGraph: Api.StatsGraph
            public var storyInteractionsGraph: Api.StatsGraph
            public var storyReactionsByEmotionGraph: Api.StatsGraph
            public var recentPostsInteractions: [Api.PostInteractionCounters]
            public init(period: Api.StatsDateRangeDays, followers: Api.StatsAbsValueAndPrev, viewsPerPost: Api.StatsAbsValueAndPrev, sharesPerPost: Api.StatsAbsValueAndPrev, reactionsPerPost: Api.StatsAbsValueAndPrev, viewsPerStory: Api.StatsAbsValueAndPrev, sharesPerStory: Api.StatsAbsValueAndPrev, reactionsPerStory: Api.StatsAbsValueAndPrev, enabledNotifications: Api.StatsPercentValue, growthGraph: Api.StatsGraph, followersGraph: Api.StatsGraph, muteGraph: Api.StatsGraph, topHoursGraph: Api.StatsGraph, interactionsGraph: Api.StatsGraph, ivInteractionsGraph: Api.StatsGraph, viewsBySourceGraph: Api.StatsGraph, newFollowersBySourceGraph: Api.StatsGraph, languagesGraph: Api.StatsGraph, reactionsByEmotionGraph: Api.StatsGraph, storyInteractionsGraph: Api.StatsGraph, storyReactionsByEmotionGraph: Api.StatsGraph, recentPostsInteractions: [Api.PostInteractionCounters]) {
                self.period = period
                self.followers = followers
                self.viewsPerPost = viewsPerPost
                self.sharesPerPost = sharesPerPost
                self.reactionsPerPost = reactionsPerPost
                self.viewsPerStory = viewsPerStory
                self.sharesPerStory = sharesPerStory
                self.reactionsPerStory = reactionsPerStory
                self.enabledNotifications = enabledNotifications
                self.growthGraph = growthGraph
                self.followersGraph = followersGraph
                self.muteGraph = muteGraph
                self.topHoursGraph = topHoursGraph
                self.interactionsGraph = interactionsGraph
                self.ivInteractionsGraph = ivInteractionsGraph
                self.viewsBySourceGraph = viewsBySourceGraph
                self.newFollowersBySourceGraph = newFollowersBySourceGraph
                self.languagesGraph = languagesGraph
                self.reactionsByEmotionGraph = reactionsByEmotionGraph
                self.storyInteractionsGraph = storyInteractionsGraph
                self.storyReactionsByEmotionGraph = storyReactionsByEmotionGraph
                self.recentPostsInteractions = recentPostsInteractions
            }
        }
        case broadcastStats(Cons_broadcastStats)

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

        public static func parse_broadcastStats(_ reader: BufferReader) -> BroadcastStats? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.stats {
    enum MegagroupStats: TypeConstructorDescription {
        public class Cons_megagroupStats {
            public var period: Api.StatsDateRangeDays
            public var members: Api.StatsAbsValueAndPrev
            public var messages: Api.StatsAbsValueAndPrev
            public var viewers: Api.StatsAbsValueAndPrev
            public var posters: Api.StatsAbsValueAndPrev
            public var growthGraph: Api.StatsGraph
            public var membersGraph: Api.StatsGraph
            public var newMembersBySourceGraph: Api.StatsGraph
            public var languagesGraph: Api.StatsGraph
            public var messagesGraph: Api.StatsGraph
            public var actionsGraph: Api.StatsGraph
            public var topHoursGraph: Api.StatsGraph
            public var weekdaysGraph: Api.StatsGraph
            public var topPosters: [Api.StatsGroupTopPoster]
            public var topAdmins: [Api.StatsGroupTopAdmin]
            public var topInviters: [Api.StatsGroupTopInviter]
            public var users: [Api.User]
            public init(period: Api.StatsDateRangeDays, members: Api.StatsAbsValueAndPrev, messages: Api.StatsAbsValueAndPrev, viewers: Api.StatsAbsValueAndPrev, posters: Api.StatsAbsValueAndPrev, growthGraph: Api.StatsGraph, membersGraph: Api.StatsGraph, newMembersBySourceGraph: Api.StatsGraph, languagesGraph: Api.StatsGraph, messagesGraph: Api.StatsGraph, actionsGraph: Api.StatsGraph, topHoursGraph: Api.StatsGraph, weekdaysGraph: Api.StatsGraph, topPosters: [Api.StatsGroupTopPoster], topAdmins: [Api.StatsGroupTopAdmin], topInviters: [Api.StatsGroupTopInviter], users: [Api.User]) {
                self.period = period
                self.members = members
                self.messages = messages
                self.viewers = viewers
                self.posters = posters
                self.growthGraph = growthGraph
                self.membersGraph = membersGraph
                self.newMembersBySourceGraph = newMembersBySourceGraph
                self.languagesGraph = languagesGraph
                self.messagesGraph = messagesGraph
                self.actionsGraph = actionsGraph
                self.topHoursGraph = topHoursGraph
                self.weekdaysGraph = weekdaysGraph
                self.topPosters = topPosters
                self.topAdmins = topAdmins
                self.topInviters = topInviters
                self.users = users
            }
        }
        case megagroupStats(Cons_megagroupStats)

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

        public static func parse_megagroupStats(_ reader: BufferReader) -> MegagroupStats? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.stats {
    enum MessageStats: TypeConstructorDescription {
        public class Cons_messageStats {
            public var viewsGraph: Api.StatsGraph
            public var reactionsByEmotionGraph: Api.StatsGraph
            public init(viewsGraph: Api.StatsGraph, reactionsByEmotionGraph: Api.StatsGraph) {
                self.viewsGraph = viewsGraph
                self.reactionsByEmotionGraph = reactionsByEmotionGraph
            }
        }
        case messageStats(Cons_messageStats)

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

        public static func parse_messageStats(_ reader: BufferReader) -> MessageStats? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.stats {
    enum PublicForwards: TypeConstructorDescription {
        public class Cons_publicForwards {
            public var flags: Int32
            public var count: Int32
            public var forwards: [Api.PublicForward]
            public var nextOffset: String?
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, count: Int32, forwards: [Api.PublicForward], nextOffset: String?, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.count = count
                self.forwards = forwards
                self.nextOffset = nextOffset
                self.chats = chats
                self.users = users
            }
        }
        case publicForwards(Cons_publicForwards)

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

        public static func parse_publicForwards(_ reader: BufferReader) -> PublicForwards? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.stats {
    enum StoryStats: TypeConstructorDescription {
        public class Cons_storyStats {
            public var viewsGraph: Api.StatsGraph
            public var reactionsByEmotionGraph: Api.StatsGraph
            public init(viewsGraph: Api.StatsGraph, reactionsByEmotionGraph: Api.StatsGraph) {
                self.viewsGraph = viewsGraph
                self.reactionsByEmotionGraph = reactionsByEmotionGraph
            }
        }
        case storyStats(Cons_storyStats)

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

        public static func parse_storyStats(_ reader: BufferReader) -> StoryStats? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.stickers {
    enum SuggestedShortName: TypeConstructorDescription {
        case suggestedShortName(shortName: String)

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

        public static func parse_suggestedShortName(_ reader: BufferReader) -> SuggestedShortName? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.storage {
    enum FileType: TypeConstructorDescription {
        case fileGif
        case fileJpeg
        case fileMov
        case fileMp3
        case fileMp4
        case filePartial
        case filePdf
        case filePng
        case fileUnknown
        case fileWebp

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

        public static func parse_fileGif(_ reader: BufferReader) -> FileType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_fileJpeg(_ reader: BufferReader) -> FileType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_fileMov(_ reader: BufferReader) -> FileType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_fileMp3(_ reader: BufferReader) -> FileType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_fileMp4(_ reader: BufferReader) -> FileType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_filePartial(_ reader: BufferReader) -> FileType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_filePdf(_ reader: BufferReader) -> FileType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_filePng(_ reader: BufferReader) -> FileType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_fileUnknown(_ reader: BufferReader) -> FileType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_fileWebp(_ reader: BufferReader) -> FileType? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.stories {
    enum Albums: TypeConstructorDescription {
        case albums(hash: Int64, albums: [Api.StoryAlbum])
        case albumsNotModified

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

        public static func parse_albums(_ reader: BufferReader) -> Albums? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_albumsNotModified(_ reader: BufferReader) -> Albums? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.stories {
    enum AllStories: TypeConstructorDescription {
        case allStories(flags: Int32, count: Int32, state: String, peerStories: [Api.PeerStories], chats: [Api.Chat], users: [Api.User], stealthMode: Api.StoriesStealthMode)
        case allStoriesNotModified(flags: Int32, state: String, stealthMode: Api.StoriesStealthMode)

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

        public static func parse_allStories(_ reader: BufferReader) -> AllStories? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_allStoriesNotModified(_ reader: BufferReader) -> AllStories? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.stories {
    enum CanSendStoryCount: TypeConstructorDescription {
        case canSendStoryCount(countRemains: Int32)

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

        public static func parse_canSendStoryCount(_ reader: BufferReader) -> CanSendStoryCount? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api.stories {
    enum FoundStories: TypeConstructorDescription {
        case foundStories(flags: Int32, count: Int32, stories: [Api.FoundStory], nextOffset: String?, chats: [Api.Chat], users: [Api.User])

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

        public static func parse_foundStories(_ reader: BufferReader) -> FoundStories? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
