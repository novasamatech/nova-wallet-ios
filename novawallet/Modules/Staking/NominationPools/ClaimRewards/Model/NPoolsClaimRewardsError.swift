import Foundation

enum NPoolsClaimRewardsError: Error {
    case subscription(Error, String)
    case existentialDeposit(Error)
    case fee(Error)
}
