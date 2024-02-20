import Foundation

extension ChainModel {
    var nftSources: [NftSource] {
        switch chainId {
        case KnowChainId.kusama:
            return [NftSource(chainId: chainId, type: .rmrkV2)]
        case KnowChainId.statemine:
            return [NftSource(chainId: chainId, type: .uniques)]
        case KnowChainId.polkadot:
            return [NftSource(chainId: chainId, type: .pdc20)]
        default:
            return []
        }
    }
}
