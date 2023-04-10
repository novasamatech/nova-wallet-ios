typealias Slip44CoinList = [Slip44Coin]

struct Slip44Coin: Codable, Equatable {
    let index: String
    let symbol: String
}
