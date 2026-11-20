import Foundation
import NovaAnalytics

extension ChainModel {
    var analyticsNetworkName: AnalyticsContentValue? {
        .networkName(name)
    }

    var analyticsChainId: AnalyticsContentValue? {
        .chainId(chainId)
    }
}

extension ChainAsset {
    var analyticsAssetSymbol: AnalyticsContentValue? {
        .assetSymbol(asset.symbol)
    }

    var analyticsNetworkName: AnalyticsContentValue? {
        chain.analyticsNetworkName
    }
}
