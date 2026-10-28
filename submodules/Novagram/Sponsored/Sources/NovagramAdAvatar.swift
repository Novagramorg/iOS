import Foundation
import ImageIO
import SwiftSignalKit
import Postbox
import TelegramCore
import NovagramAds

/// The advertiser photo of OUR ad (`promoted.avatar_url`). Telegram shows its own sponsor photo as the
/// sponsored message's small inline image (channel bubble, bot panel) when the ad has no content media,
/// and never draws the synthetic author's avatar there. So ours goes the same way: an image in the
/// message media, loaded from https through `HttpReferenceMediaResource` like PHOTO / VIDEO ads.
///
/// The photo is added only after the file is in the media box and decodes as an image. A missing,
/// invalid or slow url, or a broken file, leaves the ad exactly as it was without a photo.
enum NovagramAdAvatar {
    /// How long a new showing waits for the photo before it renders without one. The download keeps
    /// going, so the next showing of the same advertiser has it at once.
    static let loadTimeout: Double = 3.0

    struct Loaded {
        let url: URL
        let dimensions: PixelDimensions
    }

    /// `avatar_url` when it is a valid absolute https url, else nil.
    static func url(_ ad: SDKSponsoredAd) -> URL? {
        guard let url = ad.promoted.avatarURL, url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty else {
            return nil
        }
        return url
    }

    /// Emits once: the loaded photo, or nil (no url, PHOTO / VIDEO ad, load failed or timed out).
    static func load(postbox: Postbox, ad: SDKSponsoredAd) -> Signal<Loaded?, NoError> {
        // An ad with content media shows that media; Telegram does not show the sponsor photo then either.
        guard NovagramAdMessage.mediaSpec(ad) == nil, let url = self.url(ad) else {
            return .single(nil)
        }
        let resource = HttpReferenceMediaResource(url: url.absoluteString, size: nil)
        // Not tied to this signal: a timeout must not cancel the download. The media box runs one fetch
        // per url, and it ends by itself when the file arrives or the request fails.
        _ = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: .other, userContentType: .avatar, reference: .standalone(resource: resource), statsCategory: .generic).start()

        return postbox.mediaBox.resourceData(resource)
        |> filter { data in
            return data.complete
        }
        |> take(1)
        |> map { data -> Loaded? in
            guard let dimensions = self.imageDimensions(path: data.path) else {
                NovagramSponsored.logger.debug("ad photo skipped: not an image")
                return nil
            }
            return Loaded(url: url, dimensions: dimensions)
        }
        |> timeout(self.loadTimeout, queue: Queue.concurrentDefaultQueue(), alternate: .single(nil))
    }

    /// Pixel size of the image file, or nil when it is not a readable image (e.g. an error page).
    private static func imageDimensions(path: String) -> PixelDimensions? {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil), CGImageSourceGetCount(source) > 0 else {
            return nil
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        guard let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int, width > 0, height > 0 else {
            return nil
        }
        return PixelDimensions(width: Int32(clamping: width), height: Int32(clamping: height))
    }
}
