import Foundation
@testable import fearless

final class PriceProviderFactoryStub: PriceProviderFactoryProtocol {
    let priceData: PriceData?

    init(priceData: PriceData? = nil) {
        self.priceData = priceData
    }

    func getPriceProvider(for priceId: AssetModel.PriceId) -> AnySingleValueProvider<PriceData> {
        let provider = SingleValueProviderStub(item: priceData)
        return AnySingleValueProvider(provider)
    }

    func getPriceListProvider(for priceIds: [AssetModel.PriceId]) -> AnySingleValueProvider<[PriceData]> {
        let priceList = priceData.map { [$0] } ?? []
        let provider = SingleValueProviderStub(item: priceList)
        return AnySingleValueProvider(provider)
    }
}
