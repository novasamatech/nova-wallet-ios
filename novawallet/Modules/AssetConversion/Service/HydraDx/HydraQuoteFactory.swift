import Foundation
import RobinHood

protocol HydraQuoteFactoryProtocol {
    func quote(for args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetConversion.Quote>
}

final class HydraQuoteFactory {
    let chain: ChainModel
    let omnipoolTokensFactory: HydraOmnipoolTokensFactory
    let stableswapTokensFactory: HydraStableSwapsTokensFactory
    
    init(
        chain: ChainModel,
        omnipoolTokensFactory: HydraOmnipoolTokensFactory,
        stableswapTokensFactory: HydraStableSwapsTokensFactory
    ) {
        self.chain = chain
        self.omnipoolTokensFactory = omnipoolTokensFactory
        self.stableswapTokensFactory = stableswapTokensFactory
    }
    
    private func fetchOmnipoolPairs() -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]> {
        omnipoolTokensFactory.availableDirections()
    }
    
    private func fetchStableswapPairs() -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]> {
        stableswapTokensFactory.availableDirections()
    }
    
    private func mapLocalRoutesToRemote(
        _ routes: [HydraDx.SwapRoute<ChainAssetId>],
        chain: ChainModel,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> [HydraDx.SwapRoute<HydraDx.AssetId>] {
        routes.map {
            
        }
    }
    
    private func createRoutesWrapper(
        for chain: ChainModel,
        assetIn: ChainAssetId,
        assetOut: ChainAssetId,
        omnipoolPairsOperation: BaseOperation<[ChainAssetId: Set<ChainAssetId>]>,
        stableswapPairsOperation: BaseOperation<[ChainAssetId: Set<ChainAssetId>]>,
        stableswapPoolAssets: BaseOperation<Set<ChainAssetId>>
    ) -> BaseOperation<[HydraDx.SwapRoute<HydraDx.AssetId>]> {
        ClosureOperation<[HydraDx.SwapRoute<HydraDx.AssetId>]> {
            let omnipoolPairs = try omnipoolPairsOperation.extractNoCancellableResultData()
            
            if let outAssets = omnipoolPairs[assetIn], outAssets.contains(assetOut) {
                let route = HydraDx.SwapRoute.Component(
                    assetIn: assetIn,
                    assetOut: assetOut,
                    type: .omnipool
                )
                
                return [route]
            }
            
            let stableswapPairs = try stableswapPairsOperation.extractNoCancellableResultData()
            let poolAssets = stableswapPoolAssets.extractNoCancellableResultData()
            
            if
                let outAssets = stableswapPairs[assetIn],
                outAssets.contains(assetOut) {
                
                let localRoutes = poolAssets
                    .filter({ outAssets.contains($0) })
                    .map { poolAsset in
                        let component = HydraDx.SwapRoute.Component(
                            assetIn: assetIn,
                            assetOut: assetOut,
                            type: .stableswap(poolAsset)
                        )
                        
                        return HydraDx.SwapRoute(components: [component])
                    }
                
                return localRoutes
            }
            
            if
                let omniOutAssets = omnipoolPairs[assetIn],
                stableswapPairs[assetOut] != nil {
                
                let connectedPoolAssets = poolAssets
                    .filter { asset in
                        omniOutAssets.contains(asset) &&
                        (stableswapPairs[asset]?.contains(assetOut) ?? false)
                    }
                
                let localRoutes = connectedPoolAssets
                    .map { poolAsset in
                        let component1 = HydraDx.SwapRoute.Component(
                            assetIn: assetIn,
                            assetOut: poolAsset,
                            type: .omnipool
                        )
                        
                        let component2 = HydraDx.SwapRoute.Component(
                            assetIn: poolAsset, assetOut: assetOut, type: .stableswap(poolAsset)
                        )
                        
                        return HydraDx.SwapRoute(components: [component1, component2])
                    }
                
                return localRoutes
            }
            
            if
                let stableswapOutAssets = stableswapPairs[assetIn],
                omnipoolPairs[assetOut] != nil {
                
                let connectedPoolAssets = poolAssets
                    .filter { asset in
                        stableswapOutAssets.contains(asset) &&
                        (omnipoolPairs[asset]?.contains(assetOut) ?? false)
                    }
                
                let localRoutes = connectedPoolAssets
                    .map { poolAsset in
                        let component1 = HydraDx.SwapRoute.Component(
                            assetIn: assetIn,
                            assetOut: poolAsset,
                            type: .stableswap(poolAsset)
                        )
                        
                        let component2 = HydraDx.SwapRoute.Component(
                            assetIn: poolAsset,
                            assetOut: assetOut,
                            type: .omnipool
                        )
                        
                        return HydraDx.SwapRoute(components: [component1, component2])
                    }
                
                return localRoutes
            }
        }
    }
}

extension HydraQuoteFactory: HydraQuoteFactoryProtocol {
    func quote(for args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetConversion.Quote> {
        let omnipoolPairsWrapper = fetchOmnipoolPairs()
        let stableswapPairsWrapper = fetchStableswapPairs()
    }
}
