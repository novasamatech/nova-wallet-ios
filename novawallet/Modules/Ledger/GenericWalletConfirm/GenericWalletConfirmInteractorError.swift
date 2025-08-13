import Foundation

enum GenericWalletConfirmInteractorError: Error {
    case fetchAccount(Error)
    case confirmAccount(Error)
}
