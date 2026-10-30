import Foundation

/// Reads the peer's name back from a recording's file name ("Name yyyy-MM-dd HH.mm" plus an optional " 2" / " 3"
/// de-dup suffix, see `NovagramCallRecordingStorage.fileName`) and makes the avatar initials. Pure functions, so they
/// can be unit tested without the app.
enum NovagramCallRecordingName {
    private static let stampPattern = " [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}\\.[0-9]{2}( [0-9]+)?$"
    private static let maxInitials = 2

    /// "Shoxrux Aka 2026-10-30 14.25 2" -> "Shoxrux Aka". A name without the date stamp comes back unchanged.
    static func peerName(fromFileName fileName: String) -> String {
        guard let range = fileName.range(of: stampPattern, options: .regularExpression) else {
            return fileName
        }
        let name = String(fileName[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? fileName : name
    }

    /// "Shoxrux Aka CodingTech" -> "SA", "Ali" -> "A".
    static func initials(of name: String) -> String {
        let words = name.split(whereSeparator: { $0.isWhitespace })
        let letters = words.prefix(maxInitials).compactMap { $0.first }
        return String(letters).uppercased()
    }

    /// A stable index for the avatar gradient: the same name always gets the same colour, on every launch
    /// (`hashValue` is seeded per process, so it cannot be used).
    static func colorIndex(of name: String, count: Int) -> Int {
        guard count > 0 else {
            return 0
        }
        let sum = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff }
        return sum % count
    }
}
