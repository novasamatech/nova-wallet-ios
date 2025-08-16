import Foundation

enum HydraRoutesResolver {
    struct Data {
        let omnipoolDirections: [ChainAssetId: Set<ChainAssetId>]
        let stableswapDirections: [ChainAssetId: Set<ChainAssetId>]
        let stableswapPoolAssets: Set<ChainAssetId>
        let xykDirections: [ChainAssetId: Set<ChainAssetId>]
    }

    private static func appendingDirections(
        _ directions: [ChainAssetId: Set<ChainAssetId>],
        currentDirections: [ChainAssetId: Set<HydraDx.LocalSwapRoute.Component>],
        type: HydraDx.LocalSwapRoute.ComponentType
    ) -> [ChainAssetId: Set<HydraDx.LocalSwapRoute.Component>] {
        directions.reduce(into: currentDirections) { accum, keyValue in
            let assetIn = keyValue.key
            let assetsOut = keyValue.value

            let mappedConnections = assetsOut.map { assetOut in
                HydraDx.LocalSwapRoute.Component(
                    assetIn: assetIn,
                    assetOut: assetOut,
                    type: type
                )
            }

            accum[assetIn] = accum[assetIn]?.union(Set(mappedConnections)) ?? Set(mappedConnections)
        }
    }

    private static func appendingStableswapDirections(
        _ directions: [ChainAssetId: Set<ChainAssetId>],
        stableswapPoolAssets: Set<ChainAssetId>,
        currentDirections: [ChainAssetId: Set<HydraDx.LocalSwapRoute.Component>]
    ) -> [ChainAssetId: Set<HydraDx.LocalSwapRoute.Component>] {
        directions.reduce(into: currentDirections) { accum, keyValue in
            let assetIn = keyValue.key
            let assetsOut = keyValue.value

            let mappedConnections = assetsOut.flatMap { assetOut in
                let items: [HydraDx.LocalSwapRoute.Component] = stableswapPoolAssets.compactMap { poolAsset in
                    let poolAssetsOut = directions[poolAsset] ?? []
                    let connectedByPool = (poolAsset == assetIn || assetsOut.contains(poolAsset)) &&
                        (poolAsset == assetOut || poolAssetsOut.contains(assetOut))

                    guard connectedByPool else {
                        return nil
                    }

                    return HydraDx.LocalSwapRoute.Component(
                        assetIn: assetIn,
                        assetOut: assetOut,
                        type: .stableswap(poolAsset)
                    )
                }

                return items
            }

            accum[assetIn] = accum[assetIn]?.union(Set(mappedConnections)) ?? Set(mappedConnections)
        }
    }

    private static func resolveShortestRoutes(
        assetIn: ChainAssetId,
        assetOut: ChainAssetId,
        data: HydraRoutesResolver.Data
    ) -> [HydraDx.LocalSwapRoute] {
        var allConnections = appendingDirections(
            data.omnipoolDirections,
            currentDirections: [:],
            type: .omnipool
        )

        allConnections = appendingDirections(
            data.xykDirections,
            currentDirections: allConnections,
            type: .xyk
        )

        allConnections = appendingStableswapDirections(
            data.stableswapDirections,
            stableswapPoolAssets: data.stableswapPoolAssets,
            currentDirections: allConnections
        )

        let routes = GraphModel<ChainAssetId, HydraDx.LocalSwapRoute.Component>(
            connections: allConnections
        ).calculateShortestPath(from: assetIn, nodeEnd: assetOut, topN: 4, filter: .allEdges())

        return routes.map { HydraDx.LocalSwapRoute(components: $0) }
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
        for pair: HydraDx.LocalSwapPair,
        data: HydraRoutesResolver.Data,
        chain: ChainModel,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> [HydraDx.RemoteSwapRoute] {
        let localRoutes = resolveShortestRoutes(
            assetIn: pair.assetIn,
            assetOut: pair.assetOut,
            data: data
        )

        return converLocalRoutesToRemote(localRoutes, chain: chain, codingFactory: codingFactory)
    }
}

extension HydraDx.SwapRoute.Component: GraphEdgeProtocol where Asset: Hashable {
    typealias Node = Asset

    var origin: Asset {
        assetIn
    }

    var destination: Asset {
        assetOut
    }
}

extension HydraDx.SwapRoute.Component: GraphWeightableEdgeProtocol where Asset: Hashable {
    func addingWeight(to currentWeight: Int, predecessor _: AnyGraphEdgeProtocol?) -> Int {
        currentWeight + 1
    }
}
