import Foundation
import TONWalletKit

let walletCollectibleFetchLimit = 30
private let walletCollectibleMetadataMaximumSize = 2 * 1024 * 1024

struct WalletCollectibleMetadata {
    var name: String?
    var imageUrl: String?

    var isComplete: Bool {
        return self.name != nil && self.imageUrl != nil
    }

    mutating func merge(_ other: WalletCollectibleMetadata) {
        if self.name == nil {
            self.name = other.name
        }
        if self.imageUrl == nil {
            self.imageUrl = other.imageUrl
        }
    }
}

private enum WalletCollectibleMetadataError: Error {
    case invalidData
}

private final class WalletURLSessionTaskCancellation {
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var isCancelled = false

    func setTask(_ task: URLSessionDataTask) {
        self.lock.lock()
        if self.isCancelled {
            self.lock.unlock()
            task.cancel()
        } else {
            self.task = task
            self.lock.unlock()
        }
    }

    func cancel() {
        self.lock.lock()
        self.isCancelled = true
        let task = self.task
        self.task = nil
        self.lock.unlock()
        task?.cancel()
    }
}

func walletCollectible(
    from nft: TONNFT,
    metadata: WalletCollectibleMetadata,
    receivedAt: Int32? = nil
) -> WalletContext.Collectible {
    let address = nft.address.value
    let index = nonEmptyCollectibleString(nft.index)

    let name: String
    if let metadataName = metadata.name {
        name = metadataName
    } else if let collectionName = nonEmptyCollectibleString(nft.collection?.name), let index, index.count <= 18 {
        name = "\(collectionName) #\(index)"
    } else if let index, index.count <= 18 {
        name = "Collectible #\(index)"
    } else {
        name = shortenedCollectibleAddress(address)
    }

    return WalletContext.Collectible(
        address: address,
        name: name,
        imageUrl: metadata.imageUrl,
        receivedAt: receivedAt
    )
}

func walletCollectibleMetadata(from nft: TONNFT) -> WalletCollectibleMetadata {
    let name = nonEmptyCollectibleString(nft.info?.name)
        ?? collectibleExtraString(nft.extra, keys: ["name", "title"])
    let imageUrl = collectibleImageUrl(info: nft.info?.image)
        ?? collectibleExtraUrlString(
            nft.extra,
            keys: ["_image_medium", "_image_small", "image", "image_url", "_image_big"]
        )
    return WalletCollectibleMetadata(name: name, imageUrl: imageUrl)
}

func walletCollectibleMetadataUrl(from nft: TONNFT) -> URL? {
    guard let value = collectibleExtraString(nft.extra, keys: ["uri", "metadata_url"]) else {
        return nil
    }
    return normalizedCollectibleUrl(value, relativeTo: nil)
}

func walletCollectibleMetadata(from url: URL) async throws -> WalletCollectibleMetadata {
    var request = URLRequest(url: url)
    request.cachePolicy = .returnCacheDataElseLoad
    request.timeoutInterval = 15.0
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let data = try await walletCollectibleMetadataData(request: request)
    guard data.count <= walletCollectibleMetadataMaximumSize,
          let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw WalletCollectibleMetadataError.invalidData
    }

    let name = nonEmptyCollectibleString(object["name"] as? String)
        ?? nonEmptyCollectibleString(object["title"] as? String)
    var imageUrl: String?
    for key in ["_image_medium", "_image_small", "image", "image_url", "_image_big"] {
        guard let value = nonEmptyCollectibleString(object[key] as? String),
              let resolvedUrl = normalizedCollectibleUrl(value, relativeTo: url) else {
            continue
        }
        imageUrl = resolvedUrl.absoluteString
        break
    }
    return WalletCollectibleMetadata(name: name, imageUrl: imageUrl)
}

private func walletCollectibleMetadataData(request: URLRequest) async throws -> Data {
    let cancellation = WalletURLSessionTaskCancellation()
    return try await withTaskCancellationHandler(operation: {
        try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let response = response as? HTTPURLResponse,
                      (200 ..< 300).contains(response.statusCode),
                      let data,
                      data.count <= walletCollectibleMetadataMaximumSize else {
                    continuation.resume(throwing: WalletCollectibleMetadataError.invalidData)
                    return
                }
                continuation.resume(returning: data)
            }
            cancellation.setTask(task)
            task.resume()
        }
    }, onCancel: {
        cancellation.cancel()
    })
}

private func nonEmptyCollectibleString(_ value: String?) -> String? {
    guard var value else {
        return nil
    }
    value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
}

func mergeCollectibles(
    existing: [WalletContext.Collectible],
    new: [WalletContext.Collectible]
) -> [WalletContext.Collectible] {
    var result = existing
    var indexByAddress: [String: Int] = [:]
    indexByAddress.reserveCapacity(existing.count + new.count)
    for (index, collectible) in existing.enumerated() {
        indexByAddress[collectible.address] = index
    }
    for collectible in new {
        let addressKey = collectible.address
        if let index = indexByAddress[addressKey] {
            result[index] = collectible
        } else {
            indexByAddress[addressKey] = result.count
            result.append(collectible)
        }
    }
    return result
}

private func collectibleImageUrl(info: TONTokenImage?) -> String? {
    let candidates: [URL?] = [
        info?.mediumUrl,
        info?.smallUrl,
        info?.url,
        info?.largeUrl
    ]
    for candidate in candidates {
        if let candidate, let result = normalizedCollectibleImageUrl(candidate) {
            return result
        }
    }
    return nil
}

private func collectibleExtraString(_ extra: [String: AnyCodable]?, keys: [String]) -> String? {
    guard let extra else {
        return nil
    }
    for key in keys {
        if let value = nonEmptyCollectibleString(decodedString(extra[key])) {
            return value
        }
    }
    return nil
}

private func collectibleExtraUrlString(_ extra: [String: AnyCodable]?, keys: [String]) -> String? {
    guard let value = collectibleExtraString(extra, keys: keys),
          let url = normalizedCollectibleUrl(value, relativeTo: nil) else {
        return nil
    }
    return url.absoluteString
}

private func normalizedCollectibleUrl(_ value: String, relativeTo baseUrl: URL?) -> URL? {
    guard let value = nonEmptyCollectibleString(value) else {
        return nil
    }
    let url: URL?
    if value.lowercased().hasPrefix("ipfs://") {
        if let ipfsUrl = URL(string: value),
           let normalized = normalizedCollectibleImageUrl(ipfsUrl) {
            url = URL(string: normalized)
        } else {
            url = nil
        }
    } else {
        url = URL(string: value, relativeTo: baseUrl)?.absoluteURL
    }
    guard let url, let normalized = normalizedCollectibleImageUrl(url) else {
        return nil
    }
    return URL(string: normalized)
}

private func normalizedCollectibleImageUrl(_ url: URL) -> String? {
    guard let scheme = url.scheme?.lowercased() else {
        return nil
    }
    switch scheme {
    case "http", "https":
        guard let host = url.host, !host.isEmpty else {
            return nil
        }
        return url.absoluteString
    case "ipfs":
        var path = String(url.absoluteString.dropFirst("ipfs://".count))
        while path.hasPrefix("/") {
            path.removeFirst()
        }
        if path.hasPrefix("ipfs/") {
            path.removeFirst("ipfs/".count)
        }
        guard !path.isEmpty else {
            return nil
        }
        return "https://ipfs.io/ipfs/\(path)"
    default:
        return nil
    }
}

private func shortenedCollectibleAddress(_ address: String) -> String {
    guard address.count > 14 else {
        return address
    }
    return "\(address.prefix(6))…\(address.suffix(6))"
}
