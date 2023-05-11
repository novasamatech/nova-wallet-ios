import Foundation

enum WalletConnectSessionsInteractorError: Error {
    case sessionsFetchFailed(Error)
    case connectionFailed(Error)
}
