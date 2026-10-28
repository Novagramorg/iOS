import Foundation
import Postbox
import TelegramCore
import TelegramPresentationData
import NovagramAds

/// Builds the sponsored `Message` Telegram's own ad UI renders (channel bubble, bot panel), in the
/// same shape as `AdMessagesHistoryContextImpl.CachedMessage.toMessage` / the `fakeAds` debug path.
enum NovagramAdMessage {
    /// Telegram uses this synthetic author id for every sponsored message.
    private static let authorPeerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(1))

    /// - Parameter displayDurations: VIDEO slot only — `min_display_duration` / `max_display_duration`
    ///   from the response, read by the banner's countdown.
    /// - Parameter avatar: the advertiser photo, already in the media box (`NovagramAdAvatar.load`).
    ///   Shown as the small inline image, like Telegram's sponsor photo, only when there is no content media.
    static func make(served: SDKServedAd, peerId: PeerId, chatPeer: Peer?, strings: PresentationStrings, displayDurations: (min: Int32, max: Int32)? = nil, avatar: NovagramAdAvatar.Loaded? = nil) -> Message {
        let ad = served.ad
        let contentMedia = self.contentMedia(ad)
        let otherInfo = ad.otherInfo.trimmingCharacters(in: .whitespacesAndNewlines)

        let adAttribute = AdMessageAttribute(
            opaqueId: NovagramSponsored.opaqueId(token: ad.randomId),
            messageType: .sponsored,
            url: ad.url,
            buttonText: NovagramSponsoredStrings(strings).buttonText(for: ad),
            sponsorInfo: otherInfo.isEmpty ? nil : otherInfo,
            additionalInfo: nil,
            canReport: true,
            hasContentMedia: contentMedia != nil,
            minDisplayDuration: displayDurations?.min,
            maxDisplayDuration: displayDurations?.max
        )

        var messagePeers = SimpleDictionary<PeerId, Peer>()
        if let chatPeer {
            messagePeers[chatPeer.id] = chatPeer
        }
        let author = self.author(title: ad.displayTitle)
        messagePeers[author.id] = author

        var media: [Media] = []
        if let contentMedia {
            media.append(contentMedia)
        } else if let avatar {
            media.append(self.avatarImage(avatar))
        }

        // A new random_id is a new showing, so the list must treat it as a changed item.
        let messageStableVersion = UInt32(bitPattern: Int32(truncatingIfNeeded: ad.randomId.hashValue))

        return Message(
            stableId: 0,
            stableVersion: messageStableVersion,
            id: MessageId(peerId: peerId, namespace: Namespaces.Message.Local, id: self.messageId(token: ad.randomId)),
            globallyUniqueId: nil,
            groupingKey: nil,
            groupInfo: nil,
            threadId: nil,
            timestamp: Int32.max - 1,
            flags: [.Incoming],
            tags: [],
            globalTags: [],
            localTags: [],
            customTags: [],
            forwardInfo: nil,
            author: author,
            text: ad.text,
            attributes: [adAttribute],
            media: media,
            peers: messagePeers,
            associatedMessages: SimpleDictionary<MessageId, Message>(),
            associatedMessageIds: [],
            associatedMedia: [:],
            associatedThreadInfo: nil,
            associatedStories: [:]
        )
    }

    /// A positive, non-zero id derived from `random_id` (FNV-1a 32-bit). Telegram's own sponsored message
    /// uses id 0, so the bot panel (which compares ids) sees a switch between theirs and ours, or between
    /// two of our showings. The channel path replaces the id anyway (`ChatHistoryEntriesForView`).
    static func messageId(token: String) -> Int32 {
        var hash: UInt32 = 2166136261
        for byte in token.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16777619
        }
        return Int32(bitPattern: hash & 0x7FFF_FFFF) | 1
    }

    private static func author(title: String) -> Peer {
        return TelegramChannel(
            id: self.authorPeerId,
            accessHash: nil,
            title: title,
            username: nil,
            photo: [],
            creationDate: 0,
            version: 0,
            participationStatus: .left,
            info: .broadcast(TelegramChannelBroadcastInfo(flags: [])),
            flags: [],
            restrictionInfo: nil,
            adminRights: nil,
            bannedRights: nil,
            defaultBannedRights: nil,
            usernames: [],
            storiesHidden: nil,
            nameColor: .blue,
            backgroundEmojiId: nil,
            profileColor: nil,
            profileBackgroundEmojiId: nil,
            emojiStatus: nil,
            approximateBoostLevel: nil,
            subscriptionUntilDate: nil,
            verificationIconFileId: nil,
            sendPaidMessageStars: nil,
            linkedMonoforumId: nil
        )
    }

    /// What the backend sent as `media`, normalized.
    struct MediaSpec {
        enum Kind {
            case photo
            case video
        }

        let kind: Kind
        let url: URL
        let width: Int?
        let height: Int?
        let duration: Double?
    }

    static func mediaSpec(_ ad: SDKSponsoredAd) -> MediaSpec? {
        #if DEBUG
        if let fixture = self.debugFixtureMedia() {
            return fixture
        }
        #endif
        guard let media = ad.media, let url = media.mediaURL, url.scheme == "https" else {
            return nil
        }
        let kind: MediaSpec.Kind
        switch media.type {
        case .photo:
            kind = .photo
        case .video:
            kind = .video
        case .unknown:
            return nil
        @unknown default:
            return nil
        }
        let duration = media.duration.map { NSDecimalNumber(decimal: $0.value).doubleValue }
        return MediaSpec(kind: kind, url: url, width: media.width, height: media.height, duration: duration)
    }

    #if DEBUG
    /// Debug builds only: `NOVAGRAM_ADS_DEBUG_MEDIA=photo:<https url>` or `video:<https url>` in the launch
    /// environment replaces the media of OUR channel ads, so PHOTO / VIDEO rendering can be checked while
    /// the test campaigns carry no media. Compiled out of release builds.
    private static func debugFixtureMedia() -> MediaSpec? {
        guard let value = ProcessInfo.processInfo.environment["NOVAGRAM_ADS_DEBUG_MEDIA"] else {
            return nil
        }
        let parts = value.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let url = URL(string: parts[1]), url.scheme == "https" else {
            return nil
        }
        switch parts[0] {
        case "photo":
            return MediaSpec(kind: .photo, url: url, width: 1280, height: 720, duration: nil)
        case "video":
            return MediaSpec(kind: .video, url: url, width: 1280, height: 720, duration: 10.0)
        default:
            return nil
        }
    }
    #endif

    /// 16:9 (contract §2.1) unless the response carries real dimensions, so the bubble reserves its frame
    /// before the file arrives.
    private static func dimensions(_ spec: MediaSpec) -> PixelDimensions {
        if let width = spec.width, let height = spec.height, width > 0, height > 0 {
            return PixelDimensions(width: Int32(clamping: width), height: Int32(clamping: height))
        }
        return PixelDimensions(width: 1280, height: 720)
    }

    /// Stable media id for an immutable media url (FNV-1a 64-bit).
    private static func mediaId(namespace: Int32, url: URL) -> MediaId {
        var hash: UInt64 = 14695981039346656037
        for byte in url.absoluteString.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return MediaId(namespace: namespace, id: Int64(bitPattern: hash & 0x7FFF_FFFF_FFFF_FFFF))
    }

    /// The advertiser photo as a web image (same `HttpReferenceMediaResource` path as a PHOTO ad). Its
    /// `hasContentMedia` stays false, so Telegram's UI draws it as the small sponsor image.
    private static func avatarImage(_ avatar: NovagramAdAvatar.Loaded) -> TelegramMediaImage {
        let representation = TelegramMediaImageRepresentation(
            dimensions: avatar.dimensions,
            resource: HttpReferenceMediaResource(url: avatar.url.absoluteString, size: nil),
            progressiveSizes: [],
            immediateThumbnailData: nil,
            hasVideo: false,
            isPersonal: false
        )
        return TelegramMediaImage(
            imageId: self.mediaId(namespace: Namespaces.Media.LocalImage, url: avatar.url),
            representations: [representation],
            immediateThumbnailData: nil,
            reference: nil,
            partialReference: nil,
            flags: []
        )
    }

    /// PHOTO as a web image and VIDEO as a web mp4. Both use `HttpReferenceMediaResource`: TelegramCore's
    /// fetcher downloads the whole file over HTTPS into the media box (files are immutable and small —
    /// photo ≤ 5 MB, video ≤ 20 MB), keyed by url, after which Telegram's own media pipeline shows it
    /// (muted inline autoplay for the video, like Telegram's own sponsored video).
    private static func contentMedia(_ ad: SDKSponsoredAd) -> Media? {
        guard let spec = self.mediaSpec(ad) else {
            return nil
        }
        let dimensions = self.dimensions(spec)
        let resource = HttpReferenceMediaResource(url: spec.url.absoluteString, size: nil)
        switch spec.kind {
        case .photo:
            let representation = TelegramMediaImageRepresentation(
                dimensions: dimensions,
                resource: resource,
                progressiveSizes: [],
                immediateThumbnailData: nil,
                hasVideo: false,
                isPersonal: false
            )
            return TelegramMediaImage(
                imageId: self.mediaId(namespace: Namespaces.Media.LocalImage, url: spec.url),
                representations: [representation],
                immediateThumbnailData: nil,
                reference: nil,
                partialReference: nil,
                flags: []
            )
        case .video:
            return TelegramMediaFile(
                fileId: self.mediaId(namespace: Namespaces.Media.LocalFile, url: spec.url),
                partialReference: nil,
                resource: resource,
                previewRepresentations: [],
                videoThumbnails: [],
                immediateThumbnailData: nil,
                mimeType: "video/mp4",
                size: nil,
                attributes: [
                    .Video(duration: spec.duration ?? 0.0, size: dimensions, flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil),
                    .FileName(fileName: "novagram-ad.mp4")
                ],
                alternativeRepresentations: []
            )
        }
    }
}
