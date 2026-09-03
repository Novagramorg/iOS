import Foundation
import WalletEngineFFI

private let walletCollectibleMetadataMaximumSize = 2 * 1024 * 1024
private let walletCollectibleLottieHosts: Set<String> = ["nft.fragment.com"]
private let walletTelegramAnonymousNumbersCollection = "0:0e41dc1dc3c9067ed24248580e12b3359818d83dee0304fabcf80845eafafdb2"
private let walletTelegramUsernamesCollection = "0:80d78a35f955a14b679faa887ff4cd5bfc0f43b4a4eea2a7e6927f3701b273c2"

struct WalletCollectibleMetadata {
    var name: String?
    var description: String?
    var imageUrl: String?
    var lottieUrl: String?
    var collectionName: String?
    var collectionUrl: String?
    var attributes: [String: String]

    mutating func merge(_ other: WalletCollectibleMetadata) {
        self.name = self.name ?? other.name
        self.description = self.description ?? other.description
        self.imageUrl = self.imageUrl ?? other.imageUrl
        self.lottieUrl = self.lottieUrl ?? other.lottieUrl
        self.collectionName = self.collectionName ?? other.collectionName
        self.collectionUrl = self.collectionUrl ?? other.collectionUrl
        for (key, value) in other.attributes where self.attributes[key] == nil {
            self.attributes[key] = value
        }
    }
}

func walletCollectibles(
    from values: [NftItem],
    errorLogger: WalletContextErrorLogger
) async -> [WalletContext.Collectible] {
    var result: [WalletContext.Collectible] = []
    result.reserveCapacity(values.count)
    for value in values {
        var metadata = walletCollectibleMetadata(from: value)
        if walletCollectibleNeedsRemoteMetadata(value, metadata: metadata),
           let url = walletCollectibleMetadataUrl(from: value) {
            do {
                metadata.merge(try await walletCollectibleMetadata(from: url))
            } catch {
                errorLogger.error("wallet_collectible_metadata_fetch_failed", error)
            }
        }
        result.append(walletCollectible(from: value, metadata: metadata))
    }
    return result
}

func walletCollectible(
    from nft: NftItem,
    metadata: WalletCollectibleMetadata
) -> WalletContext.Collectible {
    let address = nft.address
    let collectionName = metadata.collectionName ?? nonEmptyCollectibleString(nft.collection?.name)
    let name = metadata.name
        ?? collectionName.map { "\($0) #\(nft.index)" }
        ?? shortenedCollectibleAddress(address)
    let kind = walletCollectibleKind(from: nft)
    let subtitle: String
    if kind == .gift,
       let model = metadata.attributes["model"],
       let backdrop = metadata.attributes["backdrop"] {
        subtitle = "\(model) on \(backdrop)"
    } else {
        switch kind {
        case .username: subtitle = "Username"
        case .anonymousNumber: subtitle = "Anonymous Number"
        case .gift, .other: subtitle = collectionName ?? "NFT"
        }
    }

    return WalletContext.Collectible(
        address: address,
        name: name,
        imageUrl: metadata.imageUrl,
        subtitle: subtitle,
        kind: kind,
        description: metadata.description,
        lottieUrl: metadata.lottieUrl,
        collectionName: collectionName,
        collectionUrl: metadata.collectionUrl,
        attributes: metadata.attributes,
        giftSlug: kind == .gift ? walletCollectibleGiftSlug(name: name, metadataUrl: walletCollectibleMetadataUrl(from: nft)) : nil,
        receivedAt: nil
    )
}

