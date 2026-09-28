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

    func canPayBatchedNetworkFee(
        transferable: Balance?,
        networkFee: Balance?,
        existentialDeposit: Balance?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            let requiredAmount = (networkFee ?? 0) + (existentialDeposit ?? 0)

            presentable.presentBatchedSellFeeNotCovered(
                view,
                requiredAmount: formatRequiredAmount(requiredAmount, locale: locale),
                locale: locale
            )
        }, preservesCondition: {
            guard let networkFee else {
                return true
            }

            guard let transferable, let existentialDeposit else {
                return false
            }

            return SubtensorAmountPolicy.canPayBatchedSell(
                transferable: transferable,
                networkFee: networkFee,
                existentialDeposit: existentialDeposit
            )
        })
    }

    func canPayFeeFromStakeOtherwiseWarns(
        transferable: Balance?,
        fee: Balance?,
        locale: Locale
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let self, let view else {
                return
            }

            presentable.presentFeeFromStakeWarning(
                view,
                fee: formatAmount(fee ?? 0, locale: locale),
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            guard let fee else {
                return true
            }

            return (transferable ?? 0) >= fee
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
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            let elapsed = currentBlock.map { UInt64($0).subtractOrZero(lastStakeBlock ?? 0) } ?? 0
            let remainingBlocks = (unlockInterval ?? 0).subtractOrZero(elapsed)
            let remainingTime = (TimeInterval(remainingBlocks) * TimeInterval(blockTime)).seconds

            presentable.presentUnstakeLocked(
                view,
                eta: remainingTime.localizedDaysHoursOrFallbackMinutes(for: locale),
                locale: locale
            )
        }, preservesCondition: {
            guard let unlockInterval, unlockInterval > 0, let lastStakeBlock else {
                return true
            }

            guard let currentBlock else {
                return false
            }

            return UInt64(currentBlock).subtractOrZero(lastStakeBlock) >= unlockInterval
        })
    }

    func claimFeeCoveredByTransferable(
        transferable: Balance?,
        fee: Balance?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentClaimFeeNotAvailable(
                view,
                fee: formatAmount(fee ?? 0, locale: locale),
                locale: locale
            )
        }, preservesCondition: {
            guard let fee else {
                return true
            }

            return (transferable ?? 0) >= fee
        })
    }

    func claimableAtLeastThreshold(
        claimable: Balance?,
        threshold: Balance?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentClaimBelowThreshold(
                view,
                threshold: formatAmount(threshold ?? 0, locale: locale),
                locale: locale
            )
        }, preservesCondition: {
            guard let claimable, claimable > 0 else {
                return false
            }

            return claimable >= (threshold ?? 0)
        })
    }
}

private extension SubtensorStakingValidationFactory {
    func createSellExceedsAvailable(
        maxSell: Balance,
        assetDisplayInfo: AssetBalanceDisplayInfo?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentUnstakeExceedsAvailable(
                view,
                available: formatAmount(maxSell, assetDisplayInfo: assetDisplayInfo, locale: locale),
                locale: locale
            )
        }, preservesCondition: {
            false
        })
    }

    func createSellBelowMinimumOut(minStake: Balance, locale: Locale) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentUnstakeAmountTooLow(
                view,
                minAmount: formatAmount(minStake, locale: locale),
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
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentLockedRemainder(
                view,
                remainder: formatAmount(input.remainderTaoValue, locale: locale),
                minStake: formatAmount(input.nominatorMinStake, locale: locale),
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

        return remainder * sellLimitPrice / SubtensorStakingPallet.alphaPriceScale
    }
}

private extension UInt64 {
    func subtractOrZero(_ other: UInt64) -> UInt64 {
        self >= other ? self - other : 0
    }
}
