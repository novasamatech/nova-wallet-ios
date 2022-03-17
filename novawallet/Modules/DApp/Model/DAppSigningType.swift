import Foundation

enum DAppSigningType {
    case extrinsic(chain: ChainModel)
    case bytes(chain: ChainModel)
    case ethereumTransaction(chain: MetamaskChain)
    case rawExtrinsic(chain: ChainModel)

    var msgType: PolkadotExtensionMessage.MessageType? {
        switch self {
        case .extrinsic:
            return .signExtrinsic
        case .bytes:
            return .signBytes
        case .ethereumTransaction:
            return nil
        case .rawExtrinsic:
            return nil
        }
    }
}
