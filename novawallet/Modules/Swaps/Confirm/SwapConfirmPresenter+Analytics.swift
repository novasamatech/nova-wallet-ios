import Foundation
import NovaAnalytics

extension SwapConfirmPresenter: AnalyticsTracking {
    func trackSwapConfirmed() {
        guard
            let quote,
            let payContent = AnalyticsChainAssetContent(chainAsset: initState.chainAssetIn),
            let receiveContent = AnalyticsChainAssetContent(chainAsset: initState.chainAssetOut),
            let slippageFraction = initState.slippage.decimalValue else {
            return
        }

        trackAnalytics(
            AnalyticsEvent.swapConfirmed(
                assetIn: payContent.asset,
                assetOut: receiveContent.asset,
                networkIn: payContent.network,
                networkOut: receiveContent.network,
                amount: quote.route.amountIn.decimal(precision: initState.chainAssetIn.asset.precision),
                price: payAssetPriceData?.analyticsRate,
                slippage: slippageFraction * 100
            )
        )
    }

    func trackSwapCompleted() {
        guard
            let confirmedAt,
            let quote,
            let payContent = AnalyticsChainAssetContent(chainAsset: initState.chainAssetIn),
            let receiveContent = AnalyticsChainAssetContent(chainAsset: initState.chainAssetOut) else {
            return
        }

        trackAnalytics(
            AnalyticsEvent.swapCompleted(
                assetIn: payContent.asset,
                assetOut: receiveContent.asset,
                networkIn: payContent.network,
                networkOut: receiveContent.network,
                amount: quote.route.amountIn.decimal(precision: initState.chainAssetIn.asset.precision),
                price: payAssetPriceData?.analyticsRate,
                duration: Date().timeIntervalSince(confirmedAt)
            )
        )
    }
}
