typealias Slip44CoinList = [Slip44Coin]

struct Slip44Coin: Codable, Equatable {
    let index: String
    let symbol: String
}

extension Slip44CoinList {
    func matchFirstCaip19(of symbols: [String]) -> Caip19.RegisteredToken? {
        first { coin in
            symbols.contains { $0.caseInsensitiveCompare(coin.symbol) == .orderedSame }
        }
        .flatMap { coin in
            guard let index = Caip19.Slip44CoinIndex(coin.index) else {
                return nil
            }

            return .slip44(coin: index)
        }
    }
}
