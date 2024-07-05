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

        let syncMode = determineSyncMode(basedOn: localModel, remoteModel: remoteModel)
        
        var customNodes: [ChainNodeModel] = []
        var customNodesUrlSet: Set<String> = []
        
        localModel?.nodes.forEach { node in
            guard node.source == .user else { return }
            
            customNodes.append(node)
            customNodesUrlSet.insert(node.url)
        }
        
        let remoteNodes = remoteModel.nodes
            .compactMap { node -> ChainNodeModel? in
                return if customNodesUrlSet.contains(node.url) {
                    nil
                } else {
                    ChainNodeModel(remoteModel: node, order: Int16(0))
                }
            }
        
        let orderedNodes = (remoteNodes + customNodes)
            .enumerated()
            .map { $0.element.updatingOrder(Int16($0.offset)) }

        let newChainModel = ChainModel(
            remoteModel: remoteModel,
            assets: newAssets,
            nodes: Set(orderedNodes),
            syncMode: syncMode,
            order: order,
            connectionMode: localModel?.connectionMode ?? .autoBalanced
        )

        return newChainModel != localModel ? newChainModel : nil
    }

    private func determineSyncMode(basedOn localModel: ChainModel?, remoteModel: RemoteChainModel) -> ChainSyncMode {
        // if a user disabled network then keep it as it is
        if let localModel = localModel, localModel.syncMode == .disabled {
            return .disabled
        }

        let shouldFullSync = remoteModel.options?.contains(RemoteOnlyChainOptions.fullSyncByDefault.rawValue) ?? false

        if shouldFullSync {
            return .full
        }

        let hasNoRuntime = remoteModel.options?.contains(LocalChainOptions.noSubstrateRuntime.rawValue) ?? false

        // no runtime (e.g. evm) networks always work in full sync
        if hasNoRuntime {
            return .full
        }

        return localModel?.syncMode ?? .light
    }
}
