import Foundation
import SubstrateSdk

struct CoingeckPriceHistoryData: Decodable {
    struct Item: Decodable {
        let time: UInt64
        let value: Decimal

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            time = try container.decode(UInt64.self)
            value = try container.decode(Decimal.self)
        }
    }

    let prices: [Item]
}
