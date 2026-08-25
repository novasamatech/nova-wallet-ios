import Foundation

extension AssetModel {
    var hasStaking: Bool {
        stakings?.contains { $0 != .unsupported } ?? false
    }

    var hasPoolStaking: Bool {
        stakings?.contains(.nominationPools) ?? false
    }

    var hasMythosStaking: Bool {
        stakings?.contains(.mythos) ?? false
    }

    var hasSubtensorStaking: Bool {
        stakings?.contains(.subtensor) ?? false
    }

    var supportedStakings: [StakingType]? {
        stakings?.filter { $0 != .unsupported }
    }

    var hasMultipleStakingOptions: Bool {
        (stakings ?? []).count > 1
    }
}
