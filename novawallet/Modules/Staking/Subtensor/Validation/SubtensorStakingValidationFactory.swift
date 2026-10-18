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

    func formatAmount(_ value: Balance, locale: Locale) -> String {
        let decimal = Decimal.fromSubstrateAmount(
            value,
            precision: assetDisplayInfo.assetPrecision
        ) ?? 0

        return balanceViewModelFactory.amountFromValue(decimal).value(for: locale)
    }

    func formatRequiredAmount(_ value: Balance, locale: Locale) -> String {
        let decimal = Decimal.fromSubstrateAmount(
            value,
            precision: assetDisplayInfo.assetPrecision
        ) ?? 0

        return balanceViewModelFactory.amountFromValue(decimal, roundingMode: .up).value(for: locale)
    }

    func formatAmount(
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

    private func displayedMinimumStake(requiredStake: Balance, includesNovaFee: Bool) -> Balance {
        guard includesNovaFee, let grossStake = try? SubtensorNovaFeeCalculator.grossUp(net: requiredStake) else {
            return requiredStake
        }

        return grossStake
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

    func subnetTradesAvailable(
        tradesUnavailable: Bool,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentSubnetTradesUnavailable(view, locale: locale)
        }, preservesCondition: {
            !tradesUnavailable
        })
    }

    func hasFreshQuote(
        _ quote: SubtensorTradeQuote?,
        locale: Locale,
        onRetry: @escaping () -> Void
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentQuoteMissing(view, onRetry: onRetry, locale: locale)
        }, preservesCondition: {
            guard let quote else {
                return false
            }

            return Date().timeIntervalSince(quote.quote.capturedAt) <=
                SubtensorStakingFlowConstants.quoteStalenessWindow
        })
    }

    func orderWithinSlippageTolerance(
        quote: SubtensorTradeQuote?,
        limitPrice: Balance?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentOrderBeyondTolerance(view, locale: locale)
        }, preservesCondition: {
            guard let quote, let limitPrice else {
                return false
            }

            return quote.isFillable(atLimit: limitPrice)
        })
    }

    func priceImpactAcceptable(
        quote: SubtensorTradeQuote?,
        locale: Locale
    ) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let self, let view else {
                return
            }

            let impact = quote?.quote.priceImpact ?? BigRational(numerator: 0, denominator: 1)

            presentable.presentHighPriceImpact(
                view,
                impact: formatImpact(impact, locale: locale),
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            guard let impact = quote?.quote.priceImpact else {
                return true
            }

            return !SubtensorStakingFlowConstants.isHighPriceImpact(impact)
        })
    }

    func respectsFeeReserve(
        amount: Balance?,
        transferable: Balance?,
        networkFee: Balance?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            let maxAmount = SubtensorAmountPolicy.maxBuyOrStake(
                transferable: transferable ?? 0,
                networkFee: networkFee ?? 0
            )

            presentable.presentFeeReserveRequired(
                view,
                maxAmount: formatAmount(maxAmount, locale: locale),
                reserve: formatAmount(SubtensorNovaFeeConstants.feeReserve, locale: locale),
                locale: locale
            )
        }, preservesCondition: {
            guard let amount, let transferable else {
                return false
            }

            return amount <= SubtensorAmountPolicy.maxBuyOrStake(
                transferable: transferable,
                networkFee: networkFee ?? 0
            )
        })
    }

    func hasMinStakeAmount(
        stakedAmount: Balance?,
        minStake: Balance?,
        quotedSwapFee: Balance?,
        includesNovaFee: Bool,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            let displayedMinimum = displayedMinimumStake(
                requiredStake: (minStake ?? 0) + (quotedSwapFee ?? 0),
                includesNovaFee: includesNovaFee
            )

            presentable.presentStakeAmountTooLow(
                view,
                minStake: formatRequiredAmount(displayedMinimum, locale: locale),
                locale: locale
            )
        }, preservesCondition: {
            guard let stakedAmount, let minStake else {
                return false
            }

            return stakedAmount >= minStake + (quotedSwapFee ?? 0)
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
}
