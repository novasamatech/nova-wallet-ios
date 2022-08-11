import Foundation
import CommonWallet

struct CoingeckoPriceData: Decodable, Equatable {
    typealias Currency = String
    let rates: [Currency: CoingeckoSingleCurrencyPriceData]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let currencyProperties = try container.decode([String: Decimal?].self)

        let currencies = currencyProperties.filter { $0.key.split(separator: Constants.separator).count == 1 }

        rates = currencies.reduce(into: [Currency: CoingeckoSingleCurrencyPriceData]()) { result, currency in
            guard let price = currency.value else {
                return
            }
            result[currency.key] = CoingeckoSingleCurrencyPriceData(
                price: price,
                dayChange: currencyProperties[Constants.dayChangeKey(currency.key)] ?? nil
            )
        }
    }
}

struct CoingeckoSingleCurrencyPriceData: Equatable {
    let price: Decimal
    let dayChange: Decimal?
}

extension CoingeckoPriceData {
    enum Constants {
        static let separator = Character("_")
        static let dayChangeKey: (String) -> String = {
            [$0, "24h", "change"].joined(separator: String(Constants.separator))
        }
    }
}
