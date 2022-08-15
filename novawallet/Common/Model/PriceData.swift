import Foundation

struct PriceData: Codable, Equatable {
    let price: String
    let dayChange: Decimal?
    let currencyId: Int? // nil if selected currency id should be used
}

extension PriceData {
    static func zero(for currencyId: Int? = nil) -> PriceData {
        PriceData(price: "0", dayChange: nil, currencyId: currencyId)
    }
}
