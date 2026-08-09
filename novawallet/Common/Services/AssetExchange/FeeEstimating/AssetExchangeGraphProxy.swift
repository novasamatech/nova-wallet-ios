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

        // This manager prices a network fee being converted into a non-native fee asset, always
        // with direction == .buy — the exact branch the gross-up modifies. A policy here would
        // multiply every fee routed through a Hydration path by 1/(1 - 0.85%), inflating a fee the
        // user actually pays over a route on which no commission is ever taken.
        let routeManager = AssetsExchangeRouteManager(
            possiblePaths: possiblePaths,
            pathCostEstimator: pathCostEstimator,
            commissionPolicy: nil,
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
