import Foundation

enum NPoolsClaimRewardsError: Error {
    case subscription(Error, String)
    case fee(Error)
}
