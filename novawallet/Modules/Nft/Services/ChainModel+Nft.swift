import Foundation

extension ChainModel {
    var nftSources: [NftSource] {
        switch chainId {
        case KnowChainId.kusama:
            return [
                NftSource(chainId: chainId, type: .rmrkV1),
                NftSource(chainId: chainId, type: .rmrkV2)
            ]
        case KnowChainId.statemine:
            return [NftSource(chainId: chainId, type: .uniques)]
        default:
            return []
        }
    }
}
