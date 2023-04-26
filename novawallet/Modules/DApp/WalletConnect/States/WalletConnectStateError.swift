import Foundation

enum WalletConnectStateError: Error {
    case unexpectedMessage(AnyObject, WalletConnectStateProtocol)
}
