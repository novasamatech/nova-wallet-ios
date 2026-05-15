import Foundation

enum SelectedStakingOption: Equatable {
    case direct(PreparedValidators)
    case pool(NominationPools.PreparedPool)

    var maxApy: Decimal? {
        switch self {
        case let .direct(preparedValidators):
            return preparedValidators.targets
                .map(\.stakeReturn)
                .max()
        case let .pool(preparedPool):
            return preparedPool.selectedPool.maxApy
        }
    }
}
