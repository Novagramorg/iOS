import Foundation

/// A TON transfer target parsed from either a bare address or a `ton://transfer` link.
///
/// Amounts are nanoton integers. Keeping them as `BigUInt` avoids imposing an application's
/// display or storage limits on the protocol parser.
public struct TransferURL: Sendable, Equatable {
    public let address: Address
    public let isTestOnly: Bool
    public let amount: BigUInt?
    public let text: String?

    public init(
        address: Address,
        isTestOnly: Bool = false,
        amount: BigUInt? = nil,
        text: String? = nil
    ) {
        self.address = address
        self.isTestOnly = isTestOnly
        self.amount = amount
        self.text = text
    }

    /// The validated address in a canonical user-friendly representation.
    public func addressString(
        urlSafe: Bool = true,
        bounceable: Bool = false
    ) -> String {
        address.toString(
            urlSafe: urlSafe,
            bounceable: bounceable,
            testOnly: isTestOnly
        )
    }

    /// Parses either a bare raw/user-friendly address or a `ton://transfer/<address>` link.
    public static func parse(_ string: String) throws -> TransferURL {
        let value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw TransferURLError.empty }

        if value.lowercased().hasPrefix("ton:") {
            return try parseLink(value)
        }
        do {
            return try TransferURL(addressString: value)
        } catch let error as Address.ParseError {
            throw TransferURLError.invalidAddress(error)
        }
    }

    private init(addressString: String, amount: BigUInt? = nil, text: String? = nil) throws {
        if addressString.contains(":") {
            self.address = try Address.parseRaw(addressString)
            self.isTestOnly = false
        } else {
            let friendly = try Address.parseFriendly(addressString)
            self.address = friendly.address
            self.isTestOnly = friendly.isTestOnly
        }
        self.amount = amount
        self.text = text
    }

    private static func parseLink(_ string: String) throws -> TransferURL {
        guard let components = URLComponents(string: string) else {
            throw TransferURLError.malformedURL(string)
        }
        guard components.scheme?.lowercased() == "ton" else {
            throw TransferURLError.unsupportedScheme(components.scheme)
        }
        guard components.host?.lowercased() == "transfer" else {
            throw TransferURLError.unsupportedAction(components.host)
        }

        let addressString = components.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !addressString.isEmpty else { throw TransferURLError.missingAddress }

        func queryValue(_ name: String) -> String? {
            components.queryItems?.first(where: { $0.name == name })?.value
        }

        let amount: BigUInt?
        if let value = queryValue("amount") {
            guard !value.isEmpty, let parsed = BigUInt(value, radix: 10) else {
                throw TransferURLError.invalidAmount(value)
            }
            amount = parsed
        } else {
            amount = nil
        }

        let text = queryValue("text").flatMap(Self.nonEmptyString)
        do {
            return try TransferURL(addressString: addressString, amount: amount, text: text)
        } catch let error as Address.ParseError {
            throw TransferURLError.invalidAddress(error)
        }
    }

    private static func nonEmptyString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public enum TransferURLError: Error, Equatable, CustomStringConvertible {
    case empty
    case malformedURL(String)
    case unsupportedScheme(String?)
    case unsupportedAction(String?)
    case missingAddress
    case invalidAddress(Address.ParseError)
    case invalidAmount(String)

    public var description: String {
        switch self {
        case .empty:
            return "Transfer target is empty"
        case .malformedURL(let value):
            return "Malformed TON transfer URL \"\(value)\""
        case .unsupportedScheme(let scheme):
            return "Unsupported TON transfer scheme \"\(scheme ?? "none")\""
        case .unsupportedAction(let action):
            return "Unsupported TON URL action \"\(action ?? "none")\""
        case .missingAddress:
            return "TON transfer URL carries no address"
        case .invalidAddress(let error):
            return "Invalid TON transfer address: \(error)"
        case .invalidAmount(let value):
            return "Invalid TON transfer amount \"\(value)\""
        }
    }
}
