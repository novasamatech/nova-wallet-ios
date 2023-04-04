import Foundation
import RobinHood

extension Array where Element == DataProviderChange<PriceData> {
    func reduce(
        using initMapping: [ChainAssetId: DataProviderChange<PriceData>],
        availableTokenPrice: [ChainAssetId: AssetModel.PriceId],
        currency: Currency
    ) -> [ChainAssetId: DataProviderChange<PriceData>] {
        reduce(into: initMapping) { accum, change in
            let targetIdentifier: String

            switch change {
            case let .insert(newItem), let .update(newItem):
                targetIdentifier = newItem.identifier

            case let .delete(identifier):
                targetIdentifier = identifier
            }

            let chainAssetIds: [ChainAssetId] = availableTokenPrice.filter {
                PriceData.createIdentifier(for: $0.value, currencyId: currency.id) == targetIdentifier
            }.map(\.key)

            for chainAssetId in chainAssetIds {
                accum[chainAssetId] = change
            }
        }
    }
}
