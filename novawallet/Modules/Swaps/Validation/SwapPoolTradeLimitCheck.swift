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
        let routerDeposits: [AssetExchangeRouterHopDeposits]

        do {
            routerDeposits = try routerAccountDeposits(slippage: slippage)
        } catch {
            return .createWithError(error)
        }

        let balanceExistenceWrapper: CompoundOperationWrapper<[ChainAssetId: AssetBalanceExistence]>

        do {
            balanceExistenceWrapper = try balanceExistenceWrapperFactory(
                Set(routerDeposits.flatMap { [$0.hopIn?.assetId, $0.hopOut?.assetId].compactMap { $0 } })
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
                return self.poolLimitCheckWithoutMinBalances(verdicts: verdicts, routerDeposits: routerDeposits)
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

private extension AssetExchangeRoute {
    func poolTradeLimitCheck(
        verdicts: [AssetExchangeTradeLimitVerdict],
        routerDeposits: [AssetExchangeRouterHopDeposits],
        minBalances: [ChainAssetId: Balance]
    ) -> SwapPoolTradeLimitCheck {
        for (index, (verdict, deposits)) in zip(verdicts, routerDeposits).enumerated() {
            let isUserHop = isUserAmountHop(at: index)

            var shortfalls = [
                shortfall(of: deposits.hopIn, isUserAmount: isUserHop && direction == .sell, minBalances: minBalances)
            ].compactMap { $0 }

            switch verdict {
            case .withinLimit:
                break
            case let .belowMinimum(minTradingLimit):
                shortfalls.append(
                    AssetExchangeTradeMinimumFailure(
                        minimumAmount: minTradingLimit,
                        direction: direction,
                        isUserInputAdjustable: isUserHop
                    )
                )
            case let .exceeds(breach):
                if shortfalls.isEmpty {
                    return blockedCheck(for: breach, isUserInputAdjustable: isUserHop)
                }
            }

            shortfalls += [
                shortfall(of: deposits.hopOut, isUserAmount: isUserHop && direction == .buy, minBalances: minBalances)
            ].compactMap { $0 }

            if let failure = minimumFailure(from: shortfalls) {
                return .belowMinimum(failure)
            }
        }

        return .withinLimits
    }

    func poolLimitCheckWithoutMinBalances(
        verdicts: [AssetExchangeTradeLimitVerdict],
        routerDeposits: [AssetExchangeRouterHopDeposits]
    ) -> SwapPoolTradeLimitCheck {
        let poolLimitCheck = poolTradeLimitCheck(verdicts: verdicts, routerDeposits: routerDeposits, minBalances: [:])

        return poolLimitCheck == .withinLimits ? .minBalanceUnavailable : poolLimitCheck
    }

    func isUserAmountHop(at index: Int) -> Bool {
        switch direction {
        case .sell:
            return index == 0
        case .buy:
            return index == items.count - 1
        }
    }

    func shortfall(
        of deposit: AssetExchangeRouterDeposit?,
        isUserAmount: Bool,
        minBalances: [ChainAssetId: Balance]
    ) -> AssetExchangeTradeMinimumFailure? {
        guard let deposit, let minBalance = minBalances[deposit.assetId], deposit.amount < minBalance else {
            return nil
        }

        return AssetExchangeTradeMinimumFailure(
            minimumAmount: minBalance,
            direction: direction,
            isUserInputAdjustable: isUserAmount
        )
    }

    func minimumFailure(from shortfalls: [AssetExchangeTradeMinimumFailure]) -> AssetExchangeTradeMinimumFailure? {
        shortfalls.filter(\.isUserInputAdjustable).max { $0.minimumAmount < $1.minimumAmount } ?? shortfalls.first
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
