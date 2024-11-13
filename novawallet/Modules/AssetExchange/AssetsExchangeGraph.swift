import Foundation

typealias AssetsExchangeGraphModel = GraphModel<ChainAssetId, AnyAssetExchangeEdge>

protocol AssetsExchangeGraphProtocol: AnyObject {
    func fetchPaths(
        from assetIn: ChainAssetId,
        to assetOut: ChainAssetId,
        maxTopPaths: Int
    ) -> [AssetExchangeGraphPath]

    func fetchReachability() -> AssetsExchageGraphReachabilityProtocol
}

final class AssetsExchangeGraph {
    let model: AssetsExchangeGraphModel
    let filter: AnyGraphEdgeFilter<AnyAssetExchangeEdge>

    init(model: AssetsExchangeGraphModel, filter: AnyGraphEdgeFilter<AnyAssetExchangeEdge>) {
        self.model = model
        self.filter = filter
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
        let allNodes = model.connections.keys

        let mapping = allNodes.reduce(into: [ChainAssetId: Set<ChainAssetId>]()) { accum, assetIn in
            accum[assetIn] = model.calculateReachableNodes(for: assetIn, filter: filter)
        }

        return AssetsExchageGraphReachability(mapping: mapping)
    }
}
