import Foundation

typealias AssetsExchangeGraphModel = GraphModel<ChainAssetId, AnyAssetExchangeEdge>

protocol AssetsExchangeGraphProtocol {
    func fetchPaths(from origin: ChainAssetId, to destination: ChainAssetId) -> [[AnyAssetExchangeEdge]]
}

final class AssetsExchangeGraph {
    let model: AssetsExchangeGraphModel

    init(model: AssetsExchangeGraphModel) {
        self.model = model
    }
}

extension AssetsExchangeGraph: AssetsExchangeGraphProtocol {
    func fetchPaths(from origin: ChainAssetId, to destination: ChainAssetId) -> [[AnyAssetExchangeEdge]] {
        model.calculateShortestPath(from: origin, nodeEnd: destination, topN: 4)
    }
}
