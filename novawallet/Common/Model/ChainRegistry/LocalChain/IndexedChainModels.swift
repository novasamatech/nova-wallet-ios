import Foundation

typealias IndexedChainModels = [ChainModel.Id: ChainModel]

extension IndexedChainModels {
    func resolve(chainAssetId: ChainAssetId) -> ChainAsset? {
        self[chainAssetId.chainId]?.chainAsset(for: chainAssetId.assetId)
    }
}
