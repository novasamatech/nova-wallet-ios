import Foundation
import NovaAnalytics

extension TransferOnChainConfirmPresenter: AnalyticsTracking {
    func trackSendCompleted() {
        guard analyticsFlow.tracksSendFunnel else {
            return
        }

        let event: AnalyticsEvent? = AnalyticsChainAssetContent(chainAsset: chainAsset).map { content in
            .sendCompleted(
                asset: content.asset,
                network: content.network,
                destinationNetwork: nil,
                amount: amount.value,
                rate: sendingAssetPrice?.analyticsRate
            )
        }

        trackAnalytics(event)
    }

    func trackSendFailed(error: Error) {
        guard analyticsFlow.tracksSendFunnel else {
            return
        }

        let event: AnalyticsEvent? = AnalyticsChainAssetContent(chainAsset: chainAsset).map { content in
            .sendFailed(
                asset: content.asset,
                network: content.network,
                destinationNetwork: nil,
                reason: error.analyticsTransactionFailureReason
            )
        }

        trackAnalytics(event)
    }
}
