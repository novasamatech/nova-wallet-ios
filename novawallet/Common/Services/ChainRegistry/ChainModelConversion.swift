import Foundation

protocol ChainModelConversionProtocol {
    func update(
        localModel: ChainModel?,
        remoteModel: RemoteChainModel,
        additionals: ChainModelConversionAdditionals
    ) -> ChainModel?
}

struct ChainModelConversionAdditionals {
    let assetDisplayPriorities: [AssetModel.Symbol: UInt16]
    let chainDisplayPriorities: [ChainModel.Id: UInt16]
    let additionalAssets: [RemoteAssetModel]
    let order: Int64
}

final class ChainModelConverter: ChainModelConversionProtocol {
    func update(
        localModel: ChainModel?,
        remoteModel: RemoteChainModel,
        additionals: ChainModelConversionAdditionals
    ) -> ChainModel? {
        let assetPriorities = additionals.assetDisplayPriorities
        let chainPriorities = additionals.chainDisplayPriorities
        
        let localUserAssets = localModel?.assets.filter { $0.source == .user } ?? []

        let localAssets = localModel?.assets.reduce(into: [AssetModel.Id: AssetModel]()) { accum, asset in
            accum[asset.assetId] = asset
        }

        let remoteAssets = remoteModel.assets + additionals.additionalAssets
        let chainAssets = remoteAssets.map { remoteAsset in
            if let localAsset = localAssets?[remoteAsset.assetId] {
                return AssetModel(remoteModel: remoteAsset, enabled: localAsset.enabled)
            } else {
                return AssetModel(remoteModel: remoteAsset, enabled: true)
            }
        }

        let newAssets = Set(chainAssets)
            .union(localUserAssets)
            .map { $0.byChanging(displayPriority: assetPriorities[$0.symbol]) }

        let syncMode = determineSyncMode(basedOn: localModel, remoteModel: remoteModel)

        var customNodes: [ChainNodeModel] = []
        var customNodesUrlSet: Set<String> = []

        localModel?.nodes.forEach { node in
            guard node.source == .user else { return }

            customNodes.append(node)
            customNodesUrlSet.insert(node.url)
        }

        let remoteNodes = remoteModel.nodes
            .filter { !customNodesUrlSet.contains($0.url) }
            .map { ChainNodeModel(remoteModel: $0, order: Int16(0)) }

        let orderedNodes = (remoteNodes + customNodes)
            .enumerated()
            .map { $0.element.updatingOrder(Int16($0.offset)) }

        let newChainModel = ChainModel(
            remoteModel: remoteModel,
            assets: Set(newAssets),
            nodes: Set(orderedNodes),
            syncMode: syncMode,
            order: additionals.order,
            connectionMode: localModel?.connectionMode ?? .autoBalanced,
            displayPriority: chainPriorities[remoteModel.chainId]
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
