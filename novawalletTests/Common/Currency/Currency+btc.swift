@testable import novawallet

extension Currency {
    static let btc = Currency(
        id: 10,
        code: "BTC",
        name: "Bitcoin",
        symbol: nil,
        category: .crypto,
        isPopular: true,
        coingeckoId: "btc"
    )
}
