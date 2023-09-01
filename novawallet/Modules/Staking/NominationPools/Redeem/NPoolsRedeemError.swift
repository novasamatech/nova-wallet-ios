import Foundation

enum NPoolsRedeemError: Error {
    case subscription(Error, String)
    case fee(Error)
}
