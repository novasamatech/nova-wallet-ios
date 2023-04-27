import Foundation

enum WalletConnectTransportError: Error {
    case stateFailed(WalletConnectStateError)
    case serviceFailed(WalletConnectServiceError)
}
