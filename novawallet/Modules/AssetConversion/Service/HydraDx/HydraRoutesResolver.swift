import Foundation

enum HydraRoutesResolver {
    struct Data {
        let omnipoolDirections: [ChainAssetId: Set<ChainAssetId>]
        let stableswapDirections: [ChainAssetId: Set<ChainAssetId>]
        let stableswapPoolAssets: Set<ChainAssetId>
        let xykDirections: [ChainAssetId: Set<ChainAssetId>]
    }

    private static func resolveShortestRoutes(
        assetIn: ChainAssetId,
        assetOut: ChainAssetId,
        data: HydraRoutesResolver.Data
    ) -> [HydraDx.LocalSwapRoute] {
        var allConnections: [ChainAssetId: Set<HydraDx.LocalSwapRoute.Component>]
        allConnections = data.omnipoolDirections.reduce(into: [:]) { accum, keyValue in
            let node = keyValue.key
            let connections = keyValue.value

            let mappedConnections = connections.map { connection in
                HydraDx.LocalSwapRoute.Component(
                    assetIn: node,
                    assetOut: connection,
                    type: .omnipool
                )
            }

            accum[node] = accum[node]?.union(Set(mappedConnections)) ?? Set(mappedConnections)
        }

        allConnections = data.xykDirections.reduce(into: allConnections) { accum, keyValue in
            let node = keyValue.key
            let connections = keyValue.value

            let mappedConnections = connections.map { connection in
                HydraDx.LocalSwapRoute.Component(
                    assetIn: node,
                    assetOut: connection,
                    type: .xyk
                )
            }

            accum[node] = accum[node]?.union(Set(mappedConnections)) ?? Set(mappedConnections)
        }

        allConnections = data.stableswapDirections.reduce(
            into: allConnections
        ) { accum, keyValue in
            let node = keyValue.key
            let connections = keyValue.value

            let mappedConnections = connections.flatMap { connection in
                let items: [HydraDx.LocalSwapRoute.Component] = data.stableswapPoolAssets.compactMap { asset in
                    let connectedWithInAsset = asset == node || connections.contains(asset)
                    guard
                        connectedWithInAsset,
                        (data.stableswapDirections[asset] ?? []).contains(connection) else {
                        return nil
                    }

                    return HydraDx.LocalSwapRoute.Component(
                        assetIn: node,
                        assetOut: connection,
                        type: .stableswap(asset)
                    )
                }

                return items
            }

            accum[node] = accum[node]?.union(Set(mappedConnections)) ?? Set(mappedConnections)
        }

        let routes = GraphModel<ChainAssetId, HydraDx.LocalSwapRoute.Component>(
            connections: allConnections
        ).calculateShortestPath(from: assetIn, nodeEnd: assetOut, topN: 4)

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

    var destination: Asset {
        assetOut
    }
}
