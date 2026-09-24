import Foundation
import NovaAnalytics

struct AnalyticsRampContent {
    let provider: AnalyticsContentValue
    let asset: AnalyticsContentValue
    let network: AnalyticsContentValue

    init?(providerId: String, chainAsset: ChainAsset) {
        guard
            let provider = AnalyticsContentValue.providerId(providerId),
            let chainAssetContent = AnalyticsChainAssetContent(chainAsset: chainAsset)
        else {
            return nil
        }

        self.provider = provider
        asset = chainAssetContent.asset
        network = chainAssetContent.network
    }
}
