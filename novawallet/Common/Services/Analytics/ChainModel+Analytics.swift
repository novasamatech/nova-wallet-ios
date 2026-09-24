import Foundation
import NovaAnalytics

extension ChainModel {
    var analyticsNetworkName: AnalyticsContentValue? {
        .networkName(name)
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
