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
    ) -> CompoundOperationWrapper<Balance>? {
        let directionPath = switch direction {
        case .sell:
            path
        case .buy:
            AssetExchangeGraphPath(path.reversed())
        }

        return directionPath.reduce(nil) { prevWrapper, edge in
            let quoteWrapper: CompoundOperationWrapper<Balance> = OperationCombiningService.compoundNonOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) {
                let prevQuote = try prevWrapper?.targetOperation.extractNoCancellableResultData()

                let wrapper = edge.quote(amount: prevQuote ?? amount, direction: direction)

                return wrapper
            }

            if let prevWrapper {
                quoteWrapper.addDependency(wrapper: prevWrapper)

                return quoteWrapper.insertingHead(operations: prevWrapper.allOperations)
            } else {
                return quoteWrapper
            }
        }
    }
}

extension AssetsExchangeRouteManager {
    func fetchRoute(
        for amount: Balance,
        direction: AssetConversion.Direction
    ) -> CompoundOperationWrapper<AssetExchangeRoute?> {
        let pathQuoteWrappers = possiblePaths.map { createQuote(for: $0, amount: amount, direction: direction) }

        let winnerCalculator = ClosureOperation<AssetExchangeRoute?> {
            let quotes: [Balance?] = pathQuoteWrappers.map { pathQuoteWrapper in
                do {
                    return try pathQuoteWrapper?.targetOperation.extractNoCancellableResultData()
                } catch {
                    self.logger.error("Quote failed: \(error)")
                    return nil
                }
            }

            let exchangeRoutes: [AssetExchangeRoute] = zip(self.possiblePaths, quotes).compactMap { pair in
                guard let quote = pair.1 else { return nil }
                return AssetExchangeRoute(path: pair.0, quote: quote)
            }

            switch direction {
            case .sell:
                return exchangeRoutes.max(by: { $0.quote < $1.quote })
            case .buy:
                return exchangeRoutes.min(by: { $0.quote < $1.quote })
            }
        }

        let dependencies = pathQuoteWrappers
            .compactMap { $0 }
            .flatMap(\.allOperations)

        dependencies.forEach { winnerCalculator.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: winnerCalculator, dependencies: dependencies)
    }
}
