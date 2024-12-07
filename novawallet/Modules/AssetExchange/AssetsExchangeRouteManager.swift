import Foundation
import Operation_iOS

final class AssetsExchangeRouteManager {
    struct AssetExchangeRouteWithCost {
        let route: AssetExchangeRoute
        let additionalEstimatedCost: Balance
    }

    let possiblePaths: [AssetExchangeGraphPath]
    let pathCostEstimator: AssetsExchangePathCostEstimating
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        possiblePaths: [AssetExchangeGraphPath],
        pathCostEstimator: AssetsExchangePathCostEstimating,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.possiblePaths = possiblePaths
        self.pathCostEstimator = pathCostEstimator
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func createQuote(
        for path: AssetExchangeGraphPath,
        amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<AssetExchangeRoute> {
        let wrappers: [CompoundOperationWrapper<AssetExchangeRouteItem>]
        wrappers = path.quoteIteration(for: direction).reduce([]) { prevWrappers, item in
            let prevWrapper = prevWrappers.last

            let quoteWrapper: CompoundOperationWrapper<Balance> = OperationCombiningService.compoundNonOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) {
                let prevRouteItem = try prevWrapper?.targetOperation.extractNoCancellableResultData()

                let wrapper = item.quote(amount: prevRouteItem?.quote ?? amount, direction: direction)

                return wrapper
            }

            if let prevWrapper {
                quoteWrapper.addDependency(wrapper: prevWrapper)
            }

            let mappingOperation = ClosureOperation<AssetExchangeRouteItem> {
                let quote = try quoteWrapper.targetOperation.extractNoCancellableResultData()
                let prevQuoteItem = try prevWrapper?.targetOperation.extractNoCancellableResultData()

                return AssetExchangeRouteItem(
                    edge: item,
                    amount: prevQuoteItem?.quote ?? amount,
                    quote: quote
                )
            }

            mappingOperation.addDependency(quoteWrapper.targetOperation)

            let totalWrapper = quoteWrapper.insertingTail(operation: mappingOperation)

            return prevWrappers + [totalWrapper]
        }

        let mappingOperation = ClosureOperation<AssetExchangeRoute> {
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
            let routeWrapper = createQuote(for: path, amount: amount, direction: direction)
            let costWrapper = pathCostEstimator.costEstimationWrapper(for: path, direction: direction)

            return (routeWrapper, costWrapper)
        }

        let winnerCalculator = ClosureOperation<AssetExchangeRoute?> {
            let exchangeRoutes: [AssetExchangeRouteWithCost] = routeWithCostWrappers.compactMap { pairWrappers in
                do {
                    let route = try pairWrappers.0.targetOperation.extractNoCancellableResultData()
                    let cost = try pairWrappers.1.targetOperation.extractNoCancellableResultData()

                    return AssetExchangeRouteWithCost(route: route, additionalEstimatedCost: cost)
                } catch {
                    return nil
                }
            }

            switch direction {
            case .sell:
                return exchangeRoutes.max { res1, res2 in
                    let value1 = res1.route.quote.subtractOrZero(res1.additionalEstimatedCost)
                    let value2 = res2.route.quote.subtractOrZero(res2.additionalEstimatedCost)

                    return value1 < value2
                }?.route
            case .buy:
                return exchangeRoutes.min { res1, res2 in
                    let value1 = res1.route.quote + res1.additionalEstimatedCost
                    let value2 = res2.route.quote + res2.additionalEstimatedCost

                    return value1 < value2
                }?.route
            }
        }

        let dependencies = routeWithCostWrappers.flatMap { routeWithCostWrapper in
            routeWithCostWrapper.0.allOperations + routeWithCostWrapper.1.allOperations
        }

        dependencies.forEach { winnerCalculator.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: winnerCalculator, dependencies: dependencies)
    }
}
