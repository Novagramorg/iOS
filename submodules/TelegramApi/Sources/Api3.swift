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
        case cdnPublicKey(dcId: Int32, publicKey: String)

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
        case channelAdminLogEvent(id: Int64, date: Int32, userId: Int64, action: Api.ChannelAdminLogEventAction)

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
        case channelAdminLogEventActionChangeAbout(prevValue: String, newValue: String)
        case channelAdminLogEventActionChangeAvailableReactions(prevValue: Api.ChatReactions, newValue: Api.ChatReactions)
        case channelAdminLogEventActionChangeEmojiStatus(prevValue: Api.EmojiStatus, newValue: Api.EmojiStatus)
        case channelAdminLogEventActionChangeEmojiStickerSet(prevStickerset: Api.InputStickerSet, newStickerset: Api.InputStickerSet)
        case channelAdminLogEventActionChangeHistoryTTL(prevValue: Int32, newValue: Int32)
        case channelAdminLogEventActionChangeLinkedChat(prevValue: Int64, newValue: Int64)
        case channelAdminLogEventActionChangeLocation(prevValue: Api.ChannelLocation, newValue: Api.ChannelLocation)
        case channelAdminLogEventActionChangePeerColor(prevValue: Api.PeerColor, newValue: Api.PeerColor)
        case channelAdminLogEventActionChangePhoto(prevPhoto: Api.Photo, newPhoto: Api.Photo)
        case channelAdminLogEventActionChangeProfilePeerColor(prevValue: Api.PeerColor, newValue: Api.PeerColor)
        case channelAdminLogEventActionChangeStickerSet(prevStickerset: Api.InputStickerSet, newStickerset: Api.InputStickerSet)
        case channelAdminLogEventActionChangeTitle(prevValue: String, newValue: String)
        case channelAdminLogEventActionChangeUsername(prevValue: String, newValue: String)
        case channelAdminLogEventActionChangeUsernames(prevValue: [String], newValue: [String])
        case channelAdminLogEventActionChangeWallpaper(prevValue: Api.WallPaper, newValue: Api.WallPaper)
        case channelAdminLogEventActionCreateTopic(topic: Api.ForumTopic)
        case channelAdminLogEventActionDefaultBannedRights(prevBannedRights: Api.ChatBannedRights, newBannedRights: Api.ChatBannedRights)
        case channelAdminLogEventActionDeleteMessage(message: Api.Message)
        case channelAdminLogEventActionDeleteTopic(topic: Api.ForumTopic)
        case channelAdminLogEventActionDiscardGroupCall(call: Api.InputGroupCall)
        case channelAdminLogEventActionEditMessage(prevMessage: Api.Message, newMessage: Api.Message)
        case channelAdminLogEventActionEditTopic(prevTopic: Api.ForumTopic, newTopic: Api.ForumTopic)
        case channelAdminLogEventActionExportedInviteDelete(invite: Api.ExportedChatInvite)
        case channelAdminLogEventActionExportedInviteEdit(prevInvite: Api.ExportedChatInvite, newInvite: Api.ExportedChatInvite)
        case channelAdminLogEventActionExportedInviteRevoke(invite: Api.ExportedChatInvite)
        case channelAdminLogEventActionParticipantInvite(participant: Api.ChannelParticipant)
        case channelAdminLogEventActionParticipantJoin
        case channelAdminLogEventActionParticipantJoinByInvite(flags: Int32, invite: Api.ExportedChatInvite)
        case channelAdminLogEventActionParticipantJoinByRequest(invite: Api.ExportedChatInvite, approvedBy: Int64)
        case channelAdminLogEventActionParticipantLeave
        case channelAdminLogEventActionParticipantMute(participant: Api.GroupCallParticipant)
        case channelAdminLogEventActionParticipantSubExtend(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant)
        case channelAdminLogEventActionParticipantToggleAdmin(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant)
        case channelAdminLogEventActionParticipantToggleBan(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant)
        case channelAdminLogEventActionParticipantUnmute(participant: Api.GroupCallParticipant)
        case channelAdminLogEventActionParticipantVolume(participant: Api.GroupCallParticipant)
        case channelAdminLogEventActionPinTopic(flags: Int32, prevTopic: Api.ForumTopic?, newTopic: Api.ForumTopic?)
        case channelAdminLogEventActionSendMessage(message: Api.Message)
        case channelAdminLogEventActionStartGroupCall(call: Api.InputGroupCall)
        case channelAdminLogEventActionStopPoll(message: Api.Message)
        case channelAdminLogEventActionToggleAntiSpam(newValue: Api.Bool)
        case channelAdminLogEventActionToggleAutotranslation(newValue: Api.Bool)
        case channelAdminLogEventActionToggleForum(newValue: Api.Bool)
        case channelAdminLogEventActionToggleGroupCallSetting(joinMuted: Api.Bool)
        case channelAdminLogEventActionToggleInvites(newValue: Api.Bool)
        case channelAdminLogEventActionToggleNoForwards(newValue: Api.Bool)
        case channelAdminLogEventActionTogglePreHistoryHidden(newValue: Api.Bool)
        case channelAdminLogEventActionToggleSignatureProfiles(newValue: Api.Bool)
        case channelAdminLogEventActionToggleSignatures(newValue: Api.Bool)
        case channelAdminLogEventActionToggleSlowMode(prevValue: Int32, newValue: Int32)
        case channelAdminLogEventActionUpdatePinned(message: Api.Message)

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
