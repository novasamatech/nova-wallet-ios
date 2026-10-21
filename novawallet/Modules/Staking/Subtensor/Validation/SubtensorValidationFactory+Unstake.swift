import BigInt
import Foundation

extension SubtensorValidationFactory {
    func positionsAreFresh(
        syncFailed: Bool,
        locale: Locale,
        onRetry: @escaping () -> Void
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentStalePositions(view, onRetry: onRetry, locale: locale)
        }, preservesCondition: {
            !syncFailed
        })
    }

    func groupHotkeysLoaded(
        _ loaded: Bool,
        locale: Locale,
        onRetry: @escaping () -> Void
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentPreflightNotReceived(view, onRetry: onRetry, locale: locale)
        }, preservesCondition: {
            loaded
        })
    }

    func sellPlanAllows(
        _ input: SubtensorSellPlanInput?,
        assetDisplayInfo: AssetBalanceDisplayInfo?,
        onUnstakeAll: (() -> Void)?,
        locale: Locale
    ) -> DataValidating {
        guard let input else {
            return createSellExceedsAvailable(
                maxSell: 0,
                assetDisplayInfo: assetDisplayInfo,
                locale: locale
            )
        }

        switch SubtensorAmountPolicy.sellPlan(for: input) {
        case .sellAll, .partial:
            return ErrorConditionViolation(onError: {}, preservesCondition: { true })
        case .exceedsAvailable:
            return createSellExceedsAvailable(
                maxSell: SubtensorAmountPolicy.maxSell(
                    positionAlpha: input.positionAlpha,
                    availability: input.availability
                ),
                assetDisplayInfo: assetDisplayInfo,
                locale: locale
            )
        case .belowMinimumOut:
            return createSellBelowMinimumOut(minStake: input.minStake, locale: locale)
        case .remainderWouldBeSwept:
            return createSweptRemainderWarning(for: input, onUnstakeAll: onUnstakeAll, locale: locale)
        case .remainderWouldBeErased:
            return createErasedRemainderError(for: input, locale: locale)
        }
    }

    func rootUnlockIntervalElapsed(
        currentBlock: BlockNumber?,
        lastStakeBlock: UInt64?,
        unlockInterval: UInt64?,
        blockTime: BlockTime,
        locale: Locale
    ) -> DataValidating {
        let hold = SubtensorRootHold(interval: unlockInterval ?? 0, lastStakeBlock: lastStakeBlock ?? 0)
        let remainingBlocks = hold.remainingBlocks(at: currentBlock.map { UInt64($0) } ?? 0)

        return errorCondition(presenting: { factory, view in
            let remainingTime = TimeInterval(remainingBlocks) * blockTime.timeInterval

            factory.presentable.presentUnstakeLocked(
                view,
                eta: remainingTime.localizedDaysHoursOrFallbackMinutes(for: locale),
                locale: locale
            )
        }, preservesCondition: {
            guard (unlockInterval ?? 0) > 0, lastStakeBlock != nil else {
                return true
            }

            return currentBlock != nil && remainingBlocks == 0
        })
    }
}

private extension SubtensorValidationFactory {
    func createSellExceedsAvailable(
        maxSell: Balance,
        assetDisplayInfo: AssetBalanceDisplayInfo?,
        locale: Locale
    ) -> DataValidating {
        errorCondition(presenting: { factory, view in
            factory.presentable.presentSellExceedsAvailable(
                view,
                available: factory.formatAmount(maxSell, assetDisplayInfo: assetDisplayInfo, locale: locale),
                locale: locale
            )
        }, preservesCondition: {
            false
        })
    }

    func createSellBelowMinimumOut(minStake: Balance, locale: Locale) -> DataValidating {
        errorCondition(presenting: { factory, view in
            factory.presentable.presentSellBelowMinimum(
                view,
                minimum: factory.formatAmount(minStake, locale: locale),
                locale: locale
            )
        }, preservesCondition: {
            false
        })
    }

    func createSweptRemainderWarning(
        for input: SubtensorSellPlanInput,
        onUnstakeAll: (() -> Void)?,
        locale: Locale
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let self, let view else {
                return
            }

            presentable.presentDustRemainderWarning(
                view,
                remainder: formatAmount(input.remainderTaoValue, locale: locale),
                minStake: formatAmount(input.nominatorMinStake, locale: locale),
                action: {
                    delegate.didCompleteWarningHandling()
                },
                unstakeAllAction: onUnstakeAll,
                locale: locale
            )
        }, preservesCondition: {
            false
        })
    }

    func createErasedRemainderError(for input: SubtensorSellPlanInput, locale: Locale) -> DataValidating {
        errorCondition(presenting: { factory, view in
            factory.presentable.presentRemainderLocked(
                view,
                remainder: factory.formatAmount(input.remainderTaoValue, locale: locale),
                minStake: factory.formatAmount(input.nominatorMinStake, locale: locale),
                locale: locale
            )
        }, preservesCondition: {
            false
        })
    }
}

private extension SubtensorSellPlanInput {
    var remainderTaoValue: Balance {
        let remainder = positionAlpha > requestedAlpha ? positionAlpha - requestedAlpha : 0

        return remainder * sellLimitPrice / SubtensorPallet.alphaPriceScale
    }
}
