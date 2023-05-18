import Foundation
import IrohaCrypto

struct CoingeckoAPI {
    static let baseURL = URL(string: "https://api.coingecko.com/api/v3")!
    static let price = "simple/price"

    static func priceHistory(for tokenId: String) -> String {
        "coins/\(tokenId)/market_chart/range"
    }
}
