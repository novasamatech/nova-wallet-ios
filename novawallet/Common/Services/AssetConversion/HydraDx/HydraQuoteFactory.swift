import Foundation
import Operation_iOS
import BigInt

final class HydraQuoteFactory {
    let flowState: HydraFlowState
    let logger: LoggerProtocol

    init(flowState: HydraFlowState, logger: LoggerProtocol = Logger.shared) {
        self.flowState = flowState
        self.logger = logger
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
            case .xyk:
                let xykState = flowState.getXYKSwapFlowState()
                let quoteFactory = HydraXYKSwapQuoteFactory(flowState: xykState)

                return quoteFactory.quote(
                    for: .init(
                        assetIn: component.assetIn,
                        assetOut: component.assetOut,
                        amount: amount,
                        direction: direction
                    )
                )
            case .aave:
                let aaveState = flowState.getAaveSwapFlowState()
                let quoteFactory = HydraAaveSwapQuoteFactory(flowState: aaveState)

                return quoteFactory.quote(
                    for: .init(
                        assetIn: component.assetIn,
                        assetOut: component.assetOut,
                        amount: amount,
                        direction: direction
                    )
                )
            }
        }
    }

    private func createQuoteWrapper(
        route: HydraDx.RemoteSwapRoute,
        args: AssetConversion.QuoteArgs
    ) -> CompoundOperationWrapper<AssetConversion.Quote> {
        let components: [HydraDx.RemoteSwapRoute.Component]

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
        dependingOn routesOperation: BaseOperation<[HydraDx.RemoteSwapRoute]>,
        args: AssetConversion.QuoteArgs
    ) -> CompoundOperationWrapper<AssetConversion.Quote> {
        let quoteOperation = OperationCombiningService(
            operationManager: OperationManager(operationQueue: flowState.operationQueue)
        ) {
            let routes = try routesOperation.extractNoCancellableResultData()

            self.logger.debug("Routes: \(routes)")

            return routes.map { route in
                let wrapper = self.createQuoteWrapper(route: route, args: args)

                // silence error for particular route as we can have other results to select
                let mappingOperation = ClosureOperation<AssetConversion.Quote?> {
                    do {
                        let quote = try wrapper.targetOperation.extractNoCancellableResultData()
                        self.logger.debug("Quote for \(route): \(String(describing: quote))")
                        return quote
                    } catch {
                        self.logger.error("Error Quote for \(route): \(error)")
                        return nil
                    }
                }

                mappingOperation.addDependency(wrapper.targetOperation)

                return wrapper.insertingTail(operation: mappingOperation)
            }
        }.longrunOperation()

        let mapOperation = ClosureOperation<AssetConversion.Quote> {
            let quotes = try quoteOperation.extractNoCancellableResultData().compactMap { $0 }

            switch args.direction {
            case .sell:
                guard let maxSellQuote = quotes.max(by: { $0.amountOut < $1.amountOut }) else {
                    throw AssetConversionOperationError.noRoutesAvailable
                }

                return maxSellQuote
            case .buy:
                guard let minBuyQuote = quotes.min(by: { $0.amountIn < $1.amountIn }) else {
                    throw AssetConversionOperationError.noRoutesAvailable
                }

                return minBuyQuote
            }
        }

        mapOperation.addDependency(quoteOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [quoteOperation])
    }
}

extension HydraQuoteFactory: AssetQuoteFactoryProtocol {
    func quote(for args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetConversion.Quote> {
        flowState.resetServicesIfNotMatchingPair(
            .init(assetIn: args.assetIn, assetOut: args.assetOut)
        )

        let routesFactory = flowState.getRoutesFactory()

        let swapPair = HydraDx.LocalSwapPair(assetIn: args.assetIn, assetOut: args.assetOut)
        let routesWrapper = routesFactory.createRoutesWrapper(for: swapPair)

        let quoteWrapper = createQuoteWrapper(
            dependingOn: routesWrapper.targetOperation,
            args: args
        )

        quoteWrapper.addDependency(wrapper: routesWrapper)

        return quoteWrapper.insertingHead(operations: routesWrapper.allOperations)
    }
}
