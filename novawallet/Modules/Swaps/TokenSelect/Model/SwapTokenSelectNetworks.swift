import Foundation

enum SwapTokenSelectQuickNetworks {
    static let chainIds: [ChainModel.Id] = [
        KnowChainId.polkadotAssetHub,
        KnowChainId.hydra,
        KnowChainId.bittensor,
        KnowChainId.ethereum,
        KnowChainId.mythos,
        KnowChainId.astar
    ]
}

struct SwapTokenSelectChipRow {
    let networks: [ChainModel]
    let remainingCount: Int
}

enum SwapTokenSelectNetworksArranger {
    static func chipRow(
        from networks: [ChainModel],
        savedNetworks: [ChainModel.Id]
    ) -> SwapTokenSelectChipRow {
        let networksById = networks.reduce(into: [ChainModel.Id: ChainModel]()) { $0[$1.chainId] = $1 }

        var chipIds: [ChainModel.Id] = []

        for chainId in SwapTokenSelectQuickNetworks.chainIds + savedNetworks
            where networksById[chainId] != nil && !chipIds.contains(chainId) {
            chipIds.append(chainId)
        }

        return SwapTokenSelectChipRow(
            networks: chipIds.compactMap { networksById[$0] },
            remainingCount: networks.count - chipIds.count
        )
    }

    static func sheetSelection(
        savedNetworks: [ChainModel.Id],
        selectedNetworks: Set<ChainModel.Id>
    ) -> Set<ChainModel.Id> {
        selectedNetworks.union(savedNetworks.filter { !isQuick($0) })
    }

    static func savedNetworks(
        ticked tickedNetworks: [ChainModel.Id],
        shown shownNetworks: Set<ChainModel.Id>,
        previouslySaved savedNetworks: [ChainModel.Id]
    ) -> [ChainModel.Id] {
        let unshownNetworks = savedNetworks.filter { !shownNetworks.contains($0) }

        return (tickedNetworks + unshownNetworks).filter { !isQuick($0) }
    }

    static func sheetOrder(of networks: [ChainModel]) -> [ChainModel] {
        let quickIds = SwapTokenSelectQuickNetworks.chainIds

        let quickNetworks = quickIds.compactMap { chainId in
            networks.first { $0.chainId == chainId }
        }

        return quickNetworks + networks.filter { !quickIds.contains($0.chainId) }
    }
}

private extension SwapTokenSelectNetworksArranger {
    static func isQuick(_ chainId: ChainModel.Id) -> Bool {
        SwapTokenSelectQuickNetworks.chainIds.contains(chainId)
    }
}
