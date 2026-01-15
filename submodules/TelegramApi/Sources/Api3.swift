public extension Api {
    enum BusinessGreetingMessage: TypeConstructorDescription {
        public class Cons_businessGreetingMessage {
            public var shortcutId: Int32
            public var recipients: Api.BusinessRecipients
            public var noActivityDays: Int32
            public init(shortcutId: Int32, recipients: Api.BusinessRecipients, noActivityDays: Int32) {
                self.shortcutId = shortcutId
                self.recipients = recipients
                self.noActivityDays = noActivityDays
            }
        }
        case businessGreetingMessage(Cons_businessGreetingMessage)

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

        public static func parse_businessGreetingMessage(_ reader: BufferReader) -> BusinessGreetingMessage? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BusinessIntro: TypeConstructorDescription {
        public class Cons_businessIntro {
            public var flags: Int32
            public var title: String
            public var description: String
            public var sticker: Api.Document?
            public init(flags: Int32, title: String, description: String, sticker: Api.Document?) {
                self.flags = flags
                self.title = title
                self.description = description
                self.sticker = sticker
            }
        }
        case businessIntro(Cons_businessIntro)

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

        public static func parse_businessIntro(_ reader: BufferReader) -> BusinessIntro? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BusinessLocation: TypeConstructorDescription {
        public class Cons_businessLocation {
            public var flags: Int32
            public var geoPoint: Api.GeoPoint?
            public var address: String
            public init(flags: Int32, geoPoint: Api.GeoPoint?, address: String) {
                self.flags = flags
                self.geoPoint = geoPoint
                self.address = address
            }
        }
        case businessLocation(Cons_businessLocation)

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

        public static func parse_businessLocation(_ reader: BufferReader) -> BusinessLocation? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BusinessRecipients: TypeConstructorDescription {
        public class Cons_businessRecipients {
            public var flags: Int32
            public var users: [Int64]?
            public init(flags: Int32, users: [Int64]?) {
                self.flags = flags
                self.users = users
            }
        }
        case businessRecipients(Cons_businessRecipients)

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

        public static func parse_businessRecipients(_ reader: BufferReader) -> BusinessRecipients? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BusinessWeeklyOpen: TypeConstructorDescription {
        public class Cons_businessWeeklyOpen {
            public var startMinute: Int32
            public var endMinute: Int32
            public init(startMinute: Int32, endMinute: Int32) {
                self.startMinute = startMinute
                self.endMinute = endMinute
            }
        }
        case businessWeeklyOpen(Cons_businessWeeklyOpen)

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

        public static func parse_businessWeeklyOpen(_ reader: BufferReader) -> BusinessWeeklyOpen? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum BusinessWorkHours: TypeConstructorDescription {
        public class Cons_businessWorkHours {
            public var flags: Int32
            public var timezoneId: String
            public var weeklyOpen: [Api.BusinessWeeklyOpen]
            public init(flags: Int32, timezoneId: String, weeklyOpen: [Api.BusinessWeeklyOpen]) {
                self.flags = flags
                self.timezoneId = timezoneId
                self.weeklyOpen = weeklyOpen
            }
        }
        case businessWorkHours(Cons_businessWorkHours)

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

        public static func parse_businessWorkHours(_ reader: BufferReader) -> BusinessWorkHours? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum CdnConfig: TypeConstructorDescription {
        public class Cons_cdnConfig {
            public var publicKeys: [Api.CdnPublicKey]
            public init(publicKeys: [Api.CdnPublicKey]) {
                self.publicKeys = publicKeys
            }
        }
        case cdnConfig(Cons_cdnConfig)

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

        public static func parse_cdnConfig(_ reader: BufferReader) -> CdnConfig? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum CdnPublicKey: TypeConstructorDescription {
        public class Cons_cdnPublicKey {
            public var dcId: Int32
            public var publicKey: String
            public init(dcId: Int32, publicKey: String) {
                self.dcId = dcId
                self.publicKey = publicKey
            }
        }
        case cdnPublicKey(Cons_cdnPublicKey)

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

        public static func parse_cdnPublicKey(_ reader: BufferReader) -> CdnPublicKey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum ChannelAdminLogEvent: TypeConstructorDescription {
        public class Cons_channelAdminLogEvent {
            public var id: Int64
            public var date: Int32
            public var userId: Int64
            public var action: Api.ChannelAdminLogEventAction
            public init(id: Int64, date: Int32, userId: Int64, action: Api.ChannelAdminLogEventAction) {
                self.id = id
                self.date = date
                self.userId = userId
                self.action = action
            }
        }
        case channelAdminLogEvent(Cons_channelAdminLogEvent)

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

        public static func parse_channelAdminLogEvent(_ reader: BufferReader) -> ChannelAdminLogEvent? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum ChannelAdminLogEventAction: TypeConstructorDescription {
        public class Cons_channelAdminLogEventActionChangeAbout {
            public var prevValue: String
            public var newValue: String
            public init(prevValue: String, newValue: String) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionChangeAvailableReactions {
            public var prevValue: Api.ChatReactions
            public var newValue: Api.ChatReactions
            public init(prevValue: Api.ChatReactions, newValue: Api.ChatReactions) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionChangeEmojiStatus {
            public var prevValue: Api.EmojiStatus
            public var newValue: Api.EmojiStatus
            public init(prevValue: Api.EmojiStatus, newValue: Api.EmojiStatus) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionChangeEmojiStickerSet {
            public var prevStickerset: Api.InputStickerSet
            public var newStickerset: Api.InputStickerSet
            public init(prevStickerset: Api.InputStickerSet, newStickerset: Api.InputStickerSet) {
                self.prevStickerset = prevStickerset
                self.newStickerset = newStickerset
            }
        }
        public class Cons_channelAdminLogEventActionChangeHistoryTTL {
            public var prevValue: Int32
            public var newValue: Int32
            public init(prevValue: Int32, newValue: Int32) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionChangeLinkedChat {
            public var prevValue: Int64
            public var newValue: Int64
            public init(prevValue: Int64, newValue: Int64) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionChangeLocation {
            public var prevValue: Api.ChannelLocation
            public var newValue: Api.ChannelLocation
            public init(prevValue: Api.ChannelLocation, newValue: Api.ChannelLocation) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionChangePeerColor {
            public var prevValue: Api.PeerColor
            public var newValue: Api.PeerColor
            public init(prevValue: Api.PeerColor, newValue: Api.PeerColor) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionChangePhoto {
            public var prevPhoto: Api.Photo
            public var newPhoto: Api.Photo
            public init(prevPhoto: Api.Photo, newPhoto: Api.Photo) {
                self.prevPhoto = prevPhoto
                self.newPhoto = newPhoto
            }
        }
        public class Cons_channelAdminLogEventActionChangeProfilePeerColor {
            public var prevValue: Api.PeerColor
            public var newValue: Api.PeerColor
            public init(prevValue: Api.PeerColor, newValue: Api.PeerColor) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionChangeStickerSet {
            public var prevStickerset: Api.InputStickerSet
            public var newStickerset: Api.InputStickerSet
            public init(prevStickerset: Api.InputStickerSet, newStickerset: Api.InputStickerSet) {
                self.prevStickerset = prevStickerset
                self.newStickerset = newStickerset
            }
        }
        public class Cons_channelAdminLogEventActionChangeTitle {
            public var prevValue: String
            public var newValue: String
            public init(prevValue: String, newValue: String) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionChangeUsername {
            public var prevValue: String
            public var newValue: String
            public init(prevValue: String, newValue: String) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionChangeUsernames {
            public var prevValue: [String]
            public var newValue: [String]
            public init(prevValue: [String], newValue: [String]) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionChangeWallpaper {
            public var prevValue: Api.WallPaper
            public var newValue: Api.WallPaper
            public init(prevValue: Api.WallPaper, newValue: Api.WallPaper) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionCreateTopic {
            public var topic: Api.ForumTopic
            public init(topic: Api.ForumTopic) {
                self.topic = topic
            }
        }
        public class Cons_channelAdminLogEventActionDefaultBannedRights {
            public var prevBannedRights: Api.ChatBannedRights
            public var newBannedRights: Api.ChatBannedRights
            public init(prevBannedRights: Api.ChatBannedRights, newBannedRights: Api.ChatBannedRights) {
                self.prevBannedRights = prevBannedRights
                self.newBannedRights = newBannedRights
            }
        }
        public class Cons_channelAdminLogEventActionDeleteMessage {
            public var message: Api.Message
            public init(message: Api.Message) {
                self.message = message
            }
        }
        public class Cons_channelAdminLogEventActionDeleteTopic {
            public var topic: Api.ForumTopic
            public init(topic: Api.ForumTopic) {
                self.topic = topic
            }
        }
        public class Cons_channelAdminLogEventActionDiscardGroupCall {
            public var call: Api.InputGroupCall
            public init(call: Api.InputGroupCall) {
                self.call = call
            }
        }
        public class Cons_channelAdminLogEventActionEditMessage {
            public var prevMessage: Api.Message
            public var newMessage: Api.Message
            public init(prevMessage: Api.Message, newMessage: Api.Message) {
                self.prevMessage = prevMessage
                self.newMessage = newMessage
            }
        }
        public class Cons_channelAdminLogEventActionEditTopic {
            public var prevTopic: Api.ForumTopic
            public var newTopic: Api.ForumTopic
            public init(prevTopic: Api.ForumTopic, newTopic: Api.ForumTopic) {
                self.prevTopic = prevTopic
                self.newTopic = newTopic
            }
        }
        public class Cons_channelAdminLogEventActionExportedInviteDelete {
            public var invite: Api.ExportedChatInvite
            public init(invite: Api.ExportedChatInvite) {
                self.invite = invite
            }
        }
        public class Cons_channelAdminLogEventActionExportedInviteEdit {
            public var prevInvite: Api.ExportedChatInvite
            public var newInvite: Api.ExportedChatInvite
            public init(prevInvite: Api.ExportedChatInvite, newInvite: Api.ExportedChatInvite) {
                self.prevInvite = prevInvite
                self.newInvite = newInvite
            }
        }
        public class Cons_channelAdminLogEventActionExportedInviteRevoke {
            public var invite: Api.ExportedChatInvite
            public init(invite: Api.ExportedChatInvite) {
                self.invite = invite
            }
        }
        public class Cons_channelAdminLogEventActionParticipantInvite {
            public var participant: Api.ChannelParticipant
            public init(participant: Api.ChannelParticipant) {
                self.participant = participant
            }
        }
        public class Cons_channelAdminLogEventActionParticipantJoinByInvite {
            public var flags: Int32
            public var invite: Api.ExportedChatInvite
            public init(flags: Int32, invite: Api.ExportedChatInvite) {
                self.flags = flags
                self.invite = invite
            }
        }
        public class Cons_channelAdminLogEventActionParticipantJoinByRequest {
            public var invite: Api.ExportedChatInvite
            public var approvedBy: Int64
            public init(invite: Api.ExportedChatInvite, approvedBy: Int64) {
                self.invite = invite
                self.approvedBy = approvedBy
            }
        }
        public class Cons_channelAdminLogEventActionParticipantMute {
            public var participant: Api.GroupCallParticipant
            public init(participant: Api.GroupCallParticipant) {
                self.participant = participant
            }
        }
        public class Cons_channelAdminLogEventActionParticipantSubExtend {
            public var prevParticipant: Api.ChannelParticipant
            public var newParticipant: Api.ChannelParticipant
            public init(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant) {
                self.prevParticipant = prevParticipant
                self.newParticipant = newParticipant
            }
        }
        public class Cons_channelAdminLogEventActionParticipantToggleAdmin {
            public var prevParticipant: Api.ChannelParticipant
            public var newParticipant: Api.ChannelParticipant
            public init(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant) {
                self.prevParticipant = prevParticipant
                self.newParticipant = newParticipant
            }
        }
        public class Cons_channelAdminLogEventActionParticipantToggleBan {
            public var prevParticipant: Api.ChannelParticipant
            public var newParticipant: Api.ChannelParticipant
            public init(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant) {
                self.prevParticipant = prevParticipant
                self.newParticipant = newParticipant
            }
        }
        public class Cons_channelAdminLogEventActionParticipantUnmute {
            public var participant: Api.GroupCallParticipant
            public init(participant: Api.GroupCallParticipant) {
                self.participant = participant
            }
        }
        public class Cons_channelAdminLogEventActionParticipantVolume {
            public var participant: Api.GroupCallParticipant
            public init(participant: Api.GroupCallParticipant) {
                self.participant = participant
            }
        }
        public class Cons_channelAdminLogEventActionPinTopic {
            public var flags: Int32
            public var prevTopic: Api.ForumTopic?
            public var newTopic: Api.ForumTopic?
            public init(flags: Int32, prevTopic: Api.ForumTopic?, newTopic: Api.ForumTopic?) {
                self.flags = flags
                self.prevTopic = prevTopic
                self.newTopic = newTopic
            }
        }
        public class Cons_channelAdminLogEventActionSendMessage {
            public var message: Api.Message
            public init(message: Api.Message) {
                self.message = message
            }
        }
        public class Cons_channelAdminLogEventActionStartGroupCall {
            public var call: Api.InputGroupCall
            public init(call: Api.InputGroupCall) {
                self.call = call
            }
        }
        public class Cons_channelAdminLogEventActionStopPoll {
            public var message: Api.Message
            public init(message: Api.Message) {
                self.message = message
            }
        }
        public class Cons_channelAdminLogEventActionToggleAntiSpam {
            public var newValue: Api.Bool
            public init(newValue: Api.Bool) {
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionToggleAutotranslation {
            public var newValue: Api.Bool
            public init(newValue: Api.Bool) {
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionToggleForum {
            public var newValue: Api.Bool
            public init(newValue: Api.Bool) {
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionToggleGroupCallSetting {
            public var joinMuted: Api.Bool
            public init(joinMuted: Api.Bool) {
                self.joinMuted = joinMuted
            }
        }
        public class Cons_channelAdminLogEventActionToggleInvites {
            public var newValue: Api.Bool
            public init(newValue: Api.Bool) {
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionToggleNoForwards {
            public var newValue: Api.Bool
            public init(newValue: Api.Bool) {
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionTogglePreHistoryHidden {
            public var newValue: Api.Bool
            public init(newValue: Api.Bool) {
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionToggleSignatureProfiles {
            public var newValue: Api.Bool
            public init(newValue: Api.Bool) {
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionToggleSignatures {
            public var newValue: Api.Bool
            public init(newValue: Api.Bool) {
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionToggleSlowMode {
            public var prevValue: Int32
            public var newValue: Int32
            public init(prevValue: Int32, newValue: Int32) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
        }
        public class Cons_channelAdminLogEventActionUpdatePinned {
            public var message: Api.Message
            public init(message: Api.Message) {
                self.message = message
            }
        }
        case channelAdminLogEventActionChangeAbout(Cons_channelAdminLogEventActionChangeAbout)
        case channelAdminLogEventActionChangeAvailableReactions(Cons_channelAdminLogEventActionChangeAvailableReactions)
        case channelAdminLogEventActionChangeEmojiStatus(Cons_channelAdminLogEventActionChangeEmojiStatus)
        case channelAdminLogEventActionChangeEmojiStickerSet(Cons_channelAdminLogEventActionChangeEmojiStickerSet)
        case channelAdminLogEventActionChangeHistoryTTL(Cons_channelAdminLogEventActionChangeHistoryTTL)
        case channelAdminLogEventActionChangeLinkedChat(Cons_channelAdminLogEventActionChangeLinkedChat)
        case channelAdminLogEventActionChangeLocation(Cons_channelAdminLogEventActionChangeLocation)
        case channelAdminLogEventActionChangePeerColor(Cons_channelAdminLogEventActionChangePeerColor)
        case channelAdminLogEventActionChangePhoto(Cons_channelAdminLogEventActionChangePhoto)
        case channelAdminLogEventActionChangeProfilePeerColor(Cons_channelAdminLogEventActionChangeProfilePeerColor)
        case channelAdminLogEventActionChangeStickerSet(Cons_channelAdminLogEventActionChangeStickerSet)
        case channelAdminLogEventActionChangeTitle(Cons_channelAdminLogEventActionChangeTitle)
        case channelAdminLogEventActionChangeUsername(Cons_channelAdminLogEventActionChangeUsername)
        case channelAdminLogEventActionChangeUsernames(Cons_channelAdminLogEventActionChangeUsernames)
        case channelAdminLogEventActionChangeWallpaper(Cons_channelAdminLogEventActionChangeWallpaper)
        case channelAdminLogEventActionCreateTopic(Cons_channelAdminLogEventActionCreateTopic)
        case channelAdminLogEventActionDefaultBannedRights(Cons_channelAdminLogEventActionDefaultBannedRights)
        case channelAdminLogEventActionDeleteMessage(Cons_channelAdminLogEventActionDeleteMessage)
        case channelAdminLogEventActionDeleteTopic(Cons_channelAdminLogEventActionDeleteTopic)
        case channelAdminLogEventActionDiscardGroupCall(Cons_channelAdminLogEventActionDiscardGroupCall)
        case channelAdminLogEventActionEditMessage(Cons_channelAdminLogEventActionEditMessage)
        case channelAdminLogEventActionEditTopic(Cons_channelAdminLogEventActionEditTopic)
        case channelAdminLogEventActionExportedInviteDelete(Cons_channelAdminLogEventActionExportedInviteDelete)
        case channelAdminLogEventActionExportedInviteEdit(Cons_channelAdminLogEventActionExportedInviteEdit)
        case channelAdminLogEventActionExportedInviteRevoke(Cons_channelAdminLogEventActionExportedInviteRevoke)
        case channelAdminLogEventActionParticipantInvite(Cons_channelAdminLogEventActionParticipantInvite)
        case channelAdminLogEventActionParticipantJoin
        case channelAdminLogEventActionParticipantJoinByInvite(Cons_channelAdminLogEventActionParticipantJoinByInvite)
        case channelAdminLogEventActionParticipantJoinByRequest(Cons_channelAdminLogEventActionParticipantJoinByRequest)
        case channelAdminLogEventActionParticipantLeave
        case channelAdminLogEventActionParticipantMute(Cons_channelAdminLogEventActionParticipantMute)
        case channelAdminLogEventActionParticipantSubExtend(Cons_channelAdminLogEventActionParticipantSubExtend)
        case channelAdminLogEventActionParticipantToggleAdmin(Cons_channelAdminLogEventActionParticipantToggleAdmin)
        case channelAdminLogEventActionParticipantToggleBan(Cons_channelAdminLogEventActionParticipantToggleBan)
        case channelAdminLogEventActionParticipantUnmute(Cons_channelAdminLogEventActionParticipantUnmute)
        case channelAdminLogEventActionParticipantVolume(Cons_channelAdminLogEventActionParticipantVolume)
        case channelAdminLogEventActionPinTopic(Cons_channelAdminLogEventActionPinTopic)
        case channelAdminLogEventActionSendMessage(Cons_channelAdminLogEventActionSendMessage)
        case channelAdminLogEventActionStartGroupCall(Cons_channelAdminLogEventActionStartGroupCall)
        case channelAdminLogEventActionStopPoll(Cons_channelAdminLogEventActionStopPoll)
        case channelAdminLogEventActionToggleAntiSpam(Cons_channelAdminLogEventActionToggleAntiSpam)
        case channelAdminLogEventActionToggleAutotranslation(Cons_channelAdminLogEventActionToggleAutotranslation)
        case channelAdminLogEventActionToggleForum(Cons_channelAdminLogEventActionToggleForum)
        case channelAdminLogEventActionToggleGroupCallSetting(Cons_channelAdminLogEventActionToggleGroupCallSetting)
        case channelAdminLogEventActionToggleInvites(Cons_channelAdminLogEventActionToggleInvites)
        case channelAdminLogEventActionToggleNoForwards(Cons_channelAdminLogEventActionToggleNoForwards)
        case channelAdminLogEventActionTogglePreHistoryHidden(Cons_channelAdminLogEventActionTogglePreHistoryHidden)
        case channelAdminLogEventActionToggleSignatureProfiles(Cons_channelAdminLogEventActionToggleSignatureProfiles)
        case channelAdminLogEventActionToggleSignatures(Cons_channelAdminLogEventActionToggleSignatures)
        case channelAdminLogEventActionToggleSlowMode(Cons_channelAdminLogEventActionToggleSlowMode)
        case channelAdminLogEventActionUpdatePinned(Cons_channelAdminLogEventActionUpdatePinned)

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

        public static func parse_channelAdminLogEventActionChangeAbout(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionChangeAvailableReactions(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionChangeEmojiStatus(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionChangeEmojiStickerSet(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionChangeHistoryTTL(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionChangeLinkedChat(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionChangeLocation(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionChangePeerColor(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionChangePhoto(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionChangeProfilePeerColor(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionChangeStickerSet(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionChangeTitle(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionChangeUsername(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionChangeUsernames(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionChangeWallpaper(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionCreateTopic(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionDefaultBannedRights(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionDeleteMessage(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionDeleteTopic(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionDiscardGroupCall(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionEditMessage(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionEditTopic(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionExportedInviteDelete(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionExportedInviteEdit(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionExportedInviteRevoke(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionParticipantInvite(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionParticipantJoin(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionParticipantJoinByInvite(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionParticipantJoinByRequest(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionParticipantLeave(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionParticipantMute(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionParticipantSubExtend(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionParticipantToggleAdmin(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionParticipantToggleBan(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionParticipantUnmute(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionParticipantVolume(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionPinTopic(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionSendMessage(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionStartGroupCall(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionStopPoll(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionToggleAntiSpam(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionToggleAutotranslation(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionToggleForum(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionToggleGroupCallSetting(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionToggleInvites(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionToggleNoForwards(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionTogglePreHistoryHidden(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionToggleSignatureProfiles(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionToggleSignatures(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionToggleSlowMode(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_channelAdminLogEventActionUpdatePinned(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
