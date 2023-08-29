import Foundation

enum NPoolsUnstakeBaseError: Error {
    case subscription(Error, String)
    case stakingDuration(Error)
    case eraCountdown(Error)
    case claimableRewards(Error)
    case unstakeLimits(Error)
    case fee(Error)
}
