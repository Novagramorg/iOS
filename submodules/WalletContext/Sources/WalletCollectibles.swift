import Foundation
import TONCore
import TONToncenter

let walletCollectibleFetchLimit = 30
private let walletCollectibleMetadataMaximumSize = 2 * 1024 * 1024
private let walletCollectibleLottieHosts: Set<String> = [
    "nft.fragment.com"
]
private let walletTelegramAnonymousNumbersCollection = "0:0e41dc1dc3c9067ed24248580e12b3359818d83dee0304fabcf80845eafafdb2"
private let walletTelegramUsernamesCollection = "0:80d78a35f955a14b679faa887ff4cd5bfc0f43b4a4eea2a7e6927f3701b273c2"

struct WalletCollectibleMetadata {
    var name: String?
    var description: String?
    var imageUrl: String?
    var lottieUrl: String?
    var collectionName: String?
    var collectionUrl: String?
    var attributes: [String: String] = [:]

    init(
        name: String?,
        description: String? = nil,
        imageUrl: String?,
        lottieUrl: String? = nil,
        collectionName: String? = nil,
        collectionUrl: String? = nil,
        attributes: [String: String] = [:]
    ) {
        self.name = name
        self.description = description
        self.imageUrl = imageUrl
        self.lottieUrl = lottieUrl
        self.collectionName = collectionName
        self.collectionUrl = collectionUrl
        self.attributes = attributes
    }

    var isComplete: Bool {
        return self.name != nil && self.imageUrl != nil
    }

