import Foundation
import SwiftSignalKit
import TelegramApi

public struct CurrencyRate {
    public let currency: String
    public let rate: Double

    public init(currency: String, rate: Double) {
        self.currency = currency
        self.rate = rate
    }
}

func _internal_currencyRates(account: Account) -> Signal<[CurrencyRate]?, NoError> {
    return account.network.request(Api.functions.payments.getCurrencyRates())
    |> map { result -> [CurrencyRate]? in
        switch result {
        case let .currencyRates(currencyRatesData):
            return currencyRatesData.rates.map { currencyRate in
                switch currencyRate {
                case let .currencyRate(currencyRateData):
                    return CurrencyRate(currency: currencyRateData.currency, rate: currencyRateData.rate)
                }
            }
        }
    }
    |> `catch` { _ -> Signal<[CurrencyRate]?, NoError> in
        return .single(nil)
    }
}
