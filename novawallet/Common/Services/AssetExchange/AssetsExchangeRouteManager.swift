import Foundation
import Operation_iOS

final class AssetsExchangeRouteManager {
    struct AssetExchangeRouteWithCost {
        let path: AssetExchangeGraphPath
        let route: AssetExchangeRoute
        let additionalEstimatedCost: AssetsExchangePathCost

        var comparableAmountOut: Balance {
            route.quote.subtractOrZero(additionalEstimatedCost.amountInAssetOut)
        }
    }

    let possiblePaths: [AssetExchangeGraphPath]
    let pathCostEstimator: AssetsExchangePathCostEstimating
    let commissionPolicy: AssetExchangeCommissionPolicyProtocol?
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        possiblePaths: [AssetExchangeGraphPath],
        pathCostEstimator: AssetsExchangePathCostEstimating,
        commissionPolicy: AssetExchangeCommissionPolicyProtocol?,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.possiblePaths = possiblePaths
        self.pathCostEstimator = pathCostEstimator
        self.commissionPolicy = commissionPolicy
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func createQuote(
        for path: AssetExchangeGraphPath,
        direction: AssetConversion.Direction,
        amountClosure: @escaping () throws -> Balance
    ) -> CompoundOperationWrapper<AssetExchangeRoute> {
        let wrappers: [CompoundOperationWrapper<AssetExchangeRouteItem>]
        wrappers = path.quoteIteration(for: direction).reduce([]) { prevWrappers, item in
            let prevWrapper = prevWrappers.last

            let quoteWrapper: CompoundOperationWrapper<Balance> = OperationCombiningService.compoundNonOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) {
                let prevRouteItem = try prevWrapper?.targetOperation.extractNoCancellableResultData()
                let amountIn = try prevRouteItem?.quote ?? amountClosure()

                return item.quote(amount: amountIn, direction: direction)
            }

            if let prevWrapper {
                quoteWrapper.addDependency(wrapper: prevWrapper)
            }

            let mappingOperation = ClosureOperation<AssetExchangeRouteItem> {
                let quote = try quoteWrapper.targetOperation.extractNoCancellableResultData()
                let prevQuoteItem = try prevWrapper?.targetOperation.extractNoCancellableResultData()
                let amountIn = try prevQuoteItem?.quote ?? amountClosure()

                return AssetExchangeRouteItem(
                    edge: item,
                    amount: amountIn,
                    quote: quote
                )
            }

            mappingOperation.addDependency(quoteWrapper.targetOperation)

            let totalWrapper = quoteWrapper.insertingTail(operation: mappingOperation)

            return prevWrappers + [totalWrapper]
        }

        let mappingOperation = ClosureOperation<AssetExchangeRoute> {
            let amount = try amountClosure()
            let initRoute = AssetExchangeRoute(items: [], amount: amount, direction: direction)

            return try wrappers.reduce(initRoute) { route, wrapper in
                let item = try wrapper.targetOperation.extractNoCancellableResultData()

                return route.byAddingNext(item: item)
            }
        }

        wrappers.forEach { mappingOperation.addDependency($0.targetOperation) }

        let dependencies = wrappers.flatMap(\.allOperations)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }
}

extension AssetsExchangeRouteManager {
    func fetchRoute(
        for amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<AssetExchangeRoute?> {
        let routeWithCostWrappers = possiblePaths.map { path in
            let routeWrapper = createQuote(for: path, direction: direction) { amount }
            let costWrapper = pathCostEstimator.costEstimationWrapper(for: path)

            return (path: path, route: routeWrapper, cost: costWrapper)
        }

        let winnerCalculator = ClosureOperation<AssetExchangeRouteWithCost?> {
            let exchangeRoutes: [AssetExchangeRouteWithCost] = routeWithCostWrappers.compactMap { pathWrappers in
                do {
                    let route = try pathWrappers.route.targetOperation.extractNoCancellableResultData()
                    let cost = try pathWrappers.cost.targetOperation.extractNoCancellableResultData()

                    return AssetExchangeRouteWithCost(
                        path: pathWrappers.path,
                        route: route,
                        additionalEstimatedCost: cost
                    )
                } catch {
                    return nil
                }
            }

            switch direction {
            case .sell:
                return exchangeRoutes.max { res1, res2 in
                    res1.comparableAmountOut < res2.comparableAmountOut
                }
            case .buy:
                return exchangeRoutes.min { res1, res2 in
                    let value1 = res1.route.quote + res1.additionalEstimatedCost.amountInAssetIn
                    let value2 = res2.route.quote + res2.additionalEstimatedCost.amountInAssetIn

                    return value1 < value2
                }
            }
        }

        let dependencies = routeWithCostWrappers.flatMap { routeWithCostWrapper in
            routeWithCostWrapper.route.allOperations + routeWithCostWrapper.cost.allOperations
        }

        dependencies.forEach { winnerCalculator.addDependency($0) }

        let finalWrapper = createWinnerRouteWrapper(
            from: winnerCalculator,
            amount: amount,
            direction: direction
        )

        return finalWrapper.insertingHead(operations: dependencies + [winnerCalculator])
    }
}

private extension AssetsExchangeRouteManager {
    func createWinnerRouteWrapper(
        from winnerCalculator: BaseOperation<AssetExchangeRouteWithCost?>,
        amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<AssetExchangeRoute?> {
        let wrapper: CompoundOperationWrapper<AssetExchangeRoute?>
        wrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            guard let winner = try winnerCalculator.extractNoCancellableResultData() else {
                return .createWithResult(nil)
            }

            switch direction {
            case .sell:
                return .createWithResult(winner.route)
            case .buy:
                return self.createGrossedUpQuote(for: winner, amount: amount)
            }
        }

        wrapper.addDependency(operations: [winnerCalculator])

        return wrapper
    }

    func createGrossedUpQuote(
        for candidate: AssetExchangeRouteWithCost,
        amount: Balance
    ) -> CompoundOperationWrapper<AssetExchangeRoute?> {
        guard let commissionPolicy else {
            return .createWithResult(candidate.route)
        }

        let grossWrapper = commissionPolicy.grossingUpAmountOutWrapper(amount, for: candidate.path)

        let routeWrapper = createQuote(for: candidate.path, direction: .buy) {
            try grossWrapper.targetOperation.extractNoCancellableResultData()
        }

        routeWrapper.addDependency(wrapper: grossWrapper)

        let mappingOperation = ClosureOperation<AssetExchangeRoute?> {
            try routeWrapper.targetOperation.extractNoCancellableResultData()
        }

        mappingOperation.addDependency(routeWrapper.targetOperation)

        return routeWrapper
            .insertingHead(operations: grossWrapper.allOperations)
            .insertingTail(operation: mappingOperation)
    }
}
