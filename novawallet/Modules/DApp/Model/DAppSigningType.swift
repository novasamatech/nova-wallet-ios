import Foundation

enum DAppSigningType {
    case extrinsic(chain: ChainModel)
    case bytes(chain: ChainModel)
    case ethereumTransaction(chain: MetamaskChain)
    case ethereumBytes(chain: MetamaskChain, accountId: AccountId)

    var msgType: PolkadotExtensionMessage.MessageType? {
        switch self {
        case .extrinsic:
            return .signExtrinsic
        case .bytes:
            return .signBytes
        case .ethereumTransaction, .ethereumBytes:
            return nil
        }
    }
}
