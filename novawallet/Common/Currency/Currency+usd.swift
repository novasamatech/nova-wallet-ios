import Foundation

extension Currency {
    static let usd = Currency(
        id: 0,
        code: "USD",
        name: "United States Dollar",
        symbol: "$",
        category: .fiat,
        isPopular: true,
        coingeckoId: "usd"
    )
}
