import Foundation

protocol AssetsExchageGraphReachabilityProtocol {
    func getAllAssetIn() -> Set<ChainAssetId>
    func getAllAssetOut() -> Set<ChainAssetId>
    func getAssetsIn(for assetOut: ChainAssetId) -> Set<ChainAssetId>
    func getAssetsOut(for assetIn: ChainAssetId) -> Set<ChainAssetId>
}

final class AssetsExchageGraphReachability {
    let mapping: [ChainAssetId: Set<ChainAssetId>]
    
    init(mapping: [ChainAssetId: Set<ChainAssetId>]) {
        self.mapping = mapping
    }
}

extension AssetsExchangeGraphReachability: AssetsExchageGraphReachabilityProtocol {
    func getAllAssetIn() -> Set<ChainAssetId> {
        Set(mapping.keys)
    }
    
    func getAllAssetOut() -> Set<ChainAssetId> {
        mapping.values.reduce(into: Set<ChainAssetId>()) { accum, assets in
            accum.union(assets)
        }
    }
    
    func getAssetsIn(for assetOut: ChainAssetId) -> Set<ChainAssetId> {
        let assetsIn = mapping.filter(\.value.contains(assetOut)).keys
        return Set(assetsIn)
    }
    
    func getAssetsOut(for assetIn: ChainAssetId) -> Set<ChainAssetId> {
        mapping[assetIn] ?? []
    }
}
