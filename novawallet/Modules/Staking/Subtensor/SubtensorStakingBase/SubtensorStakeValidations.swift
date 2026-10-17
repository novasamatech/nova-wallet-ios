import Foundation

struct SubtensorStakeValidatingDep {
    let amount: Balance?
    let balance: AssetBalance?
    let fee: ExtrinsicFeeProtocol?
    let preflight: SubtensorStakingPreflight?
    let netuid: UInt16
    let assetDisplayInfo: AssetBalanceDisplayInfo
    let onFeeRefresh: () -> Void
    let onPreflightRefresh: () -> Void
    var quoteContext: SubtensorQuoteValidatingContext?

    var isSubnet: Bool {
        netuid != SubtensorStakingPallet.rootNetuid
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

extension SubtensorStakingValidationFactoryProtocol {
    func validateStake(
        for dep: SubtensorStakeValidatingDep,
        locale: Locale,
        onSuccess: @escaping () -> Void
    ) {
        var validations: [DataValidating] = [
            has(
                fee: dep.fee,
                locale: locale,
                onError: { dep.onFeeRefresh() }
            ),

            hasPreflight(
                dep.preflight,
                locale: locale,
                onRetry: { dep.onPreflightRefresh() }
            )
        ]

        if dep.isSubnet {
            validations.append(contentsOf: createQuoteValidations(for: dep.quoteContext, locale: locale))
        }

        validations.append(contentsOf: createStakeBalanceValidations(for: dep, locale: locale))
        validations.append(contentsOf: createStakePreflightValidations(for: dep, locale: locale))

        if dep.isSubnet {
            validations.append(priceImpactAcceptable(quote: dep.quoteContext?.latestQuote, locale: locale))
            validations.append(passesRealtimeQuote(dep.quoteContext, locale: locale))
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
        for preflight: SubtensorStakingPreflight?,
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

private extension SubtensorStakingValidationFactoryProtocol {
    func createStakeBalanceValidations(
        for dep: SubtensorStakeValidatingDep,
        locale: Locale
    ) -> [DataValidating] {
        [
            canSpendAmountInPlank(
                balance: dep.balance?.transferable,
                spendingAmount: dep.amountDecimal,
                asset: dep.assetDisplayInfo,
                locale: locale
            ),

            canPayFeeSpendingAmountInPlank(
                balance: dep.balance?.transferable,
                fee: dep.fee,
                spendingAmount: dep.amountDecimal,
                asset: dep.assetDisplayInfo,
                locale: locale
            ),

            respectsFeeReserve(
                amount: dep.amount,
                transferable: dep.balance?.transferable,
                networkFee: dep.fee?.amountForCurrentAccount,
                locale: locale
            ),

            hasMinStakeAmount(
                stakedAmount: dep.stakedAmount,
                minStake: dep.preflight?.minStake,
                quotedSwapFee: dep.quoteContext?.latestQuote?.quote.poolFee,
                includesNovaFee: dep.isSubnet,
                locale: locale
            )
        ]
    }

    func createStakePreflightValidations(
        for dep: SubtensorStakeValidatingDep,
        locale: Locale
    ) -> [DataValidating] {
        [
            hotkeyIsRegistered(
                hotkeyExists: dep.preflight?.hotkeyExists,
                locale: locale
            ),

            subnetStakingEnabled(
                subnetExists: dep.preflight?.subnetExists,
                subtokenEnabled: dep.preflight?.subtokenEnabled,
                locale: locale
            )
        ] + createNetworkStateValidations(for: dep.preflight, locale: locale)
    }
}
