public extension Api {
    indirect enum PageCaption: TypeConstructorDescription {
        case pageCaption(text: Api.RichText, credit: Api.RichText)

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

        public static func parse_pageCaption(_ reader: BufferReader) -> PageCaption? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum PageListItem: TypeConstructorDescription {
        case pageListItemBlocks(blocks: [Api.PageBlock])
        case pageListItemText(text: Api.RichText)

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

        public static func parse_pageListItemBlocks(_ reader: BufferReader) -> PageListItem? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageListItemText(_ reader: BufferReader) -> PageListItem? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum PageListOrderedItem: TypeConstructorDescription {
        case pageListOrderedItemBlocks(num: String, blocks: [Api.PageBlock])
        case pageListOrderedItemText(num: String, text: Api.RichText)

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

        public static func parse_pageListOrderedItemBlocks(_ reader: BufferReader) -> PageListOrderedItem? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_pageListOrderedItemText(_ reader: BufferReader) -> PageListOrderedItem? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PageRelatedArticle: TypeConstructorDescription {
        case pageRelatedArticle(flags: Int32, url: String, webpageId: Int64, title: String?, description: String?, photoId: Int64?, author: String?, publishedDate: Int32?)

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

        public static func parse_pageRelatedArticle(_ reader: BufferReader) -> PageRelatedArticle? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum PageTableCell: TypeConstructorDescription {
        case pageTableCell(flags: Int32, text: Api.RichText?, colspan: Int32?, rowspan: Int32?)

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

        public static func parse_pageTableCell(_ reader: BufferReader) -> PageTableCell? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PageTableRow: TypeConstructorDescription {
        case pageTableRow(cells: [Api.PageTableCell])

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

        public static func parse_pageTableRow(_ reader: BufferReader) -> PageTableRow? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum PaidReactionPrivacy: TypeConstructorDescription {
        case paidReactionPrivacyAnonymous
        case paidReactionPrivacyDefault
        case paidReactionPrivacyPeer(peer: Api.InputPeer)

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

        public static func parse_paidReactionPrivacyAnonymous(_ reader: BufferReader) -> PaidReactionPrivacy? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_paidReactionPrivacyDefault(_ reader: BufferReader) -> PaidReactionPrivacy? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_paidReactionPrivacyPeer(_ reader: BufferReader) -> PaidReactionPrivacy? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Passkey: TypeConstructorDescription {
        case passkey(flags: Int32, id: String, name: String, date: Int32, softwareEmojiId: Int64?, lastUsageDate: Int32?)

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

        public static func parse_passkey(_ reader: BufferReader) -> Passkey? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PasswordKdfAlgo: TypeConstructorDescription {
        case passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(salt1: Buffer, salt2: Buffer, g: Int32, p: Buffer)
        case passwordKdfAlgoUnknown

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

        public static func parse_passwordKdfAlgoSHA256SHA256PBKDF2HMACSHA512iter100000SHA256ModPow(_ reader: BufferReader) -> PasswordKdfAlgo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_passwordKdfAlgoUnknown(_ reader: BufferReader) -> PasswordKdfAlgo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PaymentCharge: TypeConstructorDescription {
        case paymentCharge(id: String, providerChargeId: String)

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

        public static func parse_paymentCharge(_ reader: BufferReader) -> PaymentCharge? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PaymentFormMethod: TypeConstructorDescription {
        case paymentFormMethod(url: String, title: String)

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

        public static func parse_paymentFormMethod(_ reader: BufferReader) -> PaymentFormMethod? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PaymentRequestedInfo: TypeConstructorDescription {
        case paymentRequestedInfo(flags: Int32, name: String?, phone: String?, email: String?, shippingAddress: Api.PostAddress?)

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

        public static func parse_paymentRequestedInfo(_ reader: BufferReader) -> PaymentRequestedInfo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PaymentSavedCredentials: TypeConstructorDescription {
        case paymentSavedCredentialsCard(id: String, title: String)

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

        public static func parse_paymentSavedCredentialsCard(_ reader: BufferReader) -> PaymentSavedCredentials? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum Peer: TypeConstructorDescription {
        case peerChannel(channelId: Int64)
        case peerChat(chatId: Int64)
        case peerUser(userId: Int64)

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

        public static func parse_peerChannel(_ reader: BufferReader) -> Peer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_peerChat(_ reader: BufferReader) -> Peer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_peerUser(_ reader: BufferReader) -> Peer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PeerBlocked: TypeConstructorDescription {
        case peerBlocked(peerId: Api.Peer, date: Int32)

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

        public static func parse_peerBlocked(_ reader: BufferReader) -> PeerBlocked? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PeerColor: TypeConstructorDescription {
        case inputPeerColorCollectible(collectibleId: Int64)
        case peerColor(flags: Int32, color: Int32?, backgroundEmojiId: Int64?)
        case peerColorCollectible(flags: Int32, collectibleId: Int64, giftEmojiId: Int64, backgroundEmojiId: Int64, accentColor: Int32, colors: [Int32], darkAccentColor: Int32?, darkColors: [Int32]?)

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

        public static func parse_inputPeerColorCollectible(_ reader: BufferReader) -> PeerColor? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_peerColor(_ reader: BufferReader) -> PeerColor? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_peerColorCollectible(_ reader: BufferReader) -> PeerColor? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PeerLocated: TypeConstructorDescription {
        case peerLocated(peer: Api.Peer, expires: Int32, distance: Int32)
        case peerSelfLocated(expires: Int32)

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

        public static func parse_peerLocated(_ reader: BufferReader) -> PeerLocated? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_peerSelfLocated(_ reader: BufferReader) -> PeerLocated? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PeerNotifySettings: TypeConstructorDescription {
        case peerNotifySettings(flags: Int32, showPreviews: Api.Bool?, silent: Api.Bool?, muteUntil: Int32?, iosSound: Api.NotificationSound?, androidSound: Api.NotificationSound?, otherSound: Api.NotificationSound?, storiesMuted: Api.Bool?, storiesHideSender: Api.Bool?, storiesIosSound: Api.NotificationSound?, storiesAndroidSound: Api.NotificationSound?, storiesOtherSound: Api.NotificationSound?)

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

        public static func parse_peerNotifySettings(_ reader: BufferReader) -> PeerNotifySettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PeerSettings: TypeConstructorDescription {
        case peerSettings(flags: Int32, geoDistance: Int32?, requestChatTitle: String?, requestChatDate: Int32?, businessBotId: Int64?, businessBotManageUrl: String?, chargePaidMessageStars: Int64?, registrationMonth: String?, phoneCountry: String?, nameChangeDate: Int32?, photoChangeDate: Int32?)

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

        public static func parse_peerSettings(_ reader: BufferReader) -> PeerSettings? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PeerStories: TypeConstructorDescription {
        case peerStories(flags: Int32, peer: Api.Peer, maxReadId: Int32?, stories: [Api.StoryItem])

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

        public static func parse_peerStories(_ reader: BufferReader) -> PeerStories? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PendingSuggestion: TypeConstructorDescription {
        case pendingSuggestion(suggestion: String, title: Api.TextWithEntities, description: Api.TextWithEntities, url: String)

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

        public static func parse_pendingSuggestion(_ reader: BufferReader) -> PendingSuggestion? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum PhoneCall: TypeConstructorDescription {
        case phoneCall(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gAOrB: Buffer, keyFingerprint: Int64, protocol: Api.PhoneCallProtocol, connections: [Api.PhoneConnection], startDate: Int32, customParameters: Api.DataJSON?)
        case phoneCallAccepted(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gB: Buffer, protocol: Api.PhoneCallProtocol)
        case phoneCallDiscarded(flags: Int32, id: Int64, reason: Api.PhoneCallDiscardReason?, duration: Int32?)
        case phoneCallEmpty(id: Int64)
        case phoneCallRequested(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gAHash: Buffer, protocol: Api.PhoneCallProtocol)
        case phoneCallWaiting(flags: Int32, id: Int64, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, protocol: Api.PhoneCallProtocol, receiveDate: Int32?)

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
        public static func parse_phoneCallAccepted(_ reader: BufferReader) -> PhoneCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_phoneCallDiscarded(_ reader: BufferReader) -> PhoneCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_phoneCallEmpty(_ reader: BufferReader) -> PhoneCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_phoneCallRequested(_ reader: BufferReader) -> PhoneCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_phoneCallWaiting(_ reader: BufferReader) -> PhoneCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
