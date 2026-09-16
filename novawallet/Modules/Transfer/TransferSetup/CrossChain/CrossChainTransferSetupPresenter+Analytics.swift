import Foundation
import NovaAnalytics

extension CrossChainTransferSetupPresenter: AnalyticsTracking {
    var analyticsIsCrossChain: Bool {
        originChainAsset.chain.chainId != destinationChainAsset.chain.chainId
    }

    var analyticsDestinationNetwork: AnalyticsContentValue? {
        analyticsIsCrossChain ? destinationChainAsset.analyticsNetworkName : nil
    }

    func trackSendInitiated(amount: Decimal) {
        guard analyticsFlow.tracksSendFunnel else {
            return
        }

        let event: AnalyticsEvent? = AnalyticsChainAssetContent(chainAsset: originChainAsset).map { content in
            .sendInitiated(
                asset: content.asset,
                network: content.network,
                destinationNetwork: analyticsDestinationNetwork,
                amount: amount,
                rate: sendingAssetPrice?.analyticsRate,
                isCrossChain: analyticsIsCrossChain
            )
        }

        trackAnalytics(event)
    }
}
