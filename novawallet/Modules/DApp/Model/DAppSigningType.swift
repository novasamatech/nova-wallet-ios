import Foundation

enum DAppSigningType {
    case extrinsic(chain: ChainModel)
    case bytes(chain: ChainModel)
    case ethereumSendTransaction(chain: MetamaskChain)
    case ethereumSignTransaction(chain: MetamaskChain)
    case ethereumBytes(chain: MetamaskChain, accountId: AccountId)

    var msgType: PolkadotExtensionMessage.MessageType? {
        switch self {
        case .extrinsic:
            return .signExtrinsic
        case .bytes:
            return .signBytes
        case .ethereumSignTransaction, .ethereumSendTransaction, .ethereumBytes:
            return nil
        }
    }
}
