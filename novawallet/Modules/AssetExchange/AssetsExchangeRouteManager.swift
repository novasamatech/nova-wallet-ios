import Foundation
import Operation_iOS

final class AssetsExchangeRouteManager {
    let possiblePaths: [AssetExchangeGraphPath]
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        possiblePaths: [AssetExchangeGraphPath],
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.possiblePaths = possiblePaths
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func createQuote(
        for path: AssetExchangeGraphPath,
        amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<AssetExchangeRoute> {
        let wrappers: [CompoundOperationWrapper<AssetExchangeRouteItem>]
        wrappers = path.quoteIteration(for: direction).reduce([]) { prevWrappers, edge in
            let prevWrapper = prevWrappers.last

            let quoteWrapper: CompoundOperationWrapper<Balance> = OperationCombiningService.compoundNonOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) {
                let prevRouteItem = try prevWrapper?.targetOperation.extractNoCancellableResultData()

                let wrapper = edge.quote(amount: prevRouteItem?.quote ?? amount, direction: direction)

                return wrapper
            }

            if let prevWrapper {
                quoteWrapper.addDependency(wrapper: prevWrapper)
            }

            let mappingOperation = ClosureOperation<AssetExchangeRouteItem> {
                let quote = try quoteWrapper.targetOperation.extractNoCancellableResultData()
                let prevQuoteItem = try prevWrapper?.targetOperation.extractNoCancellableResultData()

                return AssetExchangeRouteItem(
                    edge: edge,
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
        let routeWrappers = possiblePaths.map { createQuote(for: $0, amount: amount, direction: direction) }

        let winnerCalculator = ClosureOperation<AssetExchangeRoute?> {
            let exchangeRoutes: [AssetExchangeRoute] = try routeWrappers.map { routeWrapper in
                try routeWrapper.targetOperation.extractNoCancellableResultData()
            }

            switch direction {
            case .sell:
                return exchangeRoutes.max(by: { $0.quote < $1.quote })
            case .buy:
                return exchangeRoutes.min(by: { $0.quote < $1.quote })
            }
        }

        let dependencies = routeWrappers
            .compactMap { $0 }
            .flatMap(\.allOperations)

        dependencies.forEach { winnerCalculator.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: winnerCalculator, dependencies: dependencies)
    }
}
