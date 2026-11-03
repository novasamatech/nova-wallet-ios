import Foundation
import Operation_iOS

enum SwapPoolTradeLimitCheck: Equatable {
    case withinLimits
    case belowMinimum(AssetExchangeTradeMinimumFailure)
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

                let isUserInputAdjustable = switch routeDirection {
                case .sell: index == 0
                case .buy: index == lastIndex
                }

                if case let .belowMinimum(shortfall) = verdict {
                    return .belowMinimum(
                        AssetExchangeTradeMinimumFailure(
                            limitedAsset: shortfall.limitedAsset,
                            minTradingLimit: shortfall.minTradingLimit,
                            direction: routeDirection,
                            isUserInputAdjustable: isUserInputAdjustable
                        )
                    )
                }

                guard case let .exceeds(breach) = verdict else {
                    continue
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
