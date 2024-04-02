import Foundation

extension ChainModel {
    init(remoteModel: RemoteChainModel, assets: Set<AssetModel>, syncMode: ChainSyncMode, order: Int64) {
        chainId = remoteModel.chainId
        parentId = remoteModel.parentId
        name = remoteModel.name
        self.assets = assets
        self.syncMode = syncMode

        let nodeList = remoteModel.nodes.enumerated().map { index, node in
            ChainNodeModel(remoteModel: node, order: Int16(index))
        }

        nodes = Set(nodeList)

        nodeSwitchStrategy = .init(rawStrategy: remoteModel.nodeSelectionStrategy)

        addressPrefix = remoteModel.addressPrefix
        types = remoteModel.types
        icon = remoteModel.icon

        let remoteOptions = remoteModel.options?.compactMap { LocalChainOptions(rawValue: $0) } ?? []
        options = !remoteOptions.isEmpty ? remoteOptions : nil

        externalApis = remoteModel.externalApi.map { LocalChainExternalApiSet(remoteApi: $0) }
        explorers = remoteModel.explorers
        additional = remoteModel.additional

        self.order = order
    }
}
