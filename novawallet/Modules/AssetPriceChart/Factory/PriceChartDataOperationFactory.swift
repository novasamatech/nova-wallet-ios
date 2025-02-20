import Foundation
import Operation_iOS

protocol PriceChartDataOperationFactoryProtocol {
    func createWrapper(
        tokenId: String,
        currency: Currency
    ) -> CompoundOperationWrapper<[PriceHistoryPeriod: [PriceHistoryItem]]>
}

class PriceChartDataOperationFactory {
    let fetchOperationFactory: CoingeckoOperationFactoryProtocol

    init(fetchOperationFactory: CoingeckoOperationFactoryProtocol) {
        self.fetchOperationFactory = fetchOperationFactory
    }
}

// MARK: Private

private extension PriceChartDataOperationFactory {}

// MARK: PriceChartDataOperationFactoryProtocol

extension PriceChartDataOperationFactory: PriceChartDataOperationFactoryProtocol {
    func createWrapper(
        tokenId: String,
        currency: Currency
    ) -> CompoundOperationWrapper<[PriceHistoryPeriod : [PriceHistoryItem]]> {
        <#code#>
    }
}
