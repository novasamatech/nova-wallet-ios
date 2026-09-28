import Foundation

struct SubtensorRootHoldCheck {
    let currentBlock: BlockNumber?
    let blockTime: BlockTime
}

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
    var rootHoldCheck: SubtensorRootHoldCheck?

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

protocol SubtensorStakePresenterValidating {
    func createStakeValidations(
        for dep: SubtensorStakeValidatingDep,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        selectedLocale: Locale
    ) -> [DataValidating]

    func validateStake(
        for dep: SubtensorStakeValidatingDep,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        selectedLocale: Locale,
        onSuccess: @escaping () -> Void
    )
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

        if dep.isSubnet {
            validations.append(
                contentsOf: SubtensorCommonValidations.createQuoteValidations(
                    for: dep.quoteContext,
                    dataValidationFactory: dataValidationFactory,
                    locale: selectedLocale
                )
            )
        }

        validations.append(
            contentsOf: createStakeBalanceValidations(
                for: dep,
                dataValidationFactory: dataValidationFactory,
                selectedLocale: selectedLocale
            )
        )

        validations.append(
            contentsOf: createStakePreflightValidations(
                for: dep,
                dataValidationFactory: dataValidationFactory,
                selectedLocale: selectedLocale
            )
        )

        if dep.isSubnet {
            validations.append(
                dataValidationFactory.priceImpactAcceptable(
                    quote: dep.quoteContext?.latestQuote,
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

private extension SubtensorStakePresenterValidating {
    func createStakeBalanceValidations(
        for dep: SubtensorStakeValidatingDep,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        selectedLocale: Locale
    ) -> [DataValidating] {
        [
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

            dataValidationFactory.respectsFeeReserve(
                amount: dep.amount,
                transferable: dep.balance?.transferable,
                networkFee: dep.fee?.amountForCurrentAccount,
                locale: selectedLocale
            ),

            dataValidationFactory.hasMinStakeAmount(
                stakedAmount: dep.stakedAmount,
                minStake: dep.preflight?.minStake,
                quotedSwapFee: dep.quoteContext?.latestQuote?.quote.poolFee,
                includesNovaFee: dep.isSubnet,
                locale: selectedLocale
            )
        ]
    }

    func createStakePreflightValidations(
        for dep: SubtensorStakeValidatingDep,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        selectedLocale: Locale
    ) -> [DataValidating] {
        var validations: [DataValidating] = [
            dataValidationFactory.hotkeyIsRegistered(
                hotkeyExists: dep.preflight?.hotkeyExists,
                locale: selectedLocale
            ),

            dataValidationFactory.subnetStakingEnabled(
                netuid: dep.netuid,
                subnetExists: dep.preflight?.subnetExists,
                subtokenEnabled: dep.preflight?.subtokenEnabled,
                locale: selectedLocale
            )
        ]

        if let rootHoldCheck = dep.rootHoldCheck {
            validations.append(
                dataValidationFactory.rootUnlockIntervalElapsed(
                    currentBlock: rootHoldCheck.currentBlock,
                    lastStakeBlock: dep.preflight?.lastStakeBlock,
                    unlockInterval: dep.preflight?.rootStakeUnlockInterval,
                    blockTime: rootHoldCheck.blockTime,
                    locale: selectedLocale
                )
            )
        }

        validations.append(
            contentsOf: SubtensorCommonValidations.createNetworkStateValidations(
                for: dep.preflight,
                dataValidationFactory: dataValidationFactory,
                locale: selectedLocale
            )
        )

        return validations
    }
}

enum SubtensorCommonValidations {
    static func createQuoteValidations(
        for context: SubtensorQuoteValidatingContext?,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        locale: Locale
    ) -> [DataValidating] {
        [
            dataValidationFactory.subnetTradesAvailable(
                tradesUnavailable: context?.tradesUnavailable ?? false,
                locale: locale
            ),

            dataValidationFactory.hasFreshQuote(
                context?.latestQuote,
                locale: locale,
                onRetry: { context?.onQuoteRefresh() }
            ),

            dataValidationFactory.orderWithinSlippageTolerance(
                quote: context?.latestQuote,
                limitPrice: context?.acknowledgedLimit,
                locale: locale
            )
        ]
    }

    static func createNetworkStateValidations(
        for preflight: SubtensorStakingPreflight?,
        dataValidationFactory: SubtensorStakingValidationFactoryProtocol,
        locale: Locale
    ) -> [DataValidating] {
        [
            dataValidationFactory.noColdkeySwapInProgress(
                hasAnnouncement: preflight?.hasColdkeySwapAnnouncement,
                locale: locale
            ),

            dataValidationFactory.safeModeInactive(
                safeModeActive: preflight?.isSafeModeActive,
                locale: locale
            )
        ]
    }
}
