import Foundation
import NovaAnalytics

extension GetTokenOptionsPresenter: AnalyticsTracking {
    func trackChangeNowOpened() {
        guard
            let provider = AnalyticsContentValue.providerId(GetTokenOperation.changeNowName),
            let asset = destinationChainAsset.analyticsAssetSymbol,
            let chainId = destinationChainAsset.chain.analyticsChainId else {
            return
        }

        trackAnalytics(.assetFundingDappOpened(provider: provider, asset: asset, chainId: chainId))
    }
}
