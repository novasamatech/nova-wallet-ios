import Foundation

protocol AssetsExchageGraphReachabilityProtocol {
    var isEmpty: Bool { get }

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

extension AssetsExchageGraphReachability: AssetsExchageGraphReachabilityProtocol {
    var isEmpty: Bool {
        mapping.isEmpty
    }

    func getAllAssetIn() -> Set<ChainAssetId> {
        Set(mapping.keys)
    }

    func getAllAssetOut() -> Set<ChainAssetId> {
        mapping.values.reduce(Set<ChainAssetId>()) { accum, assets in
            accum.union(assets)
        }
    }

    func getAssetsIn(for assetOut: ChainAssetId) -> Set<ChainAssetId> {
        let assetsIn = mapping.filter { $0.value.contains(assetOut) }.keys
        return Set(assetsIn)
    }

    func getAssetsOut(for assetIn: ChainAssetId) -> Set<ChainAssetId> {
        mapping[assetIn] ?? []
    }
}
