import Foundation

extension ChainModel {
    var pdc20Network: String? {
        switch chainId {
        case KnowChainId.polkadot:
            return Pdc20Api.polkadotNetwork
        default:
            return nil
        }
    }
}
