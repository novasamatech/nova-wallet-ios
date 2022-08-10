import Foundation
import CommonWallet

struct CoingeckoPriceData: Decodable, Equatable {
    typealias Currency = String
    let data: [Currency: CoingeckoSingleCurrencyPriceData]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let currencyProperties = try container.decode([String: Decimal?].self)

        let currencies = currencyProperties.filter { $0.key.split(separator: "_").count == 1 }
        var result: [Currency: CoingeckoSingleCurrencyPriceData] = [:]

        for currency in currencies {
            guard let price = currency.value else {
                continue
            }
            result[currency.key] = CoingeckoSingleCurrencyPriceData(
                price: price,
                dayChange: currencyProperties["\(currency.key)_24h_change"] ?? nil
            )
        }
        data = result
    }
}

struct CoingeckoSingleCurrencyPriceData: Equatable {
    let price: Decimal
    let dayChange: Decimal?
}
