import BigInt
import Foundation

extension SubtensorStakingValidationFactory {
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

        return errorCondition(locale: locale, alert: { _, strings in
            let remainingTime = TimeInterval(remainingBlocks) * blockTime.timeInterval
            let eta = remainingTime.localizedDaysHoursOrFallbackMinutes(for: locale)

            return (strings.stakingSubtensorUnstakeLockedTitle(), strings.stakingSubtensorUnstakeLockedMessage(eta))
        }, preservesCondition: {
            guard (unlockInterval ?? 0) > 0, lastStakeBlock != nil else {
                return true
            }

            return currentBlock != nil && remainingBlocks == 0
        })
    }
}

private extension SubtensorStakingValidationFactory {
    func createSellExceedsAvailable(
        maxSell: Balance,
        assetDisplayInfo: AssetBalanceDisplayInfo?,
        locale: Locale
    ) -> DataValidating {
        errorCondition(locale: locale, alert: { factory, strings in
            let available = factory.formatAmount(maxSell, assetDisplayInfo: assetDisplayInfo, locale: locale)

            return (strings.commonAmountTooBig(), strings.stakingSubtensorUnstakeExceedsAvailableMessage(available))
        }, preservesCondition: {
            false
        })
    }

    func createSellBelowMinimumOut(minStake: Balance, locale: Locale) -> DataValidating {
        errorCondition(locale: locale, alert: { factory, strings in
            let minimum = factory.formatAmount(minStake, locale: locale)

            return (strings.amountTooLow(), strings.stakingSubtensorUnstakeTooLowMessage(minimum))
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
        errorCondition(locale: locale, alert: { factory, strings in
            let remainder = factory.formatAmount(input.remainderTaoValue, locale: locale)
            let minStake = factory.formatAmount(input.nominatorMinStake, locale: locale)

            return (
                strings.stakingSubtensorRemainderLockedTitle(),
                strings.stakingSubtensorRemainderLockedMessage(remainder, minStake)
            )
        }, preservesCondition: {
            false
        })
    }
}

private extension SubtensorSellPlanInput {
    var remainderTaoValue: Balance {
        let remainder = positionAlpha > requestedAlpha ? positionAlpha - requestedAlpha : 0

        return remainder * sellLimitPrice / SubtensorStakingPallet.alphaPriceScale
    }
}
