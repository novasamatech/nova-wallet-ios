import Foundation

typealias AssetsExchangeGraphModel = GraphModel<ChainAssetId, AnyAssetExchangeEdge>

protocol AssetsExchangeGraphProtocol {
    func fetchPaths(
        from assetIn: ChainAssetId,
        to assetOut: ChainAssetId,
        maxTopPaths: Int
    ) -> [AssetExchangeGraphPath]
    
    func fetchReachbility() -> AssetsExchageGraphReachabilityProtocol
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
        model.calculateShortestPath(from: assetIn, nodeEnd: assetOut, topN: maxTopPaths)
    }
    
    func fetchReachability() -> AssetsExchageGraphReachabilityProtocol {
        let allNodes = model.connections.keys
        
        let mapping = allNodes.reduce(into: [ChainAssetId: Set<ChainAssetId>]()) { accum, assetIn in
            accum[assetIn] = model.reachableNodes(for: assetIn)
        }
        
        return AssetsExchageGraphReachability(mapping: mapping)
    }
}