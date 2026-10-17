import Foundation
import Operation_iOS

final class SubtensorSubnetMarketsService {
    static let category = "bittensor-subnets"

    let coingeckoOperationFactory: CoingeckoOperationFactoryProtocol

    init(coingeckoOperationFactory: CoingeckoOperationFactoryProtocol) {
        self.coingeckoOperationFactory = coingeckoOperationFactory
    }
}

extension SubtensorSubnetMarketsService: SubtensorSubnetMarketsServiceProtocol {
    func createMarketsWrapper() -> CompoundOperationWrapper<SubtensorSubnetMarkets> {
        let fetchOperation = coingeckoOperationFactory.fetchMarkets(category: Self.category, currency: .usd)

        return CompoundOperationWrapper(targetOperation: fetchOperation).mapped { data in
            let markets = try JSONDecoder().decode(SubtensorSubnetMarkets.self, from: data)

            guard !markets.byNetuid.isEmpty else {
                throw CommonError.dataCorruption
            }

            return markets
        }
    }
}
