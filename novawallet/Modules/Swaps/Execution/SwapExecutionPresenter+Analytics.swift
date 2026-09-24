import Foundation
import NovaAnalytics

extension SwapExecutionPresenter: AnalyticsTracking {
    func trackSwapCompleted() {
        guard
            let executionStartedAt,
            let payContent = AnalyticsChainAssetContent(chainAsset: chainAssetIn),
            let receiveContent = AnalyticsChainAssetContent(chainAsset: chainAssetOut) else {
            return
        }

        trackAnalytics(
            AnalyticsEvent.swapCompleted(
                assetIn: payContent.asset,
                assetOut: receiveContent.asset,
                networkIn: payContent.network,
                networkOut: receiveContent.network,
                amount: quote.route.amountIn.decimal(precision: chainAssetIn.asset.precision),
                price: payAssetPrice?.analyticsRate,
                duration: Date().timeIntervalSince(executionStartedAt)
            )
        )
    }
}
