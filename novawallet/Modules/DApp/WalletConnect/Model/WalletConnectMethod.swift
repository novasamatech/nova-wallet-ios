import Foundation

enum WalletConnectMethod: String {
    case polkadotSignTransaction = "polkadot_signTransaction"
    case polkadotSignMessage = "polkadot_signMessage"
    case ethSignTransaction = "eth_signTransaction"
    case ethSendTransaction = "eth_sendTransaction"
    case ethPersonalSign = "personal_sign"
    case ethSignTypeData = "eth_signTypedData"
}
