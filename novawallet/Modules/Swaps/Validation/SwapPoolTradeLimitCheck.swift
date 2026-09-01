import Foundation
import Operation_iOS

enum SwapPoolTradeLimitCheck: Equatable {
    case withinLimits
    case blocked(AssetExchangeTradeLimitFailure?)
}

extension AssetExchangeRoute {
    func poolTradeLimitCheckWrapper() -> CompoundOperationWrapper<SwapPoolTradeLimitCheck> {
        let verdictWrappers = items.map { item in
            item.edge.tradeLimitVerdict(amount: item.amount, direction: direction)
        }

        let routeDirection = direction
        let lastIndex = items.count - 1

        let mergeOperation = ClosureOperation<SwapPoolTradeLimitCheck> {
            for (index, verdictWrapper) in verdictWrappers.enumerated() {
                let verdict = try verdictWrapper.targetOperation.extractNoCancellableResultData()

                guard case let .exceeds(breach) = verdict else {
                    continue
                }

                let isUserInputAdjustable = switch routeDirection {
                case .sell: index == 0
                case .buy: index == lastIndex
                }

                guard let limitedAsset = breach.limitedAsset else {
                    return .blocked(nil)
                }

                return .blocked(
                    AssetExchangeTradeLimitFailure(
                        limitedAsset: limitedAsset,
                        maxGivenAmount: breach.maxGivenAmount,
                        minTradingLimit: breach.minTradingLimit,
                        direction: routeDirection,
                        isUserInputAdjustable: isUserInputAdjustable
                    )
                )
            }

            return .withinLimits
        }

        let dependencies = verdictWrappers.flatMap(\.allOperations)

        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}
