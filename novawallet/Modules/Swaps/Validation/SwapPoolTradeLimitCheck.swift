import Foundation
import Operation_iOS

enum SwapPoolTradeLimitCheck: Equatable {
    case withinLimits
    case belowMinimum(AssetExchangeTradeMinimumFailure)
    case blocked(AssetExchangeTradeLimitFailure?)
    case minBalanceUnavailable
}

typealias SwapBalanceExistenceWrapperFactory = (Set<ChainAssetId>)
    throws -> CompoundOperationWrapper<[ChainAssetId: AssetBalanceExistence]>

extension AssetExchangeRoute {
    func poolTradeLimitCheckWrapper(
        slippage: BigRational,
        balanceExistenceWrapperFactory: SwapBalanceExistenceWrapperFactory
    ) -> CompoundOperationWrapper<SwapPoolTradeLimitCheck> {
        let routerDeposits: [AssetExchangeRouterDeposit]

        do {
            routerDeposits = try routerAccountDeposits(slippage: slippage)
        } catch {
            return .createWithError(error)
        }

        let balanceExistenceWrapper: CompoundOperationWrapper<[ChainAssetId: AssetBalanceExistence]>

        do {
            balanceExistenceWrapper = try balanceExistenceWrapperFactory(
                Set(routerDeposits.map(\.asset.chainAssetId))
            )
        } catch {
            balanceExistenceWrapper = .createWithError(error)
        }

        let verdictWrappers = items.map { item in
            item.edge.tradeLimitVerdict(amount: item.amount, direction: direction)
        }

        let mergeOperation = ClosureOperation<SwapPoolTradeLimitCheck> {
            let verdicts = try verdictWrappers.map { try $0.targetOperation.extractNoCancellableResultData() }

            let minBalances: [ChainAssetId: Balance]

            do {
                minBalances = try balanceExistenceWrapper.targetOperation
                    .extractNoCancellableResultData()
                    .mapValues(\.minBalance)
            } catch {
                return .minBalanceUnavailable
            }

            return self.poolTradeLimitCheck(
                verdicts: verdicts,
                routerDeposits: routerDeposits,
                minBalances: minBalances
            )
        }

        let dependencies = verdictWrappers.flatMap(\.allOperations) + balanceExistenceWrapper.allOperations

        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}

private struct SwapPoolTradeShortfall {
    let limitedAsset: ChainAsset?
    let minimumAmount: Balance
    let isUserAmount: Bool
}

private extension AssetExchangeRoute {
    func poolTradeLimitCheck(
        verdicts: [AssetExchangeTradeLimitVerdict],
        routerDeposits: [AssetExchangeRouterDeposit],
        minBalances: [ChainAssetId: Balance]
    ) -> SwapPoolTradeLimitCheck {
        for (index, verdict) in verdicts.enumerated() {
            let hopDeposits = routerDeposits.filter { $0.itemIndex == index }

            var shortfalls = hopDeposits
                .filter { $0.side == .hopIn }
                .compactMap { shortfall(for: $0, minBalances: minBalances) }

            switch verdict {
            case .withinLimit:
                break
            case let .belowMinimum(limitShortfall):
                shortfalls.append(
                    SwapPoolTradeShortfall(
                        limitedAsset: limitShortfall.limitedAsset,
                        minimumAmount: limitShortfall.minTradingLimit,
                        isUserAmount: isUserAmountHop(at: index)
                    )
                )
            case let .exceeds(breach):
                if shortfalls.isEmpty {
                    return blockedCheck(for: breach, isUserInputAdjustable: isUserAmountHop(at: index))
                }
            }

            shortfalls += hopDeposits
                .filter { $0.side == .hopOut }
                .compactMap { shortfall(for: $0, minBalances: minBalances) }

            if let failure = minimumFailure(from: shortfalls) {
                return .belowMinimum(failure)
            }
        }

        return .withinLimits
    }

    func isUserAmountHop(at index: Int) -> Bool {
        switch direction {
        case .sell:
            return index == 0
        case .buy:
            return index == items.count - 1
        }
    }

    func isUserAmount(_ deposit: AssetExchangeRouterDeposit) -> Bool {
        let userSide: AssetExchangeRouterDeposit.Side = direction == .sell ? .hopIn : .hopOut

        return deposit.side == userSide && isUserAmountHop(at: deposit.itemIndex)
    }

    func shortfall(
        for deposit: AssetExchangeRouterDeposit,
        minBalances: [ChainAssetId: Balance]
    ) -> SwapPoolTradeShortfall? {
        let minBalance = minBalances[deposit.asset.chainAssetId] ?? 0

        guard deposit.amount < minBalance else {
            return nil
        }

        return SwapPoolTradeShortfall(
            limitedAsset: deposit.asset,
            minimumAmount: minBalance,
            isUserAmount: isUserAmount(deposit)
        )
    }

    func minimumFailure(from shortfalls: [SwapPoolTradeShortfall]) -> AssetExchangeTradeMinimumFailure? {
        guard let first = shortfalls.first else {
            return nil
        }

        guard first.isUserAmount else {
            return AssetExchangeTradeMinimumFailure(
                limitedAsset: first.limitedAsset,
                minimumAmount: first.minimumAmount,
                direction: direction,
                isUserInputAdjustable: false
            )
        }

        let userShortfalls = shortfalls.filter(\.isUserAmount)

        return AssetExchangeTradeMinimumFailure(
            limitedAsset: userShortfalls.compactMap(\.limitedAsset).first,
            minimumAmount: userShortfalls.map(\.minimumAmount).max() ?? first.minimumAmount,
            direction: direction,
            isUserInputAdjustable: true
        )
    }

    func blockedCheck(
        for breach: AssetExchangeTradeLimitBreach,
        isUserInputAdjustable: Bool
    ) -> SwapPoolTradeLimitCheck {
        guard let limitedAsset = breach.limitedAsset else {
            return .blocked(nil)
        }

        return .blocked(
            AssetExchangeTradeLimitFailure(
                limitedAsset: limitedAsset,
                maxGivenAmount: breach.maxGivenAmount,
                minTradingLimit: breach.minTradingLimit,
                direction: direction,
                isUserInputAdjustable: isUserInputAdjustable
            )
        )
    }
}
