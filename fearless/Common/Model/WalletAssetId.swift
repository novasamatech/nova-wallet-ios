import Foundation

enum WalletAssetId: String {
    case dot
    case kusama
    case westend
    case usd
    case roc
}

extension WalletAssetId {
    init?(chainId: ChainModel.Id) {
        if chainId == Chain.polkadot.genesisHash {
            self = .dot
        } else if chainId == Chain.kusama.genesisHash {
            self = .kusama
        } else if chainId == Chain.westend.genesisHash {
            self = .westend
        } else if chainId == Chain.rococo.genesisHash {
            self = .roc
        } else {
            return nil
        }
    }
}