private func walletCollectibleMetadata(from nft: NftItem) -> WalletCollectibleMetadata {
    let content = nft.content
    let collectionContent = nft.collection?.content ?? [:]
    var attributes: [String: String] = [:]
    for key in ["model", "backdrop", "symbol", "rarity"] {
        if let value = nonEmptyCollectibleString(content[key]) {
            attributes[key] = value
        }
    }
    if let encoded = content["attributes"],
       let data = encoded.data(using: .utf8),
       let value = try? JSONSerialization.jsonObject(with: data) {
        attributes.merge(collectibleAttributes(from: value)) { current, _ in current }
    }
    return WalletCollectibleMetadata(
        name: firstCollectibleString(content, keys: ["name", "title"]),
        description: firstCollectibleString(content, keys: ["description"]),
        imageUrl: firstCollectibleUrl(content, keys: ["_image_medium", "_image_small", "image", "image_url", "preview", "_image_big"]),
        lottieUrl: normalizedCollectibleLottieUrl(firstCollectibleString(content, keys: ["lottie"])),
        collectionName: nonEmptyCollectibleString(nft.collection?.name)
            ?? firstCollectibleString(collectionContent, keys: ["name"]),
        collectionUrl: normalizedFragmentCollectibleUrl(firstCollectibleString(collectionContent, keys: ["external_link", "url"])),
        attributes: attributes
    )
}

private func walletCollectibleMetadataUrl(from nft: NftItem) -> URL? {
    guard let value = firstCollectibleString(nft.content, keys: ["uri", "metadata_url", "content_uri"]) else {
        return nil
    }
    return normalizedCollectibleUrl(value, relativeTo: nil)
}

private final class WalletCollectibleDataTask: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var cancelled = false

    func set(_ task: URLSessionDataTask) {
        self.lock.lock()
        if self.cancelled {
            self.lock.unlock()
            task.cancel()
        } else {
            self.task = task
            self.lock.unlock()
        }
    }

    func cancel() {
        self.lock.lock()
        self.cancelled = true
        let task = self.task
        self.task = nil
        self.lock.unlock()
        task?.cancel()
    }
}

private func walletCollectibleData(for request: URLRequest) async throws -> (Data, URLResponse) {
    let cancellation = WalletCollectibleDataTask()
    return try await withTaskCancellationHandler(operation: {
        try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, let response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                }
            }
            cancellation.set(task)
            task.resume()
        }
    }, onCancel: {
        cancellation.cancel()
    })
}

private func walletCollectibleMetadata(from url: URL) async throws -> WalletCollectibleMetadata {
    var request = URLRequest(url: url)
    request.cachePolicy = .returnCacheDataElseLoad
    request.timeoutInterval = 15
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let (data, response) = try await walletCollectibleData(for: request)
    guard let response = response as? HTTPURLResponse,
          (200 ..< 300).contains(response.statusCode),
          data.count <= walletCollectibleMetadataMaximumSize,
          let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw URLError(.badServerResponse)
    }
    let strings = object.compactMapValues { $0 as? String }
    return WalletCollectibleMetadata(
        name: firstCollectibleString(strings, keys: ["name", "title"]),
        description: firstCollectibleString(strings, keys: ["description"]),
        imageUrl: firstCollectibleUrl(strings, keys: ["_image_medium", "_image_small", "image", "image_url", "_image_big"], relativeTo: url),
        lottieUrl: normalizedCollectibleLottieUrl(strings["lottie"], relativeTo: url),
        collectionName: nil,
        collectionUrl: nil,
        attributes: collectibleAttributes(from: object["attributes"])
    )
}

private func walletCollectibleNeedsRemoteMetadata(
    _ nft: NftItem,
    metadata: WalletCollectibleMetadata
) -> Bool {
    if metadata.name == nil || metadata.imageUrl == nil || metadata.description == nil {
        return true
    }
    return walletCollectibleKind(from: nft) == .gift
        && (metadata.attributes["model"] == nil || metadata.attributes["backdrop"] == nil)
}

