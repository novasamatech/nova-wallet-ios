import Foundation

typealias AssetsExchangeGraphModel = GraphModel<ChainAssetId, AnyAssetExchangeEdge>

protocol AssetsExchangeGraphProtocol: AnyObject {
    func fetchPaths(
        from assetIn: ChainAssetId,
        to assetOut: ChainAssetId,
        maxTopPaths: Int
    ) -> [AssetExchangeGraphPath]

    func fetchReachability() -> AssetsExchageGraphReachabilityProtocol

    func fetchAssetsIn(given assetOutId: ChainAssetId?) -> Set<ChainAssetId>
    func fetchAssetsOut(given assetInId: ChainAssetId?) -> Set<ChainAssetId>
}

final class AssetsExchangeGraph {
    let model: AssetsExchangeGraphModel
    let filter: AnyGraphEdgeFilter<AnyAssetExchangeEdge>

    private var cachedReachability: AssetsExchageGraphReachabilityProtocol?

    init(model: AssetsExchangeGraphModel, filter: AnyGraphEdgeFilter<AnyAssetExchangeEdge>) {
        self.model = model
        self.filter = filter
    }
}

private extension AssetsExchangeGraph {
    func fetchReachabilityFromGraph() -> AssetsExchageGraphReachabilityProtocol {
        let allNodes = model.connections.keys

        let mapping = allNodes.reduce(into: [ChainAssetId: Set<ChainAssetId>]()) { accum, assetIn in
            accum[assetIn] = model.calculateReachableNodes(for: assetIn, filter: filter)
        }

        return AssetsExchageGraphReachability(mapping: mapping)
    }

    func fetchIfNeededAndCacheReachability() -> AssetsExchageGraphReachabilityProtocol {
        if let cachedReachability { return cachedReachability }

        let reachability = fetchReachabilityFromGraph()

        cachedReachability = reachability

        return reachability
    }
}

extension AssetsExchangeGraph: AssetsExchangeGraphProtocol {
    func fetchPaths(
        from assetIn: ChainAssetId,
        to assetOut: ChainAssetId,
        maxTopPaths: Int
    ) -> [AssetExchangeGraphPath] {
        model.calculateShortestPath(from: assetIn, nodeEnd: assetOut, topN: maxTopPaths, filter: filter)
    }

    func fetchReachability() -> AssetsExchageGraphReachabilityProtocol {
        fetchIfNeededAndCacheReachability()
    }

    func fetchAssetsIn(given assetOutId: ChainAssetId?) -> Set<ChainAssetId> {
        let allNodes = model.connections.keys

        guard let assetOutId else {
            return Set(allNodes)
        }

        let reachability = fetchIfNeededAndCacheReachability()

        return reachability.getAssetsIn(for: assetOutId)
    }

    func fetchAssetsOut(given assetInId: ChainAssetId?) -> Set<ChainAssetId> {
        if let assetInId {
            return model.calculateReachableNodes(for: assetInId, filter: filter)
        } else {
            let allDestinations = model.connections.values.flatMap { edges in
                edges.map(\.destination)
            }

            return Set(allDestinations)
        }
    }
}
