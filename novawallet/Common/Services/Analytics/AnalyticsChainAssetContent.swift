import Foundation
import NovaAnalytics

struct AnalyticsChainAssetContent {
    let asset: AnalyticsContentValue
    let network: AnalyticsContentValue

    init?(chainAsset: ChainAsset) {
        guard
            let asset = chainAsset.analyticsAssetSymbol,
            let network = chainAsset.analyticsNetworkName else {
            return nil
        }

        self.asset = asset
        self.network = network
    }
}
