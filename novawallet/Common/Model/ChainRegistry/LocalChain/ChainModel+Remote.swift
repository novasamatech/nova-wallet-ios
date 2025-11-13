import Foundation

extension ChainModel {
    init(
        remoteModel: RemoteChainModel,
        assets: Set<AssetModel>,
        nodes: Set<ChainNodeModel>,
        syncMode: ChainSyncMode,
        order: Int64,
        connectionMode: ConnectionMode,
        displayPriority: UInt8?
    ) {
        chainId = remoteModel.chainId
        parentId = remoteModel.parentId
        name = remoteModel.name
        self.assets = assets
        self.syncMode = syncMode
        self.nodes = nodes

        nodeSwitchStrategy = .init(rawStrategy: remoteModel.nodeSelectionStrategy)

        addressPrefix = remoteModel.addressPrefix
        legacyAddressPrefix = remoteModel.legacyAddressPrefix
        types = remoteModel.types
        icon = remoteModel.icon

        let remoteOptions = remoteModel.options?.compactMap { LocalChainOptions(rawValue: $0) } ?? []
        options = !remoteOptions.isEmpty ? remoteOptions : nil

        externalApis = remoteModel.externalApi.map { LocalChainExternalApiSet(remoteApi: $0) }
        explorers = remoteModel.explorers
        additional = remoteModel.additional

        self.order = order
        source = .remote
        self.connectionMode = connectionMode
        self.displayPriority = displayPriority
    }
}
