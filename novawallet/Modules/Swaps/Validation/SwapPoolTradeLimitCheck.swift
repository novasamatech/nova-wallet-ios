import Foundation
import Operation_iOS

/// The answer the pool-trade-limit validation acts on.
///
/// `.blocked(nil)` is a real outcome, not a degenerate one: an Omnipool violation whose cap could not
/// be derived still stops the swap, it just cannot name a number (FR-16). Splitting "does this block"
/// from "can it be described" is what keeps the optionality out of the fields
/// `AssetExchangeTradeLimitFailure` reports with — that type exists only when the failure is fully
/// reportable, so its `limitedAsset` and `maxGivenAmount` are never absent.
enum SwapPoolTradeLimitCheck: Equatable {
    case withinLimits
    case blocked(AssetExchangeTradeLimitFailure?)
}

extension AssetExchangeRoute {
    /// Asks each trade-limited hop whether its pallet would reject that hop's *given* amount, and stops
    /// at the first that would.
    ///
    /// `item.amount` is the given amount — the input for a sell, the output for a buy — because of how
    /// each item was built, not because of where it sits: it is whatever was handed to that hop's quote
    /// call, which is why `amountIn(for: .sell) == amount` and `amountOut(for: .buy) == amount`.
    ///
    /// `items` is in *path* order in both directions. `AssetsExchangeRouteManager` quotes in
    /// `quoteIteration` order — reversed for a buy — but `byAddingNext` prepends for a buy, which puts
    /// them back the way the path runs; `amountIn` reading `items.first` relies on the same thing. Path
    /// order is what makes the hop quoted from the user's own number the first for a sell and the last
    /// for a buy: Android's `isUserInputAdjustable` rule without the direction arithmetic.
    func poolTradeLimitCheckWrapper() -> CompoundOperationWrapper<SwapPoolTradeLimitCheck> {
        let verdictWrappers = items.map { item in
            item.edge.tradeLimitVerdict(amount: item.amount, direction: direction)
        }

        let routeDirection = direction
        let lastIndex = items.count - 1

        let mergeOperation = ClosureOperation<SwapPoolTradeLimitCheck> {
            for (index, verdictWrapper) in verdictWrappers.enumerated() {
                guard let verdictWrapper else {
                    continue
                }

                let verdict = try verdictWrapper.targetOperation.extractNoCancellableResultData()

                guard case let .exceeds(breach) = verdict else {
                    continue
                }

                let isUserInputAdjustable = switch routeDirection {
                case .sell: index == 0
                case .buy: index == lastIndex
                }

                guard
                    let limitedAsset = breach.limitedAsset,
                    let maxGivenAmount = breach.maxGivenAmount else {
                    return .blocked(nil)
                }

                return .blocked(
                    AssetExchangeTradeLimitFailure(
                        limitedAsset: limitedAsset,
                        maxGivenAmount: maxGivenAmount,
                        minTradingLimit: breach.minTradingLimit,
                        direction: routeDirection,
                        isUserInputAdjustable: isUserInputAdjustable
                    )
                )
            }

            return .withinLimits
        }

        let dependencies = verdictWrappers.compactMap { $0 }.flatMap(\.allOperations)

        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}
