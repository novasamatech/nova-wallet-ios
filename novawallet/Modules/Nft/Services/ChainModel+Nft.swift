import Foundation

extension ChainModel {
    var nftSources: [NftSource] {
        switch chainId {
        case KnowChainId.kusama:
            return [NftSource(chainId: chainId, type: .rmrkV2)]
        case KnowChainId.kusamaAssetHub:
            return [
                NftSource(chainId: chainId, type: .kodadot)
            ]
        case KnowChainId.polkadot:
            return [NftSource(chainId: chainId, type: .pdc20)]
        case KnowChainId.polkadotAssetHub:
            return [NftSource(chainId: chainId, type: .kodadot)]
        case KnowChainId.unique:
            return [NftSource(chainId: chainId, type: .unique)]
        default:
            return []
        }
    }
}
