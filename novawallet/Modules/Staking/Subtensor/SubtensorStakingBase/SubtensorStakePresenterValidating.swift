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
        [
            dataValidationFactory.has(
                fee: dep.fee,
                locale: selectedLocale,
                onError: { dep.onFeeRefresh() }
            ),

            dataValidationFactory.hasPreflight(
                dep.preflight,
                locale: selectedLocale,
                onRetry: { dep.onPreflightRefresh() }
            ),

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
                quotedSwapFee: nil,
                locale: selectedLocale
            ),

            dataValidationFactory.hotkeyIsRegistered(
                hotkeyExists: dep.preflight?.hotkeyExists,
                locale: selectedLocale
            ),

            dataValidationFactory.subnetStakingEnabled(
                netuid: dep.netuid,
                subnetExists: dep.preflight.map { _ in true },
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
        ]
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
