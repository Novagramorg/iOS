import Foundation
import NovagramMessenger
import NovagramAds

/// The Developer section's "Ads tekshiruvi" (`NovagramAdsCheck` in NovagramMessenger, installed as its
/// provider by `NovagramAdsRegistry`).
///
/// Read-only: it calls only the low-level `client.ads.serve` and `client.bannerAds.activeBanners`, never
/// `SDKAdsSession`, so nothing is cached, queued or counted, and it never sends a view, click, action,
/// report or video_open event or a banner click / dismiss. Every run uses a fake viewer id, never the
/// account's. A failure keeps only its HTTP status class: an SDK error's text can carry a URL.
enum NovagramAdsCheckRunner {
    private static let searchQueries = ["novagram", "telegram", "kino", "musiqa", "yangiliklar", "futbol"]
    private static let botUsername = "adgram_testt_bot"
    private static let channelId: Int64 = -1003658719860
    private static let videoMessageId: Int64 = 1
    private static let fakeViewerIds: ClosedRange<Int64> = 9_000_000_000_001 ... 9_000_000_000_999
    private static let phoneCountry = "UZ"
    private static let requestTimeout: TimeInterval = 15

    // One client per environment, without retries, so a run reports what the server answered first.
    private static let productionClient = SDKClient(configuration: SDKConfiguration(environment: .production, timeout: requestTimeout, retryPolicy: .none))
    private static let developmentClient = SDKClient(configuration: SDKConfiguration(environment: .development, timeout: requestTimeout, retryPolicy: .none))

    private enum Outcome: Sendable {
        case served(SDKSponsoredAd?)
        case failed(NovagramAdsCheckFailure)
    }

    static func run(production: Bool, lang: String) async -> NovagramAdsCheckReport {
        let client = production ? self.productionClient : self.developmentClient
        let userId = Int64.random(in: self.fakeViewerIds)
        let targeting = SDKAdTargeting(phoneCountry: self.phoneCountry, lang: lang, platform: "ios", appVersion: SDKAdTargeting.bundleAppVersion)
        let started = Date()

        async let search = self.search(client: client, userId: userId, targeting: targeting)
        async let bot = self.single(.bot, slot: .bot(username: self.botUsername), client: client, userId: userId, targeting: targeting)
        async let channel = self.single(.channelMessage, slot: .channel(channelId: self.channelId), client: client, userId: userId, targeting: targeting)
        async let video = self.single(.video, slot: .video(channelId: self.channelId, messageId: self.videoMessageId), client: client, userId: userId, targeting: targeting)
        async let banners = self.banners(client: client, userId: userId)
        let slots = await [search, bot, channel, video, banners]

        let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
        let summary = slots.map { "\($0.slot)=\($0.hits)/\($0.requests)\($0.failures > 0 ? " failed \($0.failures)" : "")" }.joined(separator: ", ")
        NovagramSponsored.trace("ads check \(production ? "production" : "development"): \(summary) in \(elapsedMs) ms")
        return NovagramAdsCheckReport(production: production, finishedAt: Date(), elapsedMs: elapsedMs, slots: slots)
    }

    // MARK: - Requests

    private static func serve(_ slot: SDKAdSlot, client: SDKClient, userId: Int64, targeting: SDKAdTargeting) async -> Outcome {
        do {
            let response = try await client.ads.serve(slot: slot, userId: userId, targeting: targeting)
            return .served(response.ad)
        } catch {
            return .failed(self.failure(error))
        }
    }

    private static func search(client: SDKClient, userId: Int64, targeting: SDKAdTargeting) async -> NovagramAdsCheckSlotResult {
        let queries = self.searchQueries
        let outcomes: [Outcome] = await withTaskGroup(of: (Int, Outcome).self) { group in
            for (index, query) in queries.enumerated() {
                group.addTask {
                    return (index, await self.serve(.search(query: query), client: client, userId: userId, targeting: targeting))
                }
            }
            var ordered = [Outcome?](repeating: nil, count: queries.count)
            for await (index, outcome) in group {
                ordered[index] = outcome
            }
            return ordered.map { $0 ?? .failed(.cancelled) }
        }
        return self.result(.search, outcomes: outcomes, queries: queries)
    }

    private static func single(_ kind: NovagramAdsCheckSlot, slot: SDKAdSlot, client: SDKClient, userId: Int64, targeting: SDKAdTargeting) async -> NovagramAdsCheckSlotResult {
        let outcome = await self.serve(slot, client: client, userId: userId, targeting: targeting)
        return self.result(kind, outcomes: [outcome], queries: nil)
    }

    private static func banners(client: SDKClient, userId: Int64) async -> NovagramAdsCheckSlotResult {
        do {
            let banners = try await client.bannerAds.activeBanners(userId: userId)
            return NovagramAdsCheckSlotResult(slot: .banners, requests: 1, hits: banners.count)
        } catch {
            return NovagramAdsCheckSlotResult(slot: .banners, requests: 1, hits: 0, failures: 1, failure: self.failure(error))
        }
    }

    // MARK: - Results

    private static func result(_ kind: NovagramAdsCheckSlot, outcomes: [Outcome], queries: [String]?) -> NovagramAdsCheckSlotResult {
        var result = NovagramAdsCheckSlotResult(slot: kind, requests: outcomes.count, hits: 0)
        for (index, outcome) in outcomes.enumerated() {
            switch outcome {
            case let .served(sponsored):
                guard let sponsored else {
                    continue
                }
                result.hits += 1
                if result.firstHit == nil {
                    result.firstHit = self.promotedName(sponsored)
                    result.firstQuery = queries?[index]
                }
            case let .failed(failure):
                result.failures += 1
                if result.failure == nil {
                    result.failure = failure
                }
            }
        }
        return result
    }

    /// "@username" of the promoted peer, else its title.
    private static func promotedName(_ sponsored: SDKSponsoredAd) -> String {
        let username = sponsored.promoted.username.trimmingCharacters(in: CharacterSet(charactersIn: "@ "))
        if !username.isEmpty {
            return "@" + username
        }
        if !sponsored.promoted.title.isEmpty {
            return sponsored.promoted.title
        }
        return sponsored.displayTitle
    }

    /// The HTTP status class only: an SDK error's own text (`description`, `body`, `detail`) can carry
    /// a URL and is never read here.
    private static func failure(_ error: Error) -> NovagramAdsCheckFailure {
        if error is CancellationError {
            return .cancelled
        }
        if error is URLError {
            return .network
        }
        guard let error = error as? SDKError else {
            return .unknown
        }
        if case .transport = error {
            return .network
        }
        if let status = error.statusCode {
            if error.isAPIKeyRejected || status == 401 || status == 403 {
                return .keyRejected(status: status)
            }
            if status == 503 {
                return .unavailable(status: status)
            }
            if error.isRateLimited || status == 429 {
                return .rateLimited(status: status)
            }
            return .http(status: status)
        }
        switch error {
        case .unauthorized:
            return .keyRejected(status: 401)
        case .invalidResponse, .decoding:
            return .badResponse
        default:
            return error.isAPIKeyRejected ? .keyRejected(status: 403) : .unknown
        }
    }
}
