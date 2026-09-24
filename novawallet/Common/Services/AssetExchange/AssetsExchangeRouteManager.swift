import Foundation
import Operation_iOS

final class AssetsExchangeRouteManager {
    struct AssetExchangeRouteWithCost {
        let path: AssetExchangeGraphPath
        let route: AssetExchangeRoute
        let additionalEstimatedCost: AssetsExchangePathCost
        let netAmountOut: Balance

        var comparableAmountOut: Balance {
            netAmountOut.subtractOrZero(additionalEstimatedCost.amountInAssetOut)
        }

        var comparableAmountIn: Balance {
            route.amountIn + additionalEstimatedCost.amountInAssetIn
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
        amountWrapper: CompoundOperationWrapper<Balance>
    ) -> CompoundOperationWrapper<AssetExchangeRoute> {
        let wrappers: [CompoundOperationWrapper<AssetExchangeRouteItem>]
        wrappers = path.quoteIteration(for: direction).reduce([]) { prevWrappers, item in
            let prevWrapper = prevWrappers.last

            let quoteWrapper: CompoundOperationWrapper<Balance> = OperationCombiningService.compoundNonOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) {
                let prevRouteItem = try prevWrapper?.targetOperation.extractNoCancellableResultData()
                let amountIn = try prevRouteItem?.quote ?? amountWrapper.targetOperation.extractNoCancellableResultData()

                return item.quote(amount: amountIn, direction: direction)
            }

            if let prevWrapper {
                quoteWrapper.addDependency(wrapper: prevWrapper)
            } else {
                quoteWrapper.addDependency(wrapper: amountWrapper)
            }

            let mappingOperation = ClosureOperation<AssetExchangeRouteItem> {
                let quote = try quoteWrapper.targetOperation.extractNoCancellableResultData()
                let prevQuoteItem = try prevWrapper?.targetOperation.extractNoCancellableResultData()
                let amountIn = try prevQuoteItem?.quote ?? amountWrapper.targetOperation.extractNoCancellableResultData()

                return AssetExchangeRouteItem(
                    edge: item,
                    amount: amountIn,
                    quote: quote
                )
            }

            mappingOperation.addDependency(quoteWrapper.targetOperation)

            if prevWrapper == nil {
                mappingOperation.addDependency(amountWrapper.targetOperation)
            }

            let totalWrapper = quoteWrapper.insertingTail(operation: mappingOperation)

            return prevWrappers + [totalWrapper]
        }

        let mappingOperation = ClosureOperation<AssetExchangeRoute> {
            let amount = try amountWrapper.targetOperation.extractNoCancellableResultData()
            let initRoute = AssetExchangeRoute(items: [], amount: amount, direction: direction)

            return try wrappers.reduce(initRoute) { route, wrapper in
                let item = try wrapper.targetOperation.extractNoCancellableResultData()

                return route.byAddingNext(item: item)
            }
        }

        wrappers.forEach { mappingOperation.addDependency($0.targetOperation) }
        mappingOperation.addDependency(amountWrapper.targetOperation)

        let dependencies = wrappers.flatMap(\.allOperations) + amountWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }
}

extension AssetsExchangeRouteManager {
    func fetchRoute(
        for amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<AssetExchangeRoute?> {
        let routeWithCostWrappers = possiblePaths.map { path in
            let routeWrapper = createCandidateQuote(
                for: path,
                amount: amount,
                direction: direction
            )
            let costWrapper = pathCostEstimator.costEstimationWrapper(for: path)

            return (path: path, route: routeWrapper, cost: costWrapper)
        }

        let winnerCalculator = ClosureOperation<AssetExchangeRoute?> {
            let exchangeRoutes: [AssetExchangeRouteWithCost] = routeWithCostWrappers.compactMap { pathWrappers in
                do {
                    let route = try pathWrappers.route.targetOperation.extractNoCancellableResultData()
                    let cost = try pathWrappers.cost.targetOperation.extractNoCancellableResultData()

                    return AssetExchangeRouteWithCost(
                        path: pathWrappers.path,
                        route: route,
                        additionalEstimatedCost: cost,
                        netAmountOut: try self.calculateNetAmountOut(for: route)
                    )
                } catch {
                    let pathDescription = pathWrappers.path
                        .map { "\($0.type) \($0.origin.stringValue) -> \($0.destination.stringValue)" }
                        .joined(separator: ", ")

                    self.logger.warning("Route quoting failed for candidate path [\(pathDescription)]: \(error)")

                    return nil
                }
            }

            return self.selectWinner(from: exchangeRoutes, direction: direction)?.route
        }

        let dependencies = routeWithCostWrappers.flatMap { routeWithCostWrapper in
            routeWithCostWrapper.route.allOperations + routeWithCostWrapper.cost.allOperations
        }

        dependencies.forEach { winnerCalculator.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: winnerCalculator, dependencies: dependencies)
    }
}

private extension AssetsExchangeRouteManager {
    func selectWinner(
        from candidates: [AssetExchangeRouteWithCost],
        direction: AssetConversion.Direction
    ) -> AssetExchangeRouteWithCost? {
        switch direction {
        case .sell:
            return candidates.max { res1, res2 in
                res1.comparableAmountOut < res2.comparableAmountOut
            }
        case .buy:
            return candidates.min { res1, res2 in
                res1.comparableAmountIn < res2.comparableAmountIn
            }
        }
    }

    func calculateNetAmountOut(for route: AssetExchangeRoute) throws -> Balance {
        guard let commission = commissionPolicy?.resolveCommission(for: route) else {
            return route.amountOut
        }

        return try AssetExchangeMetaOperationFactory()
            .createMetaOperations(for: route)
            .netAmountOut(commission: commission)
    }

    func createCandidateQuote(
        for path: AssetExchangeGraphPath,
        amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<AssetExchangeRoute> {
        guard
            direction == .buy,
            let commissionPolicy,
            commissionPolicy.hasChargingSite(in: path) else {
            return createQuote(for: path, direction: direction, amountWrapper: .createWithResult(amount))
        }

        let grossedAmount = commissionPolicy.grossingUpAmountOut(amount, for: path)

        guard grossedAmount != amount else {
            return createQuote(for: path, direction: .buy, amountWrapper: .createWithResult(amount))
        }

        let grossedWrapper = createQuote(
            for: path,
            direction: .buy,
            amountWrapper: .createWithResult(grossedAmount)
        )

        let resultWrapper: CompoundOperationWrapper<AssetExchangeRoute>
        resultWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let grossedRoute = try grossedWrapper.targetOperation.extractNoCancellableResultData()

            guard commissionPolicy.resolveCommission(for: grossedRoute) != nil else {
                return self.createQuote(
                    for: path,
                    direction: .buy,
                    amountWrapper: .createWithResult(amount)
                )
            }

            return .createWithResult(grossedRoute)
        }

        resultWrapper.addDependency(wrapper: grossedWrapper)

        return resultWrapper.insertingHead(operations: grossedWrapper.allOperations)
    }
}
