import Foundation

enum NPoolsRedeemError: Error {
    case subscription(Error, String)
    case existentialDeposit(Error)
    case fee(Error)
}
