import Foundation

enum WalletConnectSessionDetailsInteractorError: Error {
    case sessionUpdateFailed(Error)
    case disconnectionFailed(Error)
}
