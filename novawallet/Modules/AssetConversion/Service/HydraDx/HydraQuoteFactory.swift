import Foundation
import RobinHood
import BigInt

protocol HydraQuoteFactoryProtocol {
    func quote(for args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetConversion.Quote>
}

final class HydraQuoteFactory {
    let omnipoolTokensFactory: HydraOmnipoolTokensFactory
    let stableswapTokensFactory: HydraStableSwapsTokensFactory
    let flowState: HydraFlowState

    init(
        flowState: HydraFlowState,
        omnipoolTokensFactory: HydraOmnipoolTokensFactory,
        stableswapTokensFactory: HydraStableSwapsTokensFactory
    ) {
        self.flowState = flowState
        self.omnipoolTokensFactory = omnipoolTokensFactory
        self.stableswapTokensFactory = stableswapTokensFactory
    }

    private func createRouteComponentQuoteWrapper(
        for component: HydraDx.SwapRoute<HydraDx.AssetId>.Component,
        lastWrapper: CompoundOperationWrapper<BigUInt>,
        direction: AssetConversion.Direction,
        flowState: HydraFlowState
    ) -> CompoundOperationWrapper<BigUInt> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: flowState.operationQueue)
        ) {
            let amount = try lastWrapper.targetOperation.extractNoCancellableResultData()

            switch component.type {
            case .omnipool:
                let omnipoolState = flowState.getOmnipoolFlowState()
                let quoteFactory = HydraOmnipoolQuoteFactory(flowState: omnipoolState)

                return quoteFactory.quote(
                    for: .init(
                        assetIn: component.assetIn,
                        assetOut: component.assetOut,
                        amount: amount,
                        direction: direction
                    )
                )
            case let .stableswap(poolAsset):
                let stableswapState = flowState.getStableswapFlowState()
                let quoteFactory = HydraStableswapQuoteFactory(flowState: stableswapState)

                return quoteFactory.quote(
                    for: .init(
                        assetIn: component.assetIn,
                        assetOut: component.assetOut,
                        poolAsset: poolAsset,
                        amount: amount,
                        direction: direction
                    )
                )
            }
        }
    }

    private func createQuoteWrapper(
        route: HydraDx.SwapRoute<HydraDx.AssetId>,
        args: AssetConversion.QuoteArgs
    ) -> CompoundOperationWrapper<AssetConversion.Quote> {
        let components: [HydraDx.SwapRoute<HydraDx.AssetId>.Component]

        switch args.direction {
        case .sell:
            components = route.components
        case .buy:
            components = Array(route.components.reversed())
        }

        let quoteWrapper: CompoundOperationWrapper<BigUInt> = components.reduce(
            CompoundOperationWrapper.createWithResult(args.amount)
        ) { lastWrapper, component in
            let nextWrapper = createRouteComponentQuoteWrapper(
                for: component,
                lastWrapper: lastWrapper,
                direction: args.direction,
                flowState: flowState
            )

            nextWrapper.addDependency(operations: [lastWrapper.targetOperation])

            let dependecies = lastWrapper.allOperations + nextWrapper.dependencies

            return CompoundOperationWrapper(targetOperation: nextWrapper.targetOperation, dependencies: dependecies)
        }

        let mapOperation = ClosureOperation<AssetConversion.Quote> {
            let amount = try quoteWrapper.targetOperation.extractNoCancellableResultData()

            let context = try JsonStringify.jsonString(from: route)
            return .init(args: args, amount: amount, context: context)
        }

        mapOperation.addDependency(quoteWrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: quoteWrapper.allOperations)
    }

    private func createQuoteWrapper(
        dependingOn routesOperation: BaseOperation<[HydraDx.SwapRoute<HydraDx.AssetId>]>,
        args: AssetConversion.QuoteArgs
    ) -> CompoundOperationWrapper<AssetConversion.Quote> {
        let quoteOperation = OperationCombiningService(
            operationManager: OperationManager(operationQueue: flowState.operationQueue)
        ) {
            let routes = try routesOperation.extractNoCancellableResultData()

            return routes.map { self.createQuoteWrapper(route: $0, args: args) }
        }.longrunOperation()

        let mapOperation = ClosureOperation<AssetConversion.Quote> {
            let quotes = try quoteOperation.extractNoCancellableResultData()

            switch args.direction {
            case .sell:
                guard let maxSellQuote = quotes.max(by: { $0.amountOut < $1.amountOut }) else {
                    throw AssetConversionOperationError.quoteCalcFailed
                }

                return maxSellQuote
            case .buy:
                guard let minBuyQuote = quotes.min(by: { $0.amountIn < $1.amountIn }) else {
                    throw AssetConversionOperationError.quoteCalcFailed
                }

                return minBuyQuote
            }
        }

        mapOperation.addDependency(quoteOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [quoteOperation])
    }

    private func fetchOmnipoolPairs() -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]> {
        omnipoolTokensFactory.availableDirections()
    }

    private func fetchStableswapPairs() -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]> {
        stableswapTokensFactory.availableDirections()
    }

    private func createLocalRoutesToRemoteWrapper(
        _ routesOperation: BaseOperation<[HydraDx.SwapRoute<ChainAssetId>]>,
        chain: ChainModel
    ) -> CompoundOperationWrapper<[HydraDx.SwapRoute<HydraDx.AssetId>]> {
        let codingFactoryOperation = flowState.runtimeProvider.fetchCoderFactoryOperation()

        let mapOperation = ClosureOperation<[HydraDx.SwapRoute<HydraDx.AssetId>]> {
            let routes = try routesOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            return routes.compactMap { route in
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

        mapOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [codingFactoryOperation])
    }

    private func createRoutesOperation(
        for assetIn: ChainAssetId,
        assetOut: ChainAssetId,
        omnipoolPairsOperation: BaseOperation<[ChainAssetId: Set<ChainAssetId>]>,
        stableswapPairsOperation: BaseOperation<[ChainAssetId: Set<ChainAssetId>]>,
        stableswapPoolAssets: BaseOperation<Set<ChainAssetId>>
    ) -> BaseOperation<[HydraDx.SwapRoute<ChainAssetId>]> {
        ClosureOperation<[HydraDx.SwapRoute<ChainAssetId>]> {
            let omnipoolPairs = try omnipoolPairsOperation.extractNoCancellableResultData()

            if let outAssets = omnipoolPairs[assetIn], outAssets.contains(assetOut) {
                let route = HydraDx.SwapRoute<ChainAssetId>(
                    components: [
                        .init(assetIn: assetIn, assetOut: assetOut, type: .omnipool)
                    ]
                )

                return [route]
            }

            let stableswapPairs = try stableswapPairsOperation.extractNoCancellableResultData()
            let poolAssets = try stableswapPoolAssets.extractNoCancellableResultData()

            if
                let outAssets = stableswapPairs[assetIn],
                outAssets.contains(assetOut) {
                let localRoutes = poolAssets
                    .filter { outAssets.contains($0) && (stableswapPairs[$0]?.contains(assetOut) ?? false) }
                    .map { poolAsset in
                        let component = HydraDx.SwapRoute<ChainAssetId>.Component(
                            assetIn: assetIn,
                            assetOut: assetOut,
                            type: .stableswap(poolAsset)
                        )

                        return HydraDx.SwapRoute<ChainAssetId>(components: [component])
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
                        let component1 = HydraDx.SwapRoute<ChainAssetId>.Component(
                            assetIn: assetIn,
                            assetOut: poolAsset,
                            type: .omnipool
                        )

                        let component2 = HydraDx.SwapRoute<ChainAssetId>.Component(
                            assetIn: poolAsset, assetOut: assetOut, type: .stableswap(poolAsset)
                        )

                        return HydraDx.SwapRoute<ChainAssetId>(components: [component1, component2])
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

                        return HydraDx.SwapRoute<ChainAssetId>(components: [component1, component2])
                    }

                return localRoutes
            }

            return []
        }
    }
}

