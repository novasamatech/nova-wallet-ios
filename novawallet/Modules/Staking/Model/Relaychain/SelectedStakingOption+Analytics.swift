import Foundation
import NovaAnalytics

extension SelectedStakingOption {
    var analyticsType: StakingAnalyticsType {
        switch self {
        case .direct:
            return StakingType.relaychain.analyticsType
        case .pool:
            return StakingType.nominationPools.analyticsType
        }
    }
}
