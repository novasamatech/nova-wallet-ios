import Foundation
import NovaAnalytics

extension MainTabBarIndex {
    static func analyticsTab(for index: Int) -> AnalyticsTab? {
        switch index {
        case MainTabBarIndex.wallet:
            return .assets
        case MainTabBarIndex.vote:
            return .vote
        case MainTabBarIndex.dapps:
            return .dapps
        case MainTabBarIndex.staking:
            return .staking
        case MainTabBarIndex.settings:
            return .settings
        default:
            return nil
        }
    }

    static func analyticsFeature(for index: Int) -> FeatureId? {
        switch index {
        case MainTabBarIndex.dapps:
            return .dapps
        case MainTabBarIndex.staking:
            return .staking
        case MainTabBarIndex.settings:
            return .settings
        default:
            return nil
        }
    }
}
