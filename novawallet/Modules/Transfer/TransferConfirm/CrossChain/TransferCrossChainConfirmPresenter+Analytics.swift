import Foundation
import NovaAnalytics

extension TransferCrossChainConfirmPresenter: AnalyticsTracking {
    var analyticsIsCrossChain: Bool {
        originChainAsset.chain.chainId != destinationChainAsset.chain.chainId
    }

    var analyticsDestinationNetwork: AnalyticsContentValue? {
        analyticsIsCrossChain ? destinationChainAsset.analyticsNetworkName : nil
    }

    func trackSendCompleted() {
        guard analyticsFlow.tracksSendFunnel else {
            return
        }

        let event: AnalyticsEvent? = AnalyticsChainAssetContent(chainAsset: originChainAsset).map { content in
            .sendCompleted(
                asset: content.asset,
                network: content.network,
                destinationNetwork: analyticsDestinationNetwork,
                amount: amount,
                rate: sendingAssetPrice?.analyticsRate
            )
        }

        trackAnalytics(event)
    }

    func trackSendFailed(error: Error) {
        guard analyticsFlow.tracksSendFunnel else {
            return
        }

        let event: AnalyticsEvent? = AnalyticsChainAssetContent(chainAsset: originChainAsset).map { content in
            .sendFailed(
                asset: content.asset,
                network: content.network,
                destinationNetwork: analyticsDestinationNetwork,
                reason: error.analyticsTransactionFailureReason
            )
        }

        trackAnalytics(event)
    }
}
