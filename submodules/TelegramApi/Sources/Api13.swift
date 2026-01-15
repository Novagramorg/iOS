public extension Api {
    enum InputQuickReplyShortcut: TypeConstructorDescription {
        case inputQuickReplyShortcut(shortcut: String)
        case inputQuickReplyShortcutId(shortcutId: Int32)

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

        public static func parse_inputQuickReplyShortcut(_ reader: BufferReader) -> InputQuickReplyShortcut? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputQuickReplyShortcutId(_ reader: BufferReader) -> InputQuickReplyShortcut? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum InputReplyTo: TypeConstructorDescription {
        case inputReplyToMessage(flags: Int32, replyToMsgId: Int32, topMsgId: Int32?, replyToPeerId: Api.InputPeer?, quoteText: String?, quoteEntities: [Api.MessageEntity]?, quoteOffset: Int32?, monoforumPeerId: Api.InputPeer?, todoItemId: Int32?)
        case inputReplyToMonoForum(monoforumPeerId: Api.InputPeer)
        case inputReplyToStory(peer: Api.InputPeer, storyId: Int32)

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

        public static func parse_inputReplyToMessage(_ reader: BufferReader) -> InputReplyTo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputReplyToMonoForum(_ reader: BufferReader) -> InputReplyTo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputReplyToStory(_ reader: BufferReader) -> InputReplyTo? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum InputSavedStarGift: TypeConstructorDescription {
        case inputSavedStarGiftChat(peer: Api.InputPeer, savedId: Int64)
        case inputSavedStarGiftSlug(slug: String)
        case inputSavedStarGiftUser(msgId: Int32)

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

        public static func parse_inputSavedStarGiftChat(_ reader: BufferReader) -> InputSavedStarGift? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputSavedStarGiftSlug(_ reader: BufferReader) -> InputSavedStarGift? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputSavedStarGiftUser(_ reader: BufferReader) -> InputSavedStarGift? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputSecureFile: TypeConstructorDescription {
        case inputSecureFile(id: Int64, accessHash: Int64)
        case inputSecureFileUploaded(id: Int64, parts: Int32, md5Checksum: String, fileHash: Buffer, secret: Buffer)

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

        public static func parse_inputSecureFile(_ reader: BufferReader) -> InputSecureFile? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputSecureFileUploaded(_ reader: BufferReader) -> InputSecureFile? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputSecureValue: TypeConstructorDescription {
        case inputSecureValue(flags: Int32, type: Api.SecureValueType, data: Api.SecureData?, frontSide: Api.InputSecureFile?, reverseSide: Api.InputSecureFile?, selfie: Api.InputSecureFile?, translation: [Api.InputSecureFile]?, files: [Api.InputSecureFile]?, plainData: Api.SecurePlainData?)

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

        public static func parse_inputSecureValue(_ reader: BufferReader) -> InputSecureValue? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum InputSingleMedia: TypeConstructorDescription {
        case inputSingleMedia(flags: Int32, media: Api.InputMedia, randomId: Int64, message: String, entities: [Api.MessageEntity]?)

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

        public static func parse_inputSingleMedia(_ reader: BufferReader) -> InputSingleMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputStarGiftAuction: TypeConstructorDescription {
        case inputStarGiftAuction(giftId: Int64)
        case inputStarGiftAuctionSlug(slug: String)

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

        public static func parse_inputStarGiftAuction(_ reader: BufferReader) -> InputStarGiftAuction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStarGiftAuctionSlug(_ reader: BufferReader) -> InputStarGiftAuction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputStarsTransaction: TypeConstructorDescription {
        case inputStarsTransaction(flags: Int32, id: String)

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

        public static func parse_inputStarsTransaction(_ reader: BufferReader) -> InputStarsTransaction? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputStickerSet: TypeConstructorDescription {
        case inputStickerSetAnimatedEmoji
        case inputStickerSetAnimatedEmojiAnimations
        case inputStickerSetDice(emoticon: String)
        case inputStickerSetEmojiChannelDefaultStatuses
        case inputStickerSetEmojiDefaultStatuses
        case inputStickerSetEmojiDefaultTopicIcons
        case inputStickerSetEmojiGenericAnimations
        case inputStickerSetEmpty
        case inputStickerSetID(id: Int64, accessHash: Int64)
        case inputStickerSetPremiumGifts
        case inputStickerSetShortName(shortName: String)
        case inputStickerSetTonGifts

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

        public static func parse_inputStickerSetAnimatedEmoji(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetAnimatedEmojiAnimations(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetDice(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetEmojiChannelDefaultStatuses(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetEmojiDefaultStatuses(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetEmojiDefaultTopicIcons(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetEmojiGenericAnimations(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetEmpty(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetID(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetPremiumGifts(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetShortName(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetTonGifts(_ reader: BufferReader) -> InputStickerSet? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputStickerSetItem: TypeConstructorDescription {
        case inputStickerSetItem(flags: Int32, document: Api.InputDocument, emoji: String, maskCoords: Api.MaskCoords?, keywords: String?)

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

        public static func parse_inputStickerSetItem(_ reader: BufferReader) -> InputStickerSetItem? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputStickeredMedia: TypeConstructorDescription {
        case inputStickeredMediaDocument(id: Api.InputDocument)
        case inputStickeredMediaPhoto(id: Api.InputPhoto)

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

        public static func parse_inputStickeredMediaDocument(_ reader: BufferReader) -> InputStickeredMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickeredMediaPhoto(_ reader: BufferReader) -> InputStickeredMedia? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum InputStorePaymentPurpose: TypeConstructorDescription {
        case inputStorePaymentAuthCode(flags: Int32, phoneNumber: String, phoneCodeHash: String, currency: String, amount: Int64)
        case inputStorePaymentGiftPremium(userId: Api.InputUser, currency: String, amount: Int64)
        case inputStorePaymentPremiumGiftCode(flags: Int32, users: [Api.InputUser], boostPeer: Api.InputPeer?, currency: String, amount: Int64, message: Api.TextWithEntities?)
        case inputStorePaymentPremiumGiveaway(flags: Int32, boostPeer: Api.InputPeer, additionalPeers: [Api.InputPeer]?, countriesIso2: [String]?, prizeDescription: String?, randomId: Int64, untilDate: Int32, currency: String, amount: Int64)
        case inputStorePaymentPremiumSubscription(flags: Int32)
        case inputStorePaymentStarsGift(userId: Api.InputUser, stars: Int64, currency: String, amount: Int64)
        case inputStorePaymentStarsGiveaway(flags: Int32, stars: Int64, boostPeer: Api.InputPeer, additionalPeers: [Api.InputPeer]?, countriesIso2: [String]?, prizeDescription: String?, randomId: Int64, untilDate: Int32, currency: String, amount: Int64, users: Int32)
        case inputStorePaymentStarsTopup(flags: Int32, stars: Int64, currency: String, amount: Int64, spendPurposePeer: Api.InputPeer?)

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

        public static func parse_inputStorePaymentAuthCode(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStorePaymentGiftPremium(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStorePaymentPremiumGiftCode(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStorePaymentPremiumGiveaway(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStorePaymentPremiumSubscription(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStorePaymentStarsGift(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStorePaymentStarsGiveaway(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStorePaymentStarsTopup(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
