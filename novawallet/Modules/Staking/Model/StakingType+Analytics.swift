import Foundation
import NovaAnalytics

extension StakingType {
    var analyticsType: StakingAnalyticsType {
        switch self {
        case .relaychain, .auraRelaychain, .azero, .parachain, .turing:
            return .direct
        case .nominationPools:
            return .pool
        case .mythos:
            return .mythos
        case .unsupported:
            return .unsupported
        }
    }
}
