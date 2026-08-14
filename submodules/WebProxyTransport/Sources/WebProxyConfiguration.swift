import CommonCrypto
import Foundation

public struct WebProxyConfiguration: Equatable, Hashable {
    public static let port: UInt16 = 443

    public let host: String
    public let secret: Data

    public init?(host: String, secret: Data) {
        guard let host = Self.canonicalHost(host), Self.isValidSecret(secret) else {
            return nil
        }
        self.host = host
        self.secret = secret
    }

    public static func isValidSecret(_ secret: Data) -> Bool {
        return secret.count == 16 || (secret.count == 17 && secret.first == 0xdd)
    }

    public static func parseSecret(_ value: String) -> Data? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count % 2 == 0, value.allSatisfy({ $0.isHexDigit }) {
            var result = Data()
            result.reserveCapacity(value.count / 2)
            var index = value.startIndex
            while index < value.endIndex {
                let next = value.index(index, offsetBy: 2)
                guard let byte = UInt8(value[index ..< next], radix: 16) else {
                    return nil
                }
                result.append(byte)
                index = next
            }
            return isValidSecret(result) ? result : nil
        }

        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        guard let result = Data(base64Encoded: base64), isValidSecret(result) else {
            return nil
        }
        return result
    }

    public static func canonicalHost(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("/"),
              !trimmed.contains("@"),
              !trimmed.contains(":"),
              let components = URLComponents(string: "https://\(trimmed)"),
              components.user == nil,
              components.password == nil,
              components.port == nil,
              let host = components.url?.host?.lowercased(),
              !host.isEmpty,
              host.utf8.count <= 253 else {
            return nil
        }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2,
              !labels.allSatisfy({ label in Int(label) != nil }),
              labels.allSatisfy({ label in
            !label.isEmpty && label.utf8.count <= 63 && label.first != "-" && label.last != "-" && label.allSatisfy { character in
                character.isASCII && (character.isLetter || character.isNumber || character == "-")
            }
        }) else {
            return nil
        }
        return host
    }

    public var secretHex: String {
        return self.secret.map { String(format: "%02x", $0) }.joined()
    }

    public func bridgeCapability() -> String {
        let context = Data("tdesktop-web-proxy-bridge-v1\n\(self.host)".utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.secret.withUnsafeBytes { keyBytes in
            context.withUnsafeBytes { contextBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes.baseAddress, self.secret.count, contextBytes.baseAddress, context.count, &digest)
            }
        }
        return Data(digest).webProxyBase64Url
    }

    public func bridgeURL(nonce: String) -> URL? {
        guard nonce.utf8.count == 43 else {
            return nil
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = self.host
        components.path = "/"
        components.queryItems = [URLQueryItem(name: "bridge", value: self.bridgeCapability())]
        components.fragment = "android=\(nonce)"
        return components.url
    }
}

extension Data {
    var webProxyBase64Url: String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
