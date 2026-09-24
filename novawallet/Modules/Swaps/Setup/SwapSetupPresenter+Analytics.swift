import Foundation
import NovaAnalytics

extension SwapSetupPresenter: AnalyticsTracking {
    func trackScreenOpened() {
        trackAnalytics(.swapScreenOpened(source: source))
        trackFeatureOpened(.swap)
    }

    func trackProceededToConfirmation(for swapModel: SwapModel, quote: AssetExchangeQuote) {
        abandonTracker.markProceeded()

        guard
            let payContent = AnalyticsChainAssetContent(chainAsset: swapModel.payChainAsset),
            let receiveContent = AnalyticsChainAssetContent(chainAsset: swapModel.receiveChainAsset) else {
            return
        }

        let amountIn = quote.route.amountIn.decimal(precision: swapModel.payChainAsset.asset.precision)

        trackAnalytics(
            AnalyticsEvent.swapInitiated(
                source: source,
                assetIn: payContent.asset,
                assetOut: receiveContent.asset,
                networkIn: payContent.network,
                networkOut: receiveContent.network,
                amount: amountIn,
                price: payAssetPriceData?.analyticsRate
            )
        )
    }
}
