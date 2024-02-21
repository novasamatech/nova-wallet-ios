import Foundation

extension ChainModel {
    var nftSources: [NftSource] {
        switch chainId {
        case KnowChainId.kusama:
            return [NftSource(chainId: chainId, type: .rmrkV2)]
        case KnowChainId.statemine:
            return [
                NftSource(chainId: chainId, type: .kodadot)
            ]
        case KnowChainId.polkadot:
            return [NftSource(chainId: chainId, type: .pdc20)]
        case KnowChainId.statemint:
            return [NftSource(chainId: chainId, type: .kodadot)]
        default:
            return []
        }
    }
}
