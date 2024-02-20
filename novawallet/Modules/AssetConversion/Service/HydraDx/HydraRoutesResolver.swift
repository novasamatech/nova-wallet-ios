import Foundation

enum HydraRoutesResolver {
    struct Data {
        let omnipoolDirections: [ChainAssetId: Set<ChainAssetId>]
        let stableswapDirections: [ChainAssetId: Set<ChainAssetId>]
        let stableswapPoolAssets: Set<ChainAssetId>
    }

    private static func resolveOmnipoolRoutes(
        assetIn: ChainAssetId,
        assetOut: ChainAssetId,
        data: HydraRoutesResolver.Data
    ) -> [HydraDx.LocalSwapRoute] {
        if let outAssets = data.omnipoolDirections[assetIn], outAssets.contains(assetOut) {
            let route = HydraDx.LocalSwapRoute(
                components: [
                    .init(assetIn: assetIn, assetOut: assetOut, type: .omnipool)
                ]
            )

            return [route]
        } else {
            return []
        }
    }

    private static func resolveStableswapRoutes(
        assetIn: ChainAssetId,
        assetOut: ChainAssetId,
        data: HydraRoutesResolver.Data
    ) -> [HydraDx.LocalSwapRoute] {
        guard
            let outAssets = data.stableswapDirections[assetIn],
            outAssets.contains(assetOut) else {
            return []
        }

        return data.stableswapPoolAssets
            .filter { outAssets.contains($0) && (data.stableswapDirections[$0]?.contains(assetOut) ?? false) }
            .map { poolAsset in
                let component = HydraDx.LocalSwapRoute.Component(
                    assetIn: assetIn,
                    assetOut: assetOut,
                    type: .stableswap(poolAsset)
                )

                return HydraDx.LocalSwapRoute(components: [component])
            }
    }

    private static func resolveOmnipoolStableswapRoutes(
        assetIn: ChainAssetId,
        assetOut: ChainAssetId,
        data: HydraRoutesResolver.Data
    ) -> [HydraDx.LocalSwapRoute] {
        guard
            let omniOutAssets = data.omnipoolDirections[assetIn],
            data.stableswapDirections[assetOut] != nil else {
            return []
        }

        let connectedPoolAssets = data.stableswapPoolAssets
            .filter { asset in
                omniOutAssets.contains(asset) &&
                    (data.stableswapDirections[asset]?.contains(assetOut) ?? false)
            }

        return connectedPoolAssets
            .map { poolAsset in
                let component1 = HydraDx.LocalSwapRoute.Component(
                    assetIn: assetIn,
                    assetOut: poolAsset,
                    type: .omnipool
                )

                let component2 = HydraDx.LocalSwapRoute.Component(
                    assetIn: poolAsset,
                    assetOut: assetOut,
                    type: .stableswap(poolAsset)
                )

                return HydraDx.LocalSwapRoute(components: [component1, component2])
            }
    }

    private static func resolveStableswapOmnipoolRoutes(
        assetIn: ChainAssetId,
        assetOut: ChainAssetId,
        data: HydraRoutesResolver.Data
    ) -> [HydraDx.LocalSwapRoute] {
        guard
            let stableswapOutAssets = data.stableswapDirections[assetIn],
            data.omnipoolDirections[assetOut] != nil else {
            return []
        }

        let connectedPoolAssets = data.stableswapPoolAssets
            .filter { asset in
                stableswapOutAssets.contains(asset) &&
                    (data.omnipoolDirections[asset]?.contains(assetOut) ?? false)
            }

        return connectedPoolAssets
            .map { poolAsset in
                let component1 = HydraDx.LocalSwapRoute.Component(
                    assetIn: assetIn,
                    assetOut: poolAsset,
                    type: .stableswap(poolAsset)
                )

                let component2 = HydraDx.LocalSwapRoute.Component(
                    assetIn: poolAsset,
                    assetOut: assetOut,
                    type: .omnipool
                )

                return HydraDx.LocalSwapRoute(components: [component1, component2])
            }
    }

    static func converLocalRoutesToRemote(
        _ routes: [HydraDx.LocalSwapRoute],
        chain: ChainModel,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> [HydraDx.RemoteSwapRoute] {
        routes.compactMap { route in
            try? route.map { chainAssetId in
                guard let asset = chain.asset(for: chainAssetId.assetId) else {
                    throw CommonError.dataCorruption
                }

                return try HydraDxTokenConverter.convertToRemote(
                    chainAsset: .init(chain: chain, asset: asset),
                    codingFactory: codingFactory
                ).remoteAssetId
            }
        }
    }

    static func resolveRoutes(
        for swapPair: HydraDx.LocalSwapPair,
        data: HydraRoutesResolver.Data,
        chain: ChainModel,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> [HydraDx.RemoteSwapRoute] {
        let assetIn = swapPair.assetIn
        let assetOut = swapPair.assetOut

        let omnipoolRoutes = resolveOmnipoolRoutes(
            assetIn: assetIn,
            assetOut: assetOut,
            data: data
        )

        let stableswapRoutes = resolveStableswapRoutes(
            assetIn: assetIn,
            assetOut: assetOut,
            data: data
        )

        let omnipoolStableswapRoutes = resolveOmnipoolStableswapRoutes(
            assetIn: assetIn,
            assetOut: assetOut,
            data: data
        )

        let stableswapOmnipoolRoutes = resolveStableswapOmnipoolRoutes(
            assetIn: assetIn,
            assetOut: assetOut,
            data: data
        )

        let localRoutes = omnipoolRoutes + stableswapRoutes + omnipoolStableswapRoutes +
            stableswapOmnipoolRoutes

        return converLocalRoutesToRemote(localRoutes, chain: chain, codingFactory: codingFactory)
    }
}
