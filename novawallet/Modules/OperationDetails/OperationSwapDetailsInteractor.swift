import Foundation
import BigInt
import RobinHood

final class OperationSwapDetailsInteractor: OperationDetailsBaseInteractor {
    override func setupPriceHistorySubscription() {
        guard let swap = transaction.swap else {
            return
        }
        let priceAssetIn = chain.asset(byHistoryAssetId: swap.assetIdIn)?.priceId
        let priceAssetOut = chain.asset(byHistoryAssetId: swap.assetIdOut)?.priceId
        let feeAsset = chain.asset(byHistoryAssetId: transaction.feeAssetId) ?? chain.utilityAsset()
        let feePriceId = feeAsset?.priceId
        let prices = [
            priceAssetIn,
            priceAssetOut,
            feePriceId
        ].compactMap { $0 }
        Set(prices).forEach {
            priceProviders[$0] = subscribeToPriceHistory(for: $0, currency: selectedCurrency)
        }
    }
}
