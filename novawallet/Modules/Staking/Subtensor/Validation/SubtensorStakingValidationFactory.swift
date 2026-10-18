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

    private let formatterFactory = AssetBalanceFormatterFactory()

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

    func errorCondition(
        locale: Locale,
        alert: @escaping (SubtensorStakingValidationFactory, _R.string.localizable) -> (title: String, message: String),
        preservesCondition: @escaping () -> Bool
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            let content = alert(self, R.string(preferredLanguages: locale.rLanguages).localizable)

            presentable.presentError(title: content.title, message: content.message, view: view, locale: locale)
        }, preservesCondition: preservesCondition)
    }

    private func formatImpact(_ impact: BigRational, locale: Locale) -> String {
        let formatter = NumberFormatter.percentSingle
        formatter.locale = locale

        return formatter.stringFromDecimal(impact.decimalOrZeroValue) ?? ""
    }

    private func displayedMinimumStake(requiredStake: Balance, includesNovaFee: Bool) -> Balance {
        let rate = SubtensorNovaFeeRateStore.shared.rate
        let grossStake = includesNovaFee ? try? SubtensorNovaFeeCalculator.grossUp(net: requiredStake, rate: rate) : nil

        return grossStake ?? requiredStake
    }

    private func formatRate(
        _ quote: SubtensorTradeQuote,
        alphaDisplayInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> String {
        let isStake = if case .stake = quote.quote.args.direction { true } else { false }

        return formatterFactory.subtensorSwapRate(
            amountIn: quote.amountIn,
            amountOut: quote.expectedOut,
            inInfo: isStake ? assetDisplayInfo : alphaDisplayInfo,
            outInfo: isStake ? alphaDisplayInfo : assetDisplayInfo,
            locale: locale
        ) ?? ""
    }

    private func presentQuoteChange(
        _ change: SubtensorQuoteChange,
        context: SubtensorQuoteValidatingContext,
        delegate: DataValidatingDelegate,
        locale: Locale
    ) {
        guard let view else {
            return
        }

        switch change {
        case let .rateChange(_, new) where context.onPriceMoved != nil:
            context.onPriceMoved?(new)
        case let .rateChange(old, new):
            presentable.presentRateUpdated(
                from: view,
                oldRate: formatRate(old, alphaDisplayInfo: context.alphaDisplayInfo, locale: locale),
                newRate: formatRate(new, alphaDisplayInfo: context.alphaDisplayInfo, locale: locale),
                onConfirm: {
                    context.onQuoteUpdate(new)
                    delegate.didCompleteAsyncHandling()
                },
                locale: locale
            )
        case .unavailable:
            presentable.presentNotEnoughLiquidity(from: view, locale: locale)
        }
    }

    private func checkRealtimeQuote(
        _ context: SubtensorQuoteValidatingContext?,
        completion: @escaping (SubtensorQuoteChange?) -> Void
    ) {
        guard let context, let current = context.latestQuote, let limit = context.acknowledgedLimit else {
            completion(.unavailable)
            return
        }

        context.loadingView?.didStartLoading()

        context.onQuoteRequest { result in
            switch result {
            case let .success(new) where new.isFillable(atLimit: new.tighterLimit(than: limit)):
                context.onQuoteVerified?(new)
                completion(nil)
            case let .success(new):
                context.loadingView?.didStopLoading()
                completion(.rateChange(old: current, new: new))
            case .failure:
                context.loadingView?.didStopLoading()
                completion(.unavailable)
            }
        }
    }
}

private enum SubtensorQuoteChange {
    case rateChange(old: SubtensorTradeQuote, new: SubtensorTradeQuote)
    case unavailable
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

    func hasQuote(
        _ quote: SubtensorTradeQuote?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let self, let view else {
                return
            }

            presentable.presentNotEnoughLiquidity(from: view, locale: locale)
        }, preservesCondition: {
            quote != nil
        })
    }

    func passesRealtimeQuote(
        _ context: SubtensorQuoteValidatingContext?,
        locale: Locale
    ) -> DataValidating {
        var change: SubtensorQuoteChange?

        return AsyncWarningConditionViolation(
            onWarning: { [weak self] delegate in
                guard let self, let context, let change else {
                    return
                }

                presentQuoteChange(change, context: context, delegate: delegate, locale: locale)
            },
            preservesCondition: { [weak self] callback in
                self?.checkRealtimeQuote(context) { result in
                    change = result

                    callback(result == nil)
                }
            }
        )
    }

    func orderWithinSlippageTolerance(
        quote: SubtensorTradeQuote?,
        limitPrice: Balance?,
        locale: Locale
    ) -> DataValidating {
        errorCondition(locale: locale, alert: { _, strings in
            (strings.stakingSubtensorSelfImpactTitle(), strings.stakingSubtensorSelfImpactMessage())
        }, preservesCondition: {
            guard let quote, let limitPrice else {
                return true
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
        errorCondition(locale: locale, alert: { factory, strings in
            let maxAmount = SubtensorAmountPolicy.maxBuyOrStake(
                transferable: transferable ?? 0,
                networkFee: networkFee ?? 0
            )

            let reserve = factory.formatAmount(SubtensorNovaFeeConstants.feeReserve, locale: locale)

            return (
                strings.stakingSubtensorReserveTitle(reserve),
                strings.stakingSubtensorReserveMessage(factory.formatAmount(maxAmount, locale: locale), reserve)
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
        errorCondition(locale: locale, alert: { factory, strings in
            let displayedMinimum = factory.displayedMinimumStake(
                requiredStake: (minStake ?? 0) + (quotedSwapFee ?? 0),
                includesNovaFee: includesNovaFee
            )

            let minimum = factory.formatRequiredAmount(displayedMinimum, locale: locale)

            return (strings.amountTooLow(), strings.stakingSetupAmountTooLow(minimum))
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
        errorCondition(locale: locale, alert: { _, strings in
            (strings.stakingSubtensorHotkeyNotFoundTitle(), strings.stakingSubtensorHotkeyNotFoundMessage())
        }, preservesCondition: {
            hotkeyExists == true
        })
    }

    func subnetStakingEnabled(
        subnetExists: Bool?,
        subtokenEnabled: Bool?,
        locale: Locale
    ) -> DataValidating {
        errorCondition(locale: locale, alert: { _, strings in
            (strings.stakingSubtensorSubnetDisabledTitle(), strings.stakingSubtensorSubnetDisabledMessage())
        }, preservesCondition: {
            subnetExists == true && subtokenEnabled == true
        })
    }

    func noColdkeySwapInProgress(
        hasAnnouncement: Bool?,
        locale: Locale
    ) -> DataValidating {
        errorCondition(locale: locale, alert: { _, strings in
            (strings.stakingSubtensorColdkeySwapTitle(), strings.stakingSubtensorColdkeySwapMessage())
        }, preservesCondition: {
            hasAnnouncement == false
        })
    }

    func safeModeInactive(
        safeModeActive: Bool?,
        locale: Locale
    ) -> DataValidating {
        errorCondition(locale: locale, alert: { _, strings in
            (strings.stakingSubtensorSafeModeTitle(), strings.stakingSubtensorSafeModeMessage())
        }, preservesCondition: {
            safeModeActive == false
        })
    }
}
