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
        var validations: [DataValidating] = [
            has(
                fee: dependencies.fee,
                locale: locale,
                onError: { dependencies.onFeeRefresh() }
            ),

            hasPreflight(
                dependencies.preflight,
                locale: locale,
                onRetry: { dependencies.onPreflightRefresh() }
            )
        ]

        if dependencies.isSubnet {
            validations.append(contentsOf: createQuoteValidations(for: dependencies.quoteContext, locale: locale))
        }

        validations.append(contentsOf: createStakeBalanceValidations(for: dependencies, locale: locale))
        validations.append(contentsOf: createStakePreflightValidations(for: dependencies, locale: locale))

        if dependencies.isSubnet {
            validations.append(priceImpactAcceptable(quote: dependencies.quoteContext?.latestQuote, locale: locale))
            validations.append(passesRealtimeQuote(dependencies.quoteContext, locale: locale))
        }

        DataValidationRunner(validators: validations).runValidation(notifyingOnSuccess: onSuccess)
    }

    func createQuoteValidations(
        for context: SubtensorQuoteValidatingContext?,
        locale: Locale
    ) -> [DataValidating] {
        [
            subnetTradesAvailable(
                tradesUnavailable: context?.tradesUnavailable ?? false,
                locale: locale
            ),

            hasQuote(context?.latestQuote, locale: locale),

            orderWithinSlippageTolerance(
                quote: context?.latestQuote,
                limitPrice: context?.signingLimit,
                locale: locale
            )
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
            ),

            canPayFeeSpendingAmountInPlank(
                balance: dependencies.balance?.transferable,
                fee: dependencies.fee,
                spendingAmount: dependencies.amountDecimal,
                asset: dependencies.assetDisplayInfo,
                locale: locale
            ),

            respectsFeeReserve(
                amount: dependencies.amount,
                transferable: dependencies.balance?.transferable,
                networkFee: dependencies.fee?.amountForCurrentAccount,
                locale: locale
            ),

            hasMinStakeAmount(
                stakedAmount: dependencies.stakedAmount,
                minStake: dependencies.preflight?.minStake,
                quotedSwapFee: dependencies.quoteContext?.latestQuote?.quote.poolFee,
                includesNovaFee: dependencies.isSubnet,
                locale: locale
            )
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
