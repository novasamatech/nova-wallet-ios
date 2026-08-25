import BigInt
import Foundation
import Foundation_iOS

final class SubtensorStakingValidationFactory {
    weak var view: ControllerBackedProtocol?

    var basePresentable: BaseErrorPresentable { presentable }

    let presentable: SubtensorStakingErrorPresentable
    let assetDisplayInfo: AssetBalanceDisplayInfo
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol

    private(set) lazy var balanceViewModelFactory: BalanceViewModelFactoryProtocol = BalanceViewModelFactory(
        targetAssetInfo: assetDisplayInfo,
        priceAssetInfoFactory: priceAssetInfoFactory
    )

    init(
        presentable: SubtensorStakingErrorPresentable,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) {
        self.presentable = presentable
        self.assetDisplayInfo = assetDisplayInfo
        self.priceAssetInfoFactory = priceAssetInfoFactory
    }

    private func formatAmount(_ value: Balance, locale: Locale) -> String {
        let decimal = Decimal.fromSubstrateAmount(
            value,
            precision: assetDisplayInfo.assetPrecision
        ) ?? 0

        return balanceViewModelFactory.amountFromValue(decimal).value(for: locale)
    }
}

extension SubtensorStakingValidationFactory: SubtensorStakingValidationFactoryProtocol {
    func hasPreflight(
        _ preflight: SubtensorStakingPreflight?,
        locale: Locale,
        onRetry: @escaping () -> Void
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentPreflightNotReceived(view, onRetry: onRetry, locale: locale)
        }, preservesCondition: {
            preflight != nil
        })
    }

    func hasMinStakeAmount(
        amount: Balance?,
        minStake: Balance?,
        quotedSwapFee: Balance?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            let requiredAmount = (minStake ?? 0) + (quotedSwapFee ?? 0)

            presentable.presentStakeAmountTooLow(
                view,
                minStake: formatAmount(requiredAmount, locale: locale),
                locale: locale
            )
        }, preservesCondition: {
            guard let amount, let minStake else {
                return false
            }

            return amount >= minStake + (quotedSwapFee ?? 0)
        })
    }

    func retainsFeeReserveAfterStake(
        balance: Balance?,
        amount: Balance?,
        fee: Balance?,
        existentialDeposit: Balance?,
        locale: Locale
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let self, let view else {
                return
            }

            let reserve = (fee ?? 0) + (existentialDeposit ?? 0)

            presentable.presentStakeAllWarning(
                view,
                reserve: formatAmount(reserve, locale: locale),
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            guard let balance, let amount, let fee else {
                return true
            }

            let reserve = fee + (existentialDeposit ?? 0)

            return balance >= amount + fee + reserve
        })
    }

    func hotkeyIsRegistered(
        hotkeyExists: Bool?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentHotkeyNotFound(view, locale: locale)
        }, preservesCondition: {
            hotkeyExists == true
        })
    }

    func subnetStakingEnabled(
        netuid: UInt16,
        subnetExists: Bool?,
        subtokenEnabled: Bool?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentSubnetStakingDisabled(view, locale: locale)
        }, preservesCondition: {
            guard subnetExists == true else {
                return false
            }

            return netuid == SubtensorStakingPallet.rootNetuid || subtokenEnabled == true
        })
    }

    func noColdkeySwapInProgress(
        hasAnnouncement: Bool?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentColdkeySwapInProgress(view, locale: locale)
        }, preservesCondition: {
            hasAnnouncement == false
        })
    }

    func safeModeInactive(
        safeModeActive: Bool?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentSafeModeActive(view, locale: locale)
        }, preservesCondition: {
            safeModeActive == false
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

    func unstakeNotExceedsAvailable(
        amount: Balance?,
        available: Balance?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentUnstakeExceedsAvailable(
                view,
                available: formatAmount(available ?? 0, locale: locale),
                locale: locale
            )
        }, preservesCondition: {
            guard let amount, let available else {
                return false
            }

            return amount <= available
        })
    }

    func unstakeAboveMinTaoOut(
        taoOut: Balance?,
        minAmount: Balance?,
        isFullUnstake: Bool,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentUnstakeAmountTooLow(
                view,
                minAmount: formatAmount(minAmount ?? 0, locale: locale),
                locale: locale
            )
        }, preservesCondition: {
            guard !isFullUnstake else {
                return true
            }

            guard let taoOut, let minAmount else {
                return false
            }

            return taoOut >= minAmount
        })
    }

    func remainderNotBelowNominatorMin(
        remainder: Balance?,
        nominatorMinStake: Balance?,
        locale: Locale
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let self, let view else {
                return
            }

            presentable.presentDustRemainderWarning(
                view,
                remainder: formatAmount(remainder ?? 0, locale: locale),
                minStake: formatAmount(nominatorMinStake ?? 0, locale: locale),
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            guard let remainder, let nominatorMinStake, remainder > 0 else {
                return true
            }

            return remainder >= nominatorMinStake
        })
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

    func claimFirstAdvisory(
        claimable: Balance?,
        threshold: Balance?,
        locale: Locale
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let self, let view else {
                return
            }

            presentable.presentClaimFirstAdvisory(
                view,
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            guard let claimable, claimable > 0 else {
                return true
            }

            let effectiveThreshold = threshold ?? SubtensorStakingPallet.defaultRootClaimableThreshold

            return claimable < effectiveThreshold
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

private extension UInt64 {
    func subtractOrZero(_ other: UInt64) -> UInt64 {
        self >= other ? self - other : 0
    }
}
