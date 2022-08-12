import Foundation

struct PriceData: Codable, Equatable {
    let price: String
    let dayChange: Decimal?
    let currencyId: Int
}

extension PriceData {
    static var zero: PriceData {
        PriceData(price: "0", dayChange: nil, currencyId: 0)
    }
}
