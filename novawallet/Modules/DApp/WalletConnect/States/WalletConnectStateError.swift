import Foundation

enum WalletConnectStateError: Error {
    case unexpectedMessage(Any, WalletConnectStateProtocol)
}
