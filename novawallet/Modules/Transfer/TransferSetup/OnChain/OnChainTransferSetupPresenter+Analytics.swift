import Foundation
import NovaAnalytics

extension OnChainTransferSetupPresenter: AnalyticsTracking {
    func trackSendInitiated(amount: Decimal) {
        guard analyticsFlow.tracksSendFunnel else {
            return
        }

        let event: AnalyticsEvent? = AnalyticsChainAssetContent(chainAsset: chainAsset).map { content in
            .sendInitiated(
                asset: content.asset,
                network: content.network,
                destinationNetwork: nil,
                amount: amount,
                rate: sendingAssetPrice?.analyticsRate,
                isCrossChain: false
            )
        }

        trackAnalytics(event)
    }
}
