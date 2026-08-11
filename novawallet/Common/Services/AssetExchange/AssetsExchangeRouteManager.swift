import Foundation
import Operation_iOS

final class AssetsExchangeRouteManager {
    struct AssetExchangeRouteWithCost {
        let route: AssetExchangeRoute
        let additionalEstimatedCost: AssetsExchangePathCost
        let path: AssetExchangeGraphPath

        func comparableAmountOut(using commissionPolicy: AssetExchangeCommissionPolicyProtocol?) -> Balance {
            let willCharge = commissionPolicy?.chargingOperationIndex(in: path) != nil

            let netQuote = commissionPolicy?.netAmount(
                from: route.quote,
                willCharge: willCharge
            ) ?? route.quote

            return netQuote.subtractOrZero(additionalEstimatedCost.amountInAssetOut)
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

    func createQuote(
        for path: AssetExchangeGraphPath,
        amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<AssetExchangeRoute> {
        let seedAmount: Balance = switch direction {
        case .sell:
            amount
        case .buy:
            commissionPolicy?.grossingUpAmountOut(amount, for: path) ?? amount
        }

        let wrappers: [CompoundOperationWrapper<AssetExchangeRouteItem>]
        wrappers = path.quoteIteration(for: direction).reduce([]) { prevWrappers, item in
            let prevWrapper = prevWrappers.last

            let quoteWrapper: CompoundOperationWrapper<Balance> = OperationCombiningService.compoundNonOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) {
                let prevRouteItem = try prevWrapper?.targetOperation.extractNoCancellableResultData()

                let wrapper = item.quote(amount: prevRouteItem?.quote ?? seedAmount, direction: direction)

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
                    amount: prevQuoteItem?.quote ?? seedAmount,
                    quote: quote
                )
            }

            mappingOperation.addDependency(quoteWrapper.targetOperation)

            let totalWrapper = quoteWrapper.insertingTail(operation: mappingOperation)

            return prevWrappers + [totalWrapper]
        }

        let mappingOperation = ClosureOperation<AssetExchangeRoute> {
            let initRoute = AssetExchangeRoute(items: [], amount: seedAmount, direction: direction)

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
        let commissionPolicy = commissionPolicy

        let routeWithCostWrappers = possiblePaths.map { path in
            let routeWrapper = createQuote(for: path, amount: amount, direction: direction)
            let costWrapper = pathCostEstimator.costEstimationWrapper(for: path)

            return (path: path, route: routeWrapper, cost: costWrapper)
        }

        let winnerCalculator = ClosureOperation<AssetExchangeRoute?> {
            let exchangeRoutes: [AssetExchangeRouteWithCost] = routeWithCostWrappers.compactMap { pathWrappers in
                do {
                    let route = try pathWrappers.route.targetOperation.extractNoCancellableResultData()
                    let cost = try pathWrappers.cost.targetOperation.extractNoCancellableResultData()

                    return AssetExchangeRouteWithCost(
                        route: route,
                        additionalEstimatedCost: cost,
                        path: pathWrappers.path
                    )
                } catch {
                    return nil
                }
            }

            switch direction {
            case .sell:
                return exchangeRoutes.max { res1, res2 in
                    let value1 = res1.comparableAmountOut(using: commissionPolicy)
                    let value2 = res2.comparableAmountOut(using: commissionPolicy)

                    return value1 < value2
                }?.route
            case .buy:
                return exchangeRoutes.min { res1, res2 in
                    let value1 = res1.route.quote + res1.additionalEstimatedCost.amountInAssetIn
                    let value2 = res2.route.quote + res2.additionalEstimatedCost.amountInAssetIn

                    return value1 < value2
                }?.route
            }
        }

        let dependencies = routeWithCostWrappers.flatMap { routeWithCostWrapper in
            routeWithCostWrapper.route.allOperations + routeWithCostWrapper.cost.allOperations
        }

        dependencies.forEach { winnerCalculator.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: winnerCalculator, dependencies: dependencies)
    }
}
