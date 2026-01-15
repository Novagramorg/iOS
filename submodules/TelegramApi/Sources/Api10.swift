public extension Api {
    indirect enum InputFileLocation: TypeConstructorDescription {
        case inputDocumentFileLocation(id: Int64, accessHash: Int64, fileReference: Buffer, thumbSize: String)
        case inputEncryptedFileLocation(id: Int64, accessHash: Int64)
        case inputFileLocation(volumeId: Int64, localId: Int32, secret: Int64, fileReference: Buffer)
        case inputGroupCallStream(flags: Int32, call: Api.InputGroupCall, timeMs: Int64, scale: Int32, videoChannel: Int32?, videoQuality: Int32?)
        case inputPeerPhotoFileLocation(flags: Int32, peer: Api.InputPeer, photoId: Int64)
        case inputPhotoFileLocation(id: Int64, accessHash: Int64, fileReference: Buffer, thumbSize: String)
        case inputPhotoLegacyFileLocation(id: Int64, accessHash: Int64, fileReference: Buffer, volumeId: Int64, localId: Int32, secret: Int64)
        case inputSecureFileLocation(id: Int64, accessHash: Int64)
        case inputStickerSetThumb(stickerset: Api.InputStickerSet, thumbVersion: Int32)
        case inputTakeoutFileLocation

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

        public static func parse_inputDocumentFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputEncryptedFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputGroupCallStream(_ reader: BufferReader) -> InputFileLocation? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPeerPhotoFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPhotoFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputPhotoLegacyFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputSecureFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputStickerSetThumb(_ reader: BufferReader) -> InputFileLocation? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputTakeoutFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum InputFolderPeer: TypeConstructorDescription {
        case inputFolderPeer(peer: Api.InputPeer, folderId: Int32)

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

        public static func parse_inputFolderPeer(_ reader: BufferReader) -> InputFolderPeer? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum InputGame: TypeConstructorDescription {
        case inputGameID(id: Int64, accessHash: Int64)
        case inputGameShortName(botId: Api.InputUser, shortName: String)

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

        public static func parse_inputGameID(_ reader: BufferReader) -> InputGame? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputGameShortName(_ reader: BufferReader) -> InputGame? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputGeoPoint: TypeConstructorDescription {
        case inputGeoPoint(flags: Int32, lat: Double, long: Double, accuracyRadius: Int32?)
        case inputGeoPointEmpty

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

        public static func parse_inputGeoPoint(_ reader: BufferReader) -> InputGeoPoint? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputGeoPointEmpty(_ reader: BufferReader) -> InputGeoPoint? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    enum InputGroupCall: TypeConstructorDescription {
        case inputGroupCall(id: Int64, accessHash: Int64)
        case inputGroupCallInviteMessage(msgId: Int32)
        case inputGroupCallSlug(slug: String)

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

        public static func parse_inputGroupCall(_ reader: BufferReader) -> InputGroupCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputGroupCallInviteMessage(_ reader: BufferReader) -> InputGroupCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputGroupCallSlug(_ reader: BufferReader) -> InputGroupCall? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
public extension Api {
    indirect enum InputInvoice: TypeConstructorDescription {
        case inputInvoiceBusinessBotTransferStars(bot: Api.InputUser, stars: Int64)
        case inputInvoiceChatInviteSubscription(hash: String)
        case inputInvoiceMessage(peer: Api.InputPeer, msgId: Int32)
        case inputInvoicePremiumAuthCode(purpose: Api.InputStorePaymentPurpose)
        case inputInvoicePremiumGiftCode(purpose: Api.InputStorePaymentPurpose, option: Api.PremiumGiftCodeOption)
        case inputInvoicePremiumGiftStars(flags: Int32, userId: Api.InputUser, months: Int32, message: Api.TextWithEntities?)
        case inputInvoiceSlug(slug: String)
        case inputInvoiceStarGift(flags: Int32, peer: Api.InputPeer, giftId: Int64, message: Api.TextWithEntities?)
        case inputInvoiceStarGiftAuctionBid(flags: Int32, peer: Api.InputPeer?, giftId: Int64, bidAmount: Int64, message: Api.TextWithEntities?)
        case inputInvoiceStarGiftDropOriginalDetails(stargift: Api.InputSavedStarGift)
        case inputInvoiceStarGiftPrepaidUpgrade(peer: Api.InputPeer, hash: String)
        case inputInvoiceStarGiftResale(flags: Int32, slug: String, toId: Api.InputPeer)
        case inputInvoiceStarGiftTransfer(stargift: Api.InputSavedStarGift, toId: Api.InputPeer)
        case inputInvoiceStarGiftUpgrade(flags: Int32, stargift: Api.InputSavedStarGift)
        case inputInvoiceStars(purpose: Api.InputStorePaymentPurpose)

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

        public static func parse_inputInvoiceBusinessBotTransferStars(_ reader: BufferReader) -> InputInvoice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputInvoiceChatInviteSubscription(_ reader: BufferReader) -> InputInvoice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputInvoiceMessage(_ reader: BufferReader) -> InputInvoice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputInvoicePremiumAuthCode(_ reader: BufferReader) -> InputInvoice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputInvoicePremiumGiftCode(_ reader: BufferReader) -> InputInvoice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputInvoicePremiumGiftStars(_ reader: BufferReader) -> InputInvoice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputInvoiceSlug(_ reader: BufferReader) -> InputInvoice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputInvoiceStarGift(_ reader: BufferReader) -> InputInvoice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputInvoiceStarGiftAuctionBid(_ reader: BufferReader) -> InputInvoice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputInvoiceStarGiftDropOriginalDetails(_ reader: BufferReader) -> InputInvoice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputInvoiceStarGiftPrepaidUpgrade(_ reader: BufferReader) -> InputInvoice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputInvoiceStarGiftResale(_ reader: BufferReader) -> InputInvoice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputInvoiceStarGiftTransfer(_ reader: BufferReader) -> InputInvoice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputInvoiceStarGiftUpgrade(_ reader: BufferReader) -> InputInvoice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
        public static func parse_inputInvoiceStars(_ reader: BufferReader) -> InputInvoice? {
            #if DEBUG
            preconditionFailure()
            #else
            error
            #endif
        }
    }
}
