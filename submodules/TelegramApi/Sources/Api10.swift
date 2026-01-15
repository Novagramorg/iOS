public extension Api {
    indirect enum InputFileLocation: TypeConstructorDescription {
        public class Cons_inputDocumentFileLocation {
            public var id: Int64
            public var accessHash: Int64
            public var fileReference: Buffer
            public var thumbSize: String
            public init(id: Int64, accessHash: Int64, fileReference: Buffer, thumbSize: String) {
                self.id = id
                self.accessHash = accessHash
                self.fileReference = fileReference
                self.thumbSize = thumbSize
            }
        }
        public class Cons_inputEncryptedFileLocation {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
        }
        public class Cons_inputFileLocation {
            public var volumeId: Int64
            public var localId: Int32
            public var secret: Int64
            public var fileReference: Buffer
            public init(volumeId: Int64, localId: Int32, secret: Int64, fileReference: Buffer) {
                self.volumeId = volumeId
                self.localId = localId
                self.secret = secret
                self.fileReference = fileReference
            }
        }
        public class Cons_inputGroupCallStream {
            public var flags: Int32
            public var call: Api.InputGroupCall
            public var timeMs: Int64
            public var scale: Int32
            public var videoChannel: Int32?
            public var videoQuality: Int32?
            public init(flags: Int32, call: Api.InputGroupCall, timeMs: Int64, scale: Int32, videoChannel: Int32?, videoQuality: Int32?) {
                self.flags = flags
                self.call = call
                self.timeMs = timeMs
                self.scale = scale
                self.videoChannel = videoChannel
                self.videoQuality = videoQuality
            }
        }
        public class Cons_inputPeerPhotoFileLocation {
            public var flags: Int32
            public var peer: Api.InputPeer
            public var photoId: Int64
            public init(flags: Int32, peer: Api.InputPeer, photoId: Int64) {
                self.flags = flags
                self.peer = peer
                self.photoId = photoId
            }
        }
        public class Cons_inputPhotoFileLocation {
            public var id: Int64
            public var accessHash: Int64
            public var fileReference: Buffer
            public var thumbSize: String
            public init(id: Int64, accessHash: Int64, fileReference: Buffer, thumbSize: String) {
                self.id = id
                self.accessHash = accessHash
                self.fileReference = fileReference
                self.thumbSize = thumbSize
            }
        }
        public class Cons_inputPhotoLegacyFileLocation {
            public var id: Int64
            public var accessHash: Int64
            public var fileReference: Buffer
            public var volumeId: Int64
            public var localId: Int32
            public var secret: Int64
            public init(id: Int64, accessHash: Int64, fileReference: Buffer, volumeId: Int64, localId: Int32, secret: Int64) {
                self.id = id
                self.accessHash = accessHash
                self.fileReference = fileReference
                self.volumeId = volumeId
                self.localId = localId
                self.secret = secret
            }
        }
        public class Cons_inputSecureFileLocation {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
        }
        public class Cons_inputStickerSetThumb {
            public var stickerset: Api.InputStickerSet
            public var thumbVersion: Int32
            public init(stickerset: Api.InputStickerSet, thumbVersion: Int32) {
                self.stickerset = stickerset
                self.thumbVersion = thumbVersion
            }
        }
        case inputDocumentFileLocation(Cons_inputDocumentFileLocation)
        case inputEncryptedFileLocation(Cons_inputEncryptedFileLocation)
        case inputFileLocation(Cons_inputFileLocation)
        case inputGroupCallStream(Cons_inputGroupCallStream)
        case inputPeerPhotoFileLocation(Cons_inputPeerPhotoFileLocation)
        case inputPhotoFileLocation(Cons_inputPhotoFileLocation)
        case inputPhotoLegacyFileLocation(Cons_inputPhotoLegacyFileLocation)
        case inputSecureFileLocation(Cons_inputSecureFileLocation)
        case inputStickerSetThumb(Cons_inputStickerSetThumb)
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
        public class Cons_inputFolderPeer {
            public var peer: Api.InputPeer
            public var folderId: Int32
            public init(peer: Api.InputPeer, folderId: Int32) {
                self.peer = peer
                self.folderId = folderId
            }
        }
        case inputFolderPeer(Cons_inputFolderPeer)

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
        public class Cons_inputGameID {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
        }
        public class Cons_inputGameShortName {
            public var botId: Api.InputUser
            public var shortName: String
            public init(botId: Api.InputUser, shortName: String) {
                self.botId = botId
                self.shortName = shortName
            }
        }
        case inputGameID(Cons_inputGameID)
        case inputGameShortName(Cons_inputGameShortName)

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
        public class Cons_inputGeoPoint {
            public var flags: Int32
            public var lat: Double
            public var long: Double
            public var accuracyRadius: Int32?
            public init(flags: Int32, lat: Double, long: Double, accuracyRadius: Int32?) {
                self.flags = flags
                self.lat = lat
                self.long = long
                self.accuracyRadius = accuracyRadius
            }
        }
        case inputGeoPoint(Cons_inputGeoPoint)
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
        public class Cons_inputGroupCall {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
        }
        public class Cons_inputGroupCallInviteMessage {
            public var msgId: Int32
            public init(msgId: Int32) {
                self.msgId = msgId
            }
        }
        public class Cons_inputGroupCallSlug {
            public var slug: String
            public init(slug: String) {
                self.slug = slug
            }
        }
        case inputGroupCall(Cons_inputGroupCall)
        case inputGroupCallInviteMessage(Cons_inputGroupCallInviteMessage)
        case inputGroupCallSlug(Cons_inputGroupCallSlug)

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
