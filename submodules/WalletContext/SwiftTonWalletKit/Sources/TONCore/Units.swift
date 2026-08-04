import Foundation

/// Fixed-point conversion between nanoton integers and decimal strings.
///
/// Deliberately string-based, never `Double`: 1 TON is 10^9 nanoton and jettons run to
/// 18 decimals, so binary floating point loses value silently.
public enum Units {
    public enum UnitsError: Error, CustomStringConvertible {
        case malformedDecimal(String)
        case negativeNotAllowed(String)
        case tooManyDecimals(String, maximum: Int)

        public var description: String {
            switch self {
            case .malformedDecimal(let s): return "Malformed decimal amount \"\(s)\""
            case .negativeNotAllowed(let s): return "Amount \"\(s)\" must not be negative"
            case .tooManyDecimals(let s, let maximum):
                return "Amount \"\(s)\" has more than \(maximum) decimal places"
            }
        }
    }

    /// Formats a base-unit integer as a decimal string, trimming trailing zeros.
    ///
    /// `formatUnits(1_500_000_000, decimals: 9) == "1.5"`
    public static func formatUnits(_ value: BigUInt, decimals: Int) -> String {
        guard decimals > 0 else { return String(value) }

        let divisor = BigUInt(10).power(decimals)
        let whole = value / divisor
        let fraction = value % divisor

        guard !fraction.isZero else { return String(whole) }

        var fractionText = String(fraction)
        if fractionText.count < decimals {
            fractionText = String(repeating: "0", count: decimals - fractionText.count) + fractionText
        }
        while fractionText.hasSuffix("0") { fractionText.removeLast() }

        return "\(whole).\(fractionText)"
    }

    /// Parses a decimal string into base units.
    ///
    /// `parseUnits("1.5", decimals: 9) == 1_500_000_000`
    public static func parseUnits(_ text: String, decimals: Int) throws -> BigUInt {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw UnitsError.malformedDecimal(text) }
        guard !trimmed.hasPrefix("-") else { throw UnitsError.negativeNotAllowed(text) }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { throw UnitsError.malformedDecimal(text) }

        let wholeText = parts[0].isEmpty ? "0" : String(parts[0])
        var fractionText = parts.count == 2 ? String(parts[1]) : ""

        guard wholeText.allSatisfy(\.isNumber), fractionText.allSatisfy(\.isNumber) else {
            throw UnitsError.malformedDecimal(text)
        }
        guard fractionText.count <= decimals else {
            throw UnitsError.tooManyDecimals(text, maximum: decimals)
        }
        guard let whole = BigUInt(wholeText, radix: 10) else {
            throw UnitsError.malformedDecimal(text)
        }

        // Right-pad the fraction to full precision.
        fractionText += String(repeating: "0", count: decimals - fractionText.count)
        let fraction = fractionText.isEmpty ? BigUInt(0) : (BigUInt(fractionText, radix: 10) ?? 0)

        return whole * BigUInt(10).power(decimals) + fraction
    }

    /// Nanoton count as a TON decimal string.
    public static func fromNano(_ value: BigUInt) -> String {
        formatUnits(value, decimals: 9)
    }

    /// TON decimal string as a nanoton count.
    public static func toNano(_ text: String) throws -> BigUInt {
        try parseUnits(text, decimals: 9)
    }

    /// Whole TON as nanoton.
    public static func toNano(_ value: Int) -> BigUInt {
        BigUInt(value) * BigUInt(10).power(9)
    }
}
