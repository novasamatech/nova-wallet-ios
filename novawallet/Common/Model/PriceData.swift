import Foundation

struct PriceData: Codable, Equatable {
    let price: String
    let usdDayChange: Decimal?
}

extension PriceData {
    static var zero: PriceData {
        PriceData(price: "0", usdDayChange: nil)
    }
}
