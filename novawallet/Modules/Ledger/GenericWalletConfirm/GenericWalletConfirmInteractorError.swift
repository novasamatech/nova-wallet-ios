import Foundation

enum GenericWalletConfirmInteractorError: Error {
    case fetAccount(Error)
    case confirmAccount(Error)
}
