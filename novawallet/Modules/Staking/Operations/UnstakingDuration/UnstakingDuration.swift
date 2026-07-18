import Foundation

struct UnstakingDuration {
    let validator: Staking.EraIndex
    let nominator: Staking.EraIndex
}

enum UnstakingDurationVariant {
    case full
    case nominator
}
