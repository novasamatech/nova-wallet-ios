import BigInt
import Foundation
import Foundation_iOS

final class SubtensorStakingValidationFactory {
    weak var view: ControllerBackedProtocol?

    var basePresentable: BaseErrorPresentable {
        presentable
    }

    let presentable: SubtensorStakingErrorPresentable
    let assetDisplayInfo: AssetBalanceDisplayInfo
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol

    private(set) lazy var balanceViewModelFactory: BalanceViewModelFactoryProtocol = BalanceViewModelFactory(
        targetAssetInfo: assetDisplayInfo,
        priceAssetInfoFactory: priceAssetInfoFactory
    )

    private lazy var balanceViewModelFacade = BalanceViewModelFactoryFacade(
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

    private func formatAmount(
        _ value: Balance,
        assetDisplayInfo: AssetBalanceDisplayInfo?,
        locale: Locale
    ) -> String {
        guard let assetDisplayInfo, assetDisplayInfo != self.assetDisplayInfo else {
            return formatAmount(value, locale: locale)
        }

        let decimal = Decimal.fromSubstrateAmount(
            value,
            precision: assetDisplayInfo.assetPrecision
        ) ?? 0

        return balanceViewModelFacade.amountFromValue(
            targetAssetInfo: assetDisplayInfo,
            value: decimal
        ).value(for: locale)
    }

    private func formatImpact(_ impact: BigRational, locale: Locale) -> String {
        let formatter = NumberFormatter.percentSingle
        formatter.locale = locale

        return formatter.stringFromDecimal(impact.decimalOrZeroValue) ?? ""
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

    func hasFreshQuote(
        _ quote: SubtensorQuote?,
        for args: SubtensorQuoteArgs?,
        locale: Locale,
        onRetry: @escaping () -> Void
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentQuoteMissing(view, onRetry: onRetry, locale: locale)
        }, preservesCondition: {
            guard let args, let quote, quote.args == args else {
                return false
            }

            return Date().timeIntervalSince(quote.capturedAt) <=
                SubtensorStakingFlowConstants.quoteStalenessWindow
        })
    }

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

    func orderWithinSlippageTolerance(
        quote: SubtensorQuote?,
        limitPrice: Balance?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentOrderBeyondTolerance(view, locale: locale)
        }, preservesCondition: {
            guard
                let quote,
                let limitPrice,
                let implied = quote.impliedExecutionPrice else {
                return true
            }

            // the chain gates on the marginal pool price; an average execution price at or
            // beyond the limit means the order's own size already breaks the tolerance
            switch quote.args.direction {
            case .stake:
                return implied < limitPrice
            case .unstake:
                return implied > limitPrice
            }
        })
    }

    func priceImpactAcceptable(
        quote: SubtensorQuote?,
        locale: Locale
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let self, let view else {
                return
            }

            let impact = quote?.priceImpact ?? BigRational(numerator: 0, denominator: 1)

            presentable.presentHighPriceImpact(
                view,
                impact: formatImpact(impact, locale: locale),
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            guard let impact = quote?.priceImpact else {
                return true
            }

            return !SubtensorStakingFlowConstants.isHighPriceImpact(impact)
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
        netuid _: UInt16,
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
            subnetExists == true && subtokenEnabled == true
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
        assetDisplayInfo: AssetBalanceDisplayInfo?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentUnstakeExceedsAvailable(
                view,
                available: formatAmount(
                    available ?? 0,
                    assetDisplayInfo: assetDisplayInfo,
                    locale: locale
                ),
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
        onUnstakeAll: (() -> Void)?,
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
                // deliberately does not resume the stopped run: the amount the runner
                // captured is the dust one, so the form has to be re-entered instead
                unstakeAllAction: onUnstakeAll,
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
