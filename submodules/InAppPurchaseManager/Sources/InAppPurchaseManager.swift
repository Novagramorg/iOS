import Foundation
import SwiftSignalKit
import TelegramCore
import FenixuzAppStoreIAP

// MARK: - Fenixuz fork: complete IAP removal (Apple 3.1.1, May 2026 rejection)
//
// This module used to wrap StoreKit (`SKPaymentQueue`, `SKProductsRequest`,
// `SKPayment`, `SKPaymentTransactionObserver`, `SKReceipt*`) and drive the
// app's in-app purchase flow for Premium / Stars / Gifts / Business.
//
// The Fenixuz fork does NOT sell digital subscriptions, Stars, gifts, or any
// other IAP product. Telegram's backend only credits IAP receipts issued for
// the official Telegram client bundle (`ph.telegra.Telegraph`), so registering
// StoreKit products for `uz.fenixuz.app` would be theatre — the receipt would
// fail server-side. After the May 2026 Apple rejection (submission
// `d5a06920-6b5f-4167-b7fb-46c80b156aa8`, guideline 3.1.1) we first gated the
// flow with a runtime alert; this revision goes further and removes the
// StoreKit code path entirely so the binary contains no reachable
// `SK*` API call.
//
// Public surface preserved:
//   - `InAppPurchaseManager` class with `init(engine:)`, `availableProducts`,
//     `buyProduct(_:quantity:purpose:)`, `restorePurchases(completion:)`,
//     `finishAllTransactions()`, `getReceiptPurchases()`, `canMakePayments`.
//   - Public nested types: `Product`, `PurchaseState`, `PurchaseError`,
//     `RestoreState`, `ReceiptPurchase`.
// These are kept compilable for the 13 consumer modules; their bodies are
// fail-fast stubs that route through `FenixuzAppStoreIAP.presentBlockedAlertOnTop()`
// and return `.fail(.cancelled)` or empty signals.
//
// `availableProducts` is permanently `.single([])` so no `Product` is ever
// constructed and the `Product` class is effectively unreachable.
//
// See submodules/Fenixuz/HOOKS.md → "App Store IAP gate" for full context.

public final class InAppPurchaseManager: NSObject {
    public final class Product: Equatable {
        // No StoreKit-backed state — this class is kept as a public type for
        // consumer compilation only. `availableProducts` returns `[]`, so no
        // instance is ever constructed at runtime.

        fileprivate init() {}

        public var id: String {
            return ""
        }

        public var isSubscription: Bool {
            return false
        }

        public var price: String {
            return ""
        }

        public func pricePerMonth(_ monthsCount: Int) -> String {
            return ""
        }

        public func defaultPrice(_ value: NSDecimalNumber, monthsCount: Int) -> String {
            return ""
        }

        public func multipliedPrice(count: Int) -> String {
            return ""
        }

        public var priceValue: NSDecimalNumber {
            return NSDecimalNumber.zero
        }

        public var priceCurrencyAndAmount: (currency: String, amount: Int64) {
            return ("", 0)
        }

        public static func ==(lhs: Product, rhs: Product) -> Bool {
            return lhs === rhs
        }
    }

    public enum PurchaseState {
        case purchased(transactionId: String)
    }

    public enum PurchaseError {
        case generic
        case cancelled
        case network
        case notAllowed
        case cantMakePayments
        case assignFailed
        case tryLater
    }

    public enum RestoreState {
        case succeed(Bool)
        case failed
    }

    public struct ReceiptPurchase: Equatable {
        public let productId: String
        public let transactionId: String
        public let expirationDate: Date

        public init(productId: String, transactionId: String, expirationDate: Date) {
            self.productId = productId
            self.transactionId = transactionId
            self.expirationDate = expirationDate
        }
    }

    private let engine: SomeTelegramEngine

    public init(engine: SomeTelegramEngine) {
        self.engine = engine
        super.init()
    }

    public var canMakePayments: Bool {
        return false
    }

    /// Permanently empty — the fork has no registered IAP products.
    public var availableProducts: Signal<[Product], NoError> {
        return .single([])
    }

    /// Fail-fast — every Subscribe/Buy tap shows the Fenixuz IAP alert and
    /// returns `.cancelled` so existing call sites silently dismiss the flow
    /// without a double error toast.
    public func buyProduct(_ product: Product, quantity: Int32 = 1, purpose: AppStoreTransactionPurpose) -> Signal<PurchaseState, PurchaseError> {
        FenixuzAppStoreIAP.presentBlockedAlertOnTop()
        return .fail(.cancelled)
    }

    /// Show the IAP alert and report restore failure to the caller.
    public func restorePurchases(completion: @escaping (RestoreState) -> Void) {
        FenixuzAppStoreIAP.presentBlockedAlertOnTop()
        Queue.mainQueue().async {
            completion(.failed)
        }
    }

    /// No StoreKit queue is observed — nothing to finish.
    public func finishAllTransactions() {
    }

    /// No StoreKit receipt is requested — the fork never produces one.
    public func getReceiptPurchases() -> [ReceiptPurchase] {
        return []
    }
}
