import Foundation
import Operation_iOS

enum AssetExchangeGraphProxyError: Error {
    case noGraph
    case noRoute(AssetConversion.QuoteArgs)
}

final class AssetExchangeGraphProxy {
    private weak var actualGraph: AssetsExchangeGraphProtocol?
    let operationQueue: OperationQueue
    let pathCostEstimator: AssetsExchangePathCostEstimating
    let logger: LoggerProtocol
    let maxQuotePaths: Int

    init(
        actualGraph: AssetsExchangeGraphProtocol? = nil,
        maxQuotePaths: Int = AssetsExchange.maxQuotePaths,
        pathCostEstimator: AssetsExchangePathCostEstimating,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.actualGraph = actualGraph
        self.maxQuotePaths = maxQuotePaths
        self.pathCostEstimator = pathCostEstimator
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func install(graph: AssetsExchangeGraphProtocol) {
        actualGraph = graph
    }
}

extension AssetExchangeGraphProxy: AssetQuoteFactoryProtocol {
    func quote(for args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetConversion.Quote> {
        guard let actualGraph = actualGraph else {
            return .createWithError(AssetExchangeGraphProxyError.noGraph)
        }

        let possiblePaths = actualGraph.fetchPaths(
            from: args.assetIn,
            to: args.assetOut,
            maxTopPaths: maxQuotePaths
        )

        let routeManager = AssetsExchangeRouteManager(
            possiblePaths: possiblePaths,
            pathCostEstimator: pathCostEstimator,
            operationQueue: operationQueue,
            logger: logger
        )

        let bestRouteWrapper = routeManager.fetchRoute(for: args.amount, direction: args.direction)

        let mappingOperation = ClosureOperation<AssetConversion.Quote> {
            guard let route = try bestRouteWrapper.targetOperation.extractNoCancellableResultData() else {
                throw AssetExchangeGraphProxyError.noRoute(args)
            }

            return .init(args: args, amount: route.quote, context: nil)
        }

        mappingOperation.addDependency(bestRouteWrapper.targetOperation)

        return bestRouteWrapper.insertingTail(operation: mappingOperation)
    }
}