    mutating func merge(_ other: WalletCollectibleMetadata) {
        if self.name == nil {
            self.name = other.name
        }
        if self.description == nil {
            self.description = other.description
        }
        if self.imageUrl == nil {
            self.imageUrl = other.imageUrl
        }
        if self.lottieUrl == nil {
            self.lottieUrl = other.lottieUrl
        }
        if self.collectionName == nil {
            self.collectionName = other.collectionName
        }
        if self.collectionUrl == nil {
            self.collectionUrl = other.collectionUrl
        }
        for (key, value) in other.attributes where self.attributes[key] == nil {
            self.attributes[key] = value
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
    from nft: NFTItem,
    metadata: WalletCollectibleMetadata,
    receivedAt: Int32? = nil
) -> WalletContext.Collectible {
    let address = nft.address
    let index = nonEmptyCollectibleString(nft.index)

    let name: String
    if let metadataName = metadata.name {
        name = metadataName
    } else if let collectionName = nonEmptyCollectibleString(nft.collectionInfo?.name), let index {
        name = "\(collectionName) #\(index)"
    } else {
        name = shortenedCollectibleAddress(address)
    }
    let kind = walletCollectibleKind(from: nft)

    return WalletContext.Collectible(
        address: address,
        name: name,
        imageUrl: metadata.imageUrl,
        subtitle: walletCollectibleSubtitle(from: nft, metadata: metadata),
        kind: kind,
        description: metadata.description,
        lottieUrl: metadata.lottieUrl,
        collectionName: metadata.collectionName ?? nonEmptyCollectibleString(nft.collectionInfo?.name),
        collectionUrl: metadata.collectionUrl,
        attributes: metadata.attributes,
        giftSlug: kind == .gift ? walletCollectibleGiftSlug(
            name: name,
            metadataUrl: walletCollectibleMetadataUrl(from: nft)
        ) : nil,
        receivedAt: receivedAt
    )
}

func walletCollectibleMetadata(from nft: NFTItem) -> WalletCollectibleMetadata {
    let name = nonEmptyCollectibleString(nft.info?.name)
        ?? collectibleExtraString(nft.info?.extra, keys: ["name", "title"])
    let description = nonEmptyCollectibleString(nft.info?.description)
        ?? collectibleExtraString(nft.info?.extra, keys: ["description"])
    let imageUrl = nft.info?.imageURL.flatMap { normalizedCollectibleUrl($0, relativeTo: nil)?.absoluteString }
        ?? collectibleExtraUrlString(
            nft.info?.extra,
            keys: ["_image_medium", "_image_small", "image", "image_url", "_image_big"]
        )
    let lottieUrl = normalizedCollectibleLottieUrl(collectibleExtraString(nft.info?.extra, keys: ["lottie"]))
    let collectionName = nonEmptyCollectibleString(nft.collectionInfo?.name)
    let collectionUrl = normalizedFragmentCollectibleUrl(
        collectibleExtraString(nft.collectionInfo?.extra, keys: ["external_link"])
    )
    return WalletCollectibleMetadata(
        name: name,
        description: description,
        imageUrl: imageUrl,
        lottieUrl: lottieUrl,
        collectionName: collectionName,
        collectionUrl: collectionUrl,
        attributes: [:]
    )
}

func walletCollectibleMetadataUrl(from nft: NFTItem) -> URL? {
    guard let value = nonEmptyCollectibleString(nft.contentURI)
        ?? collectibleExtraString(nft.info?.extra, keys: ["uri", "metadata_url"]) else {
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
    let description = nonEmptyCollectibleString(object["description"] as? String)
    var imageUrl: String?
    for key in ["_image_medium", "_image_small", "image", "image_url", "_image_big"] {
        guard let value = nonEmptyCollectibleString(object[key] as? String),
              let resolvedUrl = normalizedCollectibleUrl(value, relativeTo: url) else {
            continue
        }
        imageUrl = resolvedUrl.absoluteString
        break
    }
    return WalletCollectibleMetadata(
        name: name,
        description: description,
        imageUrl: imageUrl,
        lottieUrl: nonEmptyCollectibleString(object["lottie"] as? String)
            .flatMap { normalizedCollectibleLottieUrl($0, relativeTo: url) },
        attributes: collectibleAttributes(from: object["attributes"])
    )
}

func walletCollectibleNeedsRemoteMetadata(
    from nft: NFTItem,
    metadata: WalletCollectibleMetadata
) -> Bool {
    if !metadata.isComplete || metadata.description == nil {
        return true
    }
    guard walletCollectibleKind(from: nft) == .gift else {
        return false
    }
    return metadata.attributes["model"] == nil
        || metadata.attributes["backdrop"] == nil
        || metadata.lottieUrl == nil
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

private func walletCollectibleSubtitle(
    from nft: NFTItem,
    metadata: WalletCollectibleMetadata
) -> String {
    let collectionName = nonEmptyCollectibleString(nft.collectionInfo?.name) ?? "NFT"
    switch walletCollectibleKind(from: nft) {
    case .gift:
        guard let model = nonEmptyCollectibleString(metadata.attributes["model"]),
              let backdrop = nonEmptyCollectibleString(metadata.attributes["backdrop"]) else {
            return collectionName
        }
        return "\(model) on \(backdrop)"
    case .username:
        return "Username"
    case .anonymousNumber:
        return "Anonymous Number"
    case .other:
        return collectionName
    }
}

private func walletCollectibleKind(from nft: NFTItem) -> WalletContext.Collectible.Kind {
    let collectionAddress = nft.collectionAddress
        .flatMap { try? Address.parse($0).rawString.lowercased() }
    if collectionAddress == walletTelegramUsernamesCollection {
        return .username
    }
    if collectionAddress == walletTelegramAnonymousNumbersCollection {
        return .anonymousNumber
    }

    let metadataUrl = walletCollectibleMetadataUrl(from: nft)?.absoluteString.lowercased()
    if metadataUrl?.contains("nft.fragment.com/gift/") == true {
        return .gift
    }
    if metadataUrl?.contains("nft.fragment.com/username/") == true {
        return .username
    }
    if metadataUrl?.contains("nft.fragment.com/number/") == true {
        return .anonymousNumber
    }
    return .other
}

private func walletCollectibleGiftSlug(name: String, metadataUrl: URL?) -> String? {
    if let hashIndex = name.lastIndex(of: "#") {
        let title = String(name[..<hashIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let number = String(name[name.index(after: hashIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty, !number.isEmpty, number.allSatisfy({ $0.isNumber }) {
            let compactTitle = title.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
            if !compactTitle.isEmpty {
                return String(compactTitle) + "-" + number
            }
        }
    }
    guard let metadataUrl,
          metadataUrl.absoluteString.lowercased().contains("nft.fragment.com/gift/") else {
        return nil
    }
    return nonEmptyCollectibleString(metadataUrl.deletingPathExtension().lastPathComponent)
}

private func collectibleAttributes(from value: Any?) -> [String: String] {
    guard let attributes = value as? [[String: Any]] else {
        return [:]
    }
    var result: [String: String] = [:]
    for attribute in attributes {
        guard let key = normalizedCollectibleAttributeKey(
            attribute["trait_type"] as? String ?? attribute["traitType"] as? String
        ), let value = nonEmptyCollectibleString(attribute["value"] as? String) else {
            continue
        }
        result[key] = value
    }
    return result
}

private func normalizedCollectibleAttributeKey(_ value: String?) -> String? {
    return nonEmptyCollectibleString(value)?.lowercased()
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

private func collectibleExtraString(_ extra: [String: String]?, keys: [String]) -> String? {
    guard let extra else {
        return nil
    }
    for key in keys {
        if let value = nonEmptyCollectibleString(extra[key]) {
            return value
        }
    }
    return nil
}

private func collectibleExtraUrlString(_ extra: [String: String]?, keys: [String]) -> String? {
    guard let value = collectibleExtraString(extra, keys: keys),
          let url = normalizedCollectibleUrl(value, relativeTo: nil) else {
        return nil
    }
    return url.absoluteString
}

func normalizedCollectibleUrl(_ value: String, relativeTo baseUrl: URL?) -> URL? {
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

func shortenedCollectibleAddress(_ address: String) -> String {
    guard address.count > 14 else {
        return address
    }
    return "\(address.prefix(6))…\(address.suffix(6))"
}