extension HydraQuoteFactory: HydraQuoteFactoryProtocol {
    func quote(for args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetConversion.Quote> {
        let omnipoolPairsWrapper = fetchOmnipoolPairs()
        let stableswapPairsWrapper = fetchStableswapPairs()
        let stableswapPoolAssetsWrapper = stableswapTokensFactory.fetchAllLocalPoolAssets(for: flowState.chain)

        let routesOperation = createRoutesOperation(
            for: args.assetIn,
            assetOut: args.assetOut,
            omnipoolPairsOperation: omnipoolPairsWrapper.targetOperation,
            stableswapPairsOperation: stableswapPairsWrapper.targetOperation,
            stableswapPoolAssets: stableswapPoolAssetsWrapper.targetOperation
        )

        routesOperation.addDependency(omnipoolPairsWrapper.targetOperation)
        routesOperation.addDependency(stableswapPairsWrapper.targetOperation)
        routesOperation.addDependency(stableswapPoolAssetsWrapper.targetOperation)

        let remoteRoutesWrapper = createLocalRoutesToRemoteWrapper(routesOperation, chain: flowState.chain)

        remoteRoutesWrapper.addDependency(operations: [routesOperation])

        let quoteWrapper = createQuoteWrapper(
            dependingOn: remoteRoutesWrapper.targetOperation,
            args: args
        )

        quoteWrapper.addDependency(wrapper: remoteRoutesWrapper)

        let dependencies = omnipoolPairsWrapper.allOperations + stableswapPairsWrapper.allOperations +
            stableswapPoolAssetsWrapper.allOperations + [routesOperation] + remoteRoutesWrapper.allOperations +
            quoteWrapper.dependencies

        return CompoundOperationWrapper(
            targetOperation: quoteWrapper.targetOperation,
            dependencies: dependencies
        )
    }
}
