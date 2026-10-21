import Foundation

struct SubtensorStakeValidatingDependencies {
    let amount: Balance?
    let balance: AssetBalance?
    let fee: ExtrinsicFeeProtocol?
    let preflight: SubtensorPreflight?
    let netuid: UInt16
    let assetDisplayInfo: AssetBalanceDisplayInfo
    let onFeeRefresh: () -> Void
    let onPreflightRefresh: () -> Void
    var quoteContext: SubtensorQuoteValidatingContext?
    var isValidatorInactive = false
    var analytics: SubtensorValidationReporter?

    var isSubnet: Bool {
        netuid != SubtensorPallet.rootNetuid
    }

    var amountDecimal: Decimal {
        amount?.decimal(assetInfo: assetDisplayInfo) ?? 0
    }

    var stakedAmount: Balance? {
        guard let amount, isSubnet else {
            return amount
        }

        let novaFee = quoteContext?.latestQuote?.novaFee?.amount ?? 0

        return amount > novaFee ? amount - novaFee : 0
    }
}

extension SubtensorValidationFactoryProtocol {
    func validateStake(
        for dependencies: SubtensorStakeValidatingDependencies,
        locale: Locale,
        onSuccess: @escaping () -> Void
    ) {
        let analytics = dependencies.analytics

        var validations: [DataValidating] = [
            has(
                fee: dependencies.fee,
                locale: locale,
                onError: { dependencies.onFeeRefresh() }
            ).reporting(.feeInProgress, to: analytics),

            hasPreflight(
                dependencies.preflight,
                locale: locale,
                onRetry: { dependencies.onPreflightRefresh() }
            )
        ]

        if dependencies.isSubnet {
            validations.append(
                contentsOf: createQuoteValidations(for: dependencies.quoteContext, locale: locale, analytics: analytics)
            )
        }

        validations.append(contentsOf: createStakeBalanceValidations(for: dependencies, locale: locale))
        validations.append(contentsOf: createStakePreflightValidations(for: dependencies, locale: locale))
        validations.append(validatorIsActive(isInactive: dependencies.isValidatorInactive, locale: locale))

        if dependencies.isSubnet {
            validations.append(
                priceImpactAcceptable(quote: dependencies.quoteContext?.latestQuote, locale: locale)
                    .reporting(.priceImpact, to: analytics)
            )
            validations.append(
                passesRealtimeQuote(dependencies.quoteContext?.reporting(to: analytics), locale: locale)
                    .reportingOutcome(to: analytics)
            )
        }

        DataValidationRunner(validators: validations).runValidation(notifyingOnSuccess: onSuccess)
    }

    func createQuoteValidations(
        for context: SubtensorQuoteValidatingContext?,
        locale: Locale,
        analytics: SubtensorValidationReporter?
    ) -> [DataValidating] {
        [
            subnetTradesAvailable(
                tradesUnavailable: context?.tradesUnavailable ?? false,
                locale: locale
            ).reportingTradesUnavailable(to: analytics),

            hasQuote(context?.latestQuote, locale: locale).reporting(.liquidity, to: analytics),

            orderWithinSlippageTolerance(
                quote: context?.latestQuote,
                limitPrice: context?.signingLimit,
                locale: locale
            ).reporting(.orderTooLarge, to: analytics)
        ]
    }

    func createNetworkStateValidations(
        for preflight: SubtensorPreflight?,
        locale: Locale
    ) -> [DataValidating] {
        [
            noColdkeySwapInProgress(
                hasAnnouncement: preflight?.hasColdkeySwapAnnouncement,
                locale: locale
            ),

            safeModeInactive(
                safeModeActive: preflight?.isSafeModeActive,
                locale: locale
            )
        ]
    }
}

private extension SubtensorValidationFactoryProtocol {
    func createStakeBalanceValidations(
        for dependencies: SubtensorStakeValidatingDependencies,
        locale: Locale
    ) -> [DataValidating] {
        [
            canSpendAmountInPlank(
                balance: dependencies.balance?.transferable,
                spendingAmount: dependencies.amountDecimal,
                asset: dependencies.assetDisplayInfo,
                locale: locale
            ).reporting(.insufficientBalance, to: dependencies.analytics),

            canPayFeeSpendingAmountInPlank(
                balance: dependencies.balance?.transferable,
                fee: dependencies.fee,
                spendingAmount: dependencies.amountDecimal,
                asset: dependencies.assetDisplayInfo,
                locale: locale
            ).reporting(.insufficientBalance, to: dependencies.analytics),

            respectsFeeReserve(
                amount: dependencies.amount,
                transferable: dependencies.balance?.transferable,
                networkFee: dependencies.fee?.amountForCurrentAccount,
                locale: locale
            ).reporting(.feeReserve, to: dependencies.analytics),

            hasMinStakeAmount(
                stakedAmount: dependencies.stakedAmount,
                minStake: dependencies.preflight?.minStake,
                quotedSwapFee: dependencies.quoteContext?.latestQuote?.quote.poolFee,
                novaFeeRate: dependencies.isSubnet ? dependencies.quoteContext?.latestQuote?.novaFeeRate : nil,
                locale: locale
            ).reporting(.minStake, to: dependencies.analytics)
        ]
    }

    func createStakePreflightValidations(
        for dependencies: SubtensorStakeValidatingDependencies,
        locale: Locale
    ) -> [DataValidating] {
        [
            hotkeyIsRegistered(
                hotkeyExists: dependencies.preflight?.hotkeyExists,
                locale: locale
            ),

            subnetStakingEnabled(
                subnetExists: dependencies.preflight?.subnetExists,
                subtokenEnabled: dependencies.preflight?.subtokenEnabled,
                locale: locale
            )
        ] + createNetworkStateValidations(for: dependencies.preflight, locale: locale)
    }
}

extension SubtensorValidationFactory {
    func validatorIsActive(isInactive: Bool, locale: Locale) -> DataValidating {
        WarningConditionViolation(onWarning: { [weak self] delegate in
            guard let self, let view else {
                return
            }

            presentable.presentInactiveValidator(
                view,
                action: {
                    delegate.didCompleteWarningHandling()
                },
                locale: locale
            )
        }, preservesCondition: {
            !isInactive
        })
    }
}
