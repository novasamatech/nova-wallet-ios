import Foundation

enum StartStakingConfirmInteractorError: Error {
    case assetBalance(Error)
    case price(Error)
    case fee(Error)
    case confirmation(Error)
    case restrictions(Error)
}
