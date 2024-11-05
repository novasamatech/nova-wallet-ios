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

    init(model: AssetsExchangeGraphModel) {
        self.model = model
    }
}

extension AssetsExchangeGraph: AssetsExchangeGraphProtocol {
    func fetchPaths(
        from assetIn: ChainAssetId,
        to assetOut: ChainAssetId,
        maxTopPaths: Int
    ) -> [AssetExchangeGraphPath] {
        // TODO: replace with real filter
        model.calculateShortestPath(from: assetIn, nodeEnd: assetOut, topN: maxTopPaths, filter: .allEdges())
    }

    func fetchReachability() -> AssetsExchageGraphReachabilityProtocol {
        let allNodes = model.connections.keys

        let mapping = allNodes.reduce(into: [ChainAssetId: Set<ChainAssetId>]()) { accum, assetIn in
            // TODO: replace with real filter
            accum[assetIn] = model.calculateReachableNodes(for: assetIn, filter: .allEdges())
        }

        return AssetsExchageGraphReachability(mapping: mapping)
    }
}
