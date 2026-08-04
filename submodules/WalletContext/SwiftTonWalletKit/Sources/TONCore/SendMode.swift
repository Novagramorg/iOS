import Foundation

/// Outgoing-message mode flags, as passed to `SENDRAWMSG`.
///
/// An option set rather than a plain integer, because these are combined far more
/// often than used alone — wallet transfers use
/// `[.payGasSeparately, .ignoreErrors]`.
public struct SendMode: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let none = SendMode([])

    /// Carry the whole remaining balance of the sending account.
    public static let carryAllRemainingBalance = SendMode(rawValue: 128)

    /// Carry the remaining value of the inbound message.
    public static let carryAllRemainingIncomingValue = SendMode(rawValue: 64)

    /// Destroy the account if its resulting balance is zero.
    public static let destroyAccountIfZero = SendMode(rawValue: 32)

    /// Pay forwarding fees from the sender's balance rather than the message value.
    public static let payGasSeparately = SendMode(rawValue: 1)

    /// Ignore errors in action processing instead of aborting the whole list.
    public static let ignoreErrors = SendMode(rawValue: 2)

    /// The mode wallet transfers use: fees from the balance, and a failed action does
    /// not roll back the rest of the list.
    public static let walletDefault: SendMode = [.payGasSeparately, .ignoreErrors]
}
