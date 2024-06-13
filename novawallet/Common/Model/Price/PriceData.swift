import Foundation
import Operation_iOS

struct PriceData: Codable, Equatable, Identifiable {
    let identifier: String
    let price: String
    let dayChange: Decimal?
    let currencyId: Int? // nil if selected currency id should be used
}

extension PriceData {
    static func createIdentifier(for priceId: String, currencyId: Int) -> String {
        priceId + "-" + "\(currencyId)"
    }

    static func zero(for identifier: String = "", currencyId: Int? = nil) -> PriceData {
        PriceData(identifier: identifier, price: "0", dayChange: nil, currencyId: currencyId)
    }

    static func amount(_ value: Decimal, identifier: String = "", currencyId: Int? = nil) -> PriceData {
        PriceData(
            identifier: identifier,
            price: value.stringWithPointSeparator,
            dayChange: nil,
            currencyId: currencyId
        )
    }

    var decimalRate: Decimal? {
        Decimal(string: price)
    }
}
