import Foundation
import BigInt
import RobinHood

final class OperationDetailsInteractor: OperationDetailsBaseInteractor {
    override func setupPriceHistorySubscription() {
        let priceId = chainAsset.asset.priceId

        if let priceId = priceId {
            priceProviders[priceId] = subscribeToPriceHistory(
                for: priceId,
                currency: selectedCurrency
            )
        }

        if let utilityAssetPriceId = chainAsset.chain.utilityAsset()?.priceId,
           utilityAssetPriceId != priceId {
            priceProviders[utilityAssetPriceId] = subscribeToPriceHistory(
                for: utilityAssetPriceId,
                currency: selectedCurrency
            )
        }
    }
}
