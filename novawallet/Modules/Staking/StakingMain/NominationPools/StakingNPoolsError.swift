import Foundation

enum StakingNPoolsError: Error {
    case stateSetup(Error)
    case subscription(Error, String)
    case totalActiveStake(Error)
    case stakingDuration(Error)
    case activePools(Error)
    case eraCountdown(Error)
    case claimableRewards(Error)
    case totalRewards(Error)
}
