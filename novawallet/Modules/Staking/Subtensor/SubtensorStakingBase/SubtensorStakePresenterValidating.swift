import Foundation

struct SubtensorStakeValidatingDep {
    let amount: Balance?
    let balance: AssetBalance?
    let fee: ExtrinsicFeeProtocol?
    let existentialDeposit: Balance?
    let preflight: SubtensorStakingPreflight?
    let netuid: UInt16
    let assetDisplayInfo: AssetBalanceDisplayInfo
    let onFeeRefresh: () -> Void
    let onPreflightRefresh: () -> Void
    var quoteContext: SubtensorQuoteValidatingContext?

    var amountDecimal: Decimal {
        amount?.decimal(assetInfo: assetDisplayInfo) ?? 0
    }
}

protocol SubtensorStakePresenterValidating {
    func createStakeValidations(
        for dep: SubtensorStakeValidatingDep,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        selectedLocale: Locale
    ) -> [DataValidating]
}

extension SubtensorStakePresenterValidating {
    func createStakeValidations(
        for dep: SubtensorStakeValidatingDep,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        selectedLocale: Locale
    ) -> [DataValidating] {
        var validations: [DataValidating] = [
            dataValidationFactory.has(
                fee: dep.fee,
                locale: selectedLocale,
                onError: { dep.onFeeRefresh() }
            ),

            dataValidationFactory.hasPreflight(
                dep.preflight,
                locale: selectedLocale,
                onRetry: { dep.onPreflightRefresh() }
            )
        ]

        if let quoteContext = dep.quoteContext {
            validations.append(
                dataValidationFactory.hasFreshQuote(
                    quoteContext.quote,
                    for: quoteContext.args,
                    locale: selectedLocale,
                    onRetry: { quoteContext.onQuoteRefresh() }
                )
            )

            validations.append(
                dataValidationFactory.orderWithinSlippageTolerance(
                    quote: quoteContext.quote,
                    limitPrice: quoteContext.limitPrice,
                    locale: selectedLocale
                )
            )
        }

        validations.append(contentsOf: [
            dataValidationFactory.canSpendAmountInPlank(
                balance: dep.balance?.transferable,
                spendingAmount: dep.amountDecimal,
                asset: dep.assetDisplayInfo,
                locale: selectedLocale
            ),

            dataValidationFactory.canPayFeeSpendingAmountInPlank(
                balance: dep.balance?.transferable,
                fee: dep.fee,
                spendingAmount: dep.amountDecimal,
                asset: dep.assetDisplayInfo,
                locale: selectedLocale
            ),

            dataValidationFactory.retainsFeeReserveAfterStake(
                balance: dep.balance?.transferable,
                amount: dep.amount,
                fee: dep.fee?.amountForCurrentAccount,
                existentialDeposit: dep.existentialDeposit,
                locale: selectedLocale
            ),

            dataValidationFactory.hasMinStakeAmount(
                amount: dep.amount,
                minStake: dep.preflight?.minStake,
                quotedSwapFee: dep.quoteContext?.quote?.poolFee,
                locale: selectedLocale
            ),

            dataValidationFactory.hotkeyIsRegistered(
                hotkeyExists: dep.preflight?.hotkeyExists,
                locale: selectedLocale
            ),

            dataValidationFactory.subnetStakingEnabled(
                netuid: dep.netuid,
                subnetExists: dep.preflight?.subnetExists,
                subtokenEnabled: dep.preflight?.subtokenEnabled,
                locale: selectedLocale
            ),

            dataValidationFactory.noColdkeySwapInProgress(
                hasAnnouncement: dep.preflight?.hasColdkeySwapAnnouncement,
                locale: selectedLocale
            ),

            dataValidationFactory.safeModeInactive(
                safeModeActive: dep.preflight?.isSafeModeActive,
                locale: selectedLocale
            )
        ])

        // the impact warning runs after every hard error rule so a blocked submission
        // is never preceded by a proceed-anyway prompt
        if let quoteContext = dep.quoteContext {
            validations.append(
                dataValidationFactory.priceImpactAcceptable(
                    quote: quoteContext.quote,
                    locale: selectedLocale
                )
            )
        }

        return validations
    }

    func validateStake(
        for dep: SubtensorStakeValidatingDep,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        selectedLocale: Locale,
        onSuccess: @escaping () -> Void
    ) {
        let validations = createStakeValidations(
            for: dep,
            dataValidationFactory: dataValidationFactory,
            selectedLocale: selectedLocale
        )

        DataValidationRunner(validators: validations).runValidation(notifyingOnSuccess: onSuccess)
    }
}
