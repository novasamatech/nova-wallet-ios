import Foundation

enum SelectedStakingOption {
    case direct(PreparedValidators)
    case pool(NominationPools.SelectedPool)

    var maxApy: Decimal? {
        switch self {
        case let .direct(preparedValidators):
            return preparedValidators.targets
                .map(\.stakeReturn)
                .max()
        case let .pool(selectedPool):
            return selectedPool.maxApy
        }
    }
}
