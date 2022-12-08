import Foundation

protocol ChainModelConversionProtocol {
    func update(
        localModel: ChainModel?,
        remoteModel: RemoteChainModel,
        additionalAssets: [RemoteAssetModel],
        order: Int64
    ) -> ChainModel?
}

final class ChainModelConverter: ChainModelConversionProtocol {
    func update(
        localModel: ChainModel?,
        remoteModel: RemoteChainModel,
        additionalAssets: [RemoteAssetModel],
        order: Int64
    ) -> ChainModel? {
        let localUserAssets = localModel?.assets.filter { $0.source == .user } ?? []

        let localAssets = localModel?.assets.reduce(into: [AssetModel.Id: AssetModel]()) { accum, asset in
            accum[asset.assetId] = asset
        }

        let remoteAssets = remoteModel.assets + additionalAssets
        let chainAssets = remoteAssets.map { remoteAsset in
            if let localAsset = localAssets?[remoteAsset.assetId] {
                return AssetModel(remoteModel: remoteAsset, enabled: localAsset.enabled)
            } else {
                return AssetModel(remoteModel: remoteAsset, enabled: true)
            }
        }

        let newAssets = Set(chainAssets).union(localUserAssets)
        let newChainModel = ChainModel(remoteModel: remoteModel, assets: newAssets, order: order)

        return newChainModel != localModel ? newChainModel : nil
    }
}
