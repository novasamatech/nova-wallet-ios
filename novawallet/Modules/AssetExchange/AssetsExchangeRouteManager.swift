import Foundation
import Operation_iOS

final class AssetsExchangeRouteManager {
    let possiblePaths: [AssetExchangeGraphPath]
    let chainRegistry: ChainRegistryProtocol
    let priceStore: AssetExchangePriceStoring
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        possiblePaths: [AssetExchangeGraphPath],
        chainRegistry: ChainRegistryProtocol,
        priceStore: AssetExchangePriceStoring,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.possiblePaths = possiblePaths
        self.chainRegistry = chainRegistry
        self.priceStore = priceStore
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func createQuote(
        for path: AssetExchangeQuotePath,
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

                let wrapper = item.edge.quote(amount: prevRouteItem?.quote ?? amount, direction: direction)

                return wrapper
            }

            if let prevWrapper {
                quoteWrapper.addDependency(wrapper: prevWrapper)
            }

            let mappingOperation = ClosureOperation<AssetExchangeRouteItem> {
                let quote = try quoteWrapper.targetOperation.extractNoCancellableResultData()
                let prevQuoteItem = try prevWrapper?.targetOperation.extractNoCancellableResultData()

                return AssetExchangeRouteItem(
                    pathItem: item,
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

    private func prepareQuotePaths() -> [AssetExchangeQuotePath] {
        possiblePaths.compactMap { graphPath in
            let quotePath: AssetExchangeQuotePath = graphPath.compactMap { edge in
                guard
                    let chainIn = chainRegistry.getChain(for: edge.origin.chainId),
                    let chainAssetIn = chainIn.chainAsset(for: edge.origin.assetId),
                    let chainOut = chainRegistry.getChain(for: edge.destination.chainId),
                    let chainAssetOut = chainOut.chainAsset(for: edge.destination.assetId) else {
                    return nil
                }

                return AssetExchangeQuotePathItem(
                    edge: edge,
                    assetIn: chainAssetIn,
                    assetOut: chainAssetOut,
                    priceIn: priceStore.fetchPrice(for: chainAssetIn.chainAssetId),
                    priceOut: priceStore.fetchPrice(for: chainAssetOut.chainAssetId)
                )
            }

            guard quotePath.count == graphPath.count else {
                return nil
            }

            return quotePath
        }
    }
}

extension AssetsExchangeRouteManager {
    func fetchRoute(
        for amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<AssetExchangeRoute?> {
        let quotePaths = prepareQuotePaths()
        let routeWrappers = quotePaths.map { createQuote(for: $0, amount: amount, direction: direction) }

        let winnerCalculator = ClosureOperation<AssetExchangeRoute?> {
            let exchangeRoutes: [AssetExchangeRoute] = routeWrappers.compactMap { routeWrapper in
                try? routeWrapper.targetOperation.extractNoCancellableResultData()
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
