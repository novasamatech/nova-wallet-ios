import Foundation
import NovaAnalytics

extension MainTabBarIndex {
    static func analyticsTab(for index: Int, moreItem: MainTabBarMoreItem?) -> AnalyticsTab? {
        switch index {
        case MainTabBarIndex.wallet:
            return .assets
        case MainTabBarIndex.dapps:
            return .dapps
        case MainTabBarIndex.swaps:
            return .swaps
        case MainTabBarIndex.staking:
            return .staking
        case MainTabBarIndex.more:
            return moreItem?.analyticsTab
        default:
            return nil
        }
    }

    static func analyticsFeature(for index: Int, moreItem: MainTabBarMoreItem?) -> FeatureId? {
        switch index {
        case MainTabBarIndex.dapps:
            return .dapps
        case MainTabBarIndex.staking:
            return .staking
        case MainTabBarIndex.more:
            return moreItem?.analyticsFeature
        default:
            return nil
        }
    }
}

private extension MainTabBarMoreItem {
    var analyticsTab: AnalyticsTab {
        switch self {
        case .governance:
            return .vote
        case .settings:
            return .settings
        }
    }

    var analyticsFeature: FeatureId? {
        switch self {
        case .governance:
            return nil
        case .settings:
            return .settings
        }
    }
}
