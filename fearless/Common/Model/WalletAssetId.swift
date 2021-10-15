import Foundation

enum WalletAssetId: String {
    case dot
    case kusama
    case westend
    case usd
    case roc
    case monbaseAlpha
    case moonriver
}

// TODO: Extract url from chain
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
        } else if chainId == "91bc6e169807aaa54802737e1c504b2577d4fafedd5a02c10293b1cd60e39527" {
            self = .monbaseAlpha
        } else if chainId == "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b" {
            self = .moonriver
        } else {
            return nil
        }
    }
}
