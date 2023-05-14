import Foundation

enum DAppSigningType {
    case extrinsic(chain: ChainModel)
    case bytes(chain: ChainModel)
    case ethereumSendTransaction(chain: DAppEitherChain)
    case ethereumSignTransaction(chain: DAppEitherChain)
    case ethereumBytes(chain: DAppEitherChain)

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
