import Foundation
import BigInt
import RobinHood

final class OperationSwapDetailsInteractor: OperationDetailsBaseInteractor {
    override func setupPriceHistorySubscription() {
        guard let swap = transaction.swap else {
            return
        }
        let priceAssetIn = chain.assetOrNil(for: swap.assetIdIn)?.priceId
        let priceAssetOut = chain.assetOrNil(for: swap.assetIdOut)?.priceId
        let feePriceId = chain.assetOrNative(for: transaction.feeAssetId)?.priceId
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