private func walletCollectibleKind(from nft: NftItem) -> WalletContext.Collectible.Kind {
    let collectionAddress = nft.collectionAddress.flatMap {
        try? convertTonAddress(value: $0, format: .raw).lowercased()
    }
    if collectionAddress == walletTelegramUsernamesCollection { return .username }
    if collectionAddress == walletTelegramAnonymousNumbersCollection { return .anonymousNumber }

    let metadata = walletCollectibleMetadataUrl(from: nft)?.absoluteString.lowercased()
    if metadata?.contains("nft.fragment.com/gift/") == true { return .gift }
    if metadata?.contains("nft.fragment.com/username/") == true { return .username }
    if metadata?.contains("nft.fragment.com/number/") == true { return .anonymousNumber }
    return .other
}

private func walletCollectibleGiftSlug(name: String, metadataUrl: URL?) -> String? {
    if let hash = name.lastIndex(of: "#") {
        let title = name[..<hash].filter { $0.isLetter || $0.isNumber }
        let number = name[name.index(after: hash)...].trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty, !number.isEmpty, number.allSatisfy(\.isNumber) {
            return String(title) + "-" + number
        }
    }
    guard let metadataUrl,
          metadataUrl.absoluteString.lowercased().contains("nft.fragment.com/gift/") else {
        return nil
    }
    return nonEmptyCollectibleString(metadataUrl.deletingPathExtension().lastPathComponent)
}

private func firstCollectibleString(_ values: [String: String], keys: [String]) -> String? {
    keys.lazy.compactMap { nonEmptyCollectibleString(values[$0]) }.first
}

private func firstCollectibleUrl(
    _ values: [String: String],
    keys: [String],
    relativeTo baseUrl: URL? = nil
) -> String? {
    guard let value = firstCollectibleString(values, keys: keys) else { return nil }
    return normalizedCollectibleUrl(value, relativeTo: baseUrl)?.absoluteString
}

private func collectibleAttributes(from value: Any?) -> [String: String] {
    guard let attributes = value as? [[String: Any]] else { return [:] }
    var result: [String: String] = [:]
    for attribute in attributes {
        guard let key = nonEmptyCollectibleString(attribute["trait_type"] as? String ?? attribute["traitType"] as? String)?.lowercased(),
              let value = nonEmptyCollectibleString(attribute["value"] as? String) else {
            continue
        }
        result[key] = value
    }
    return result
}

private func nonEmptyCollectibleString(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
        return nil
    }
    return value
}

func normalizedCollectibleUrl(_ value: String, relativeTo baseUrl: URL?) -> URL? {
    guard let value = nonEmptyCollectibleString(value) else { return nil }
    if value.lowercased().hasPrefix("ipfs://") {
        var path = String(value.dropFirst("ipfs://".count))
        while path.hasPrefix("/") { path.removeFirst() }
        if path.hasPrefix("ipfs/") { path.removeFirst("ipfs/".count) }
        return path.isEmpty ? nil : URL(string: "https://ipfs.io/ipfs/\(path)")
    }
    guard let url = URL(string: value, relativeTo: baseUrl)?.absoluteURL,
          ["http", "https"].contains(url.scheme?.lowercased()),
          url.host?.isEmpty == false else {
        return nil
    }
    return url
}

func normalizedFragmentCollectibleUrl(_ value: String?, relativeTo baseUrl: URL? = nil) -> String? {
    guard let value,
          let url = normalizedCollectibleUrl(value, relativeTo: baseUrl),
          url.scheme?.lowercased() == "https",
          url.host?.lowercased() == "fragment.com" else {
        return nil
    }
    return url.absoluteString
}

func normalizedCollectibleLottieUrl(_ value: String?, relativeTo baseUrl: URL? = nil) -> String? {
    guard let value,
          let url = normalizedCollectibleUrl(value, relativeTo: baseUrl),
          url.scheme?.lowercased() == "https",
          let host = url.host?.lowercased(),
          walletCollectibleLottieHosts.contains(host) else {
        return nil
    }
    return url.absoluteString
}

func shortenedCollectibleAddress(_ address: String) -> String {
    address.count > 14 ? "\(address.prefix(6))…\(address.suffix(6))" : address
}
