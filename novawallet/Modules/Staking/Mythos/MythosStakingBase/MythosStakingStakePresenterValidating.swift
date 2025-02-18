import Foundation

protocol MythosStakePresenterValidating {
    func createBaseValidations(
        for dep: MythosStakePresenterValidatingDep,
        dataValidationFactory: MythosStakingValidationFactoryProtocol,
        selectedLocale: Locale
    ) -> [DataValidating]
}

struct MythosStakePresenterValidatingDep {
    let inputAmount: Decimal
    let allowedAmount: Balance?
    let balance: AssetBalance?
    let minStake: Balance?
    let stakingDetails: MythosStakingDetails?
    let selectedCollator: AccountId?
    let fee: ExtrinsicFeeProtocol?
    let maxCollatorsPerStaker: UInt32?
    let assetDisplayInfo: AssetBalanceDisplayInfo
    let onFeeRefresh: () -> Void

    var currenctCollators: Set<AccountId>? {
        stakingDetails.map { Set($0.stakeDistribution.keys) }
    }

    var stakesWithSelectedCollator: Bool {
        guard let currenctCollators, let selectedCollator else {
            return false
        }

        return currenctCollators.contains(selectedCollator)
    }
}

extension MythosStakePresenterValidating {
    func createBaseValidations(
        for dep: MythosStakePresenterValidatingDep,
        dataValidationFactory: MythosStakingValidationFactoryProtocol,
        selectedLocale: Locale
    ) -> [DataValidating] {
        var validations = [
            dataValidationFactory.has(
                fee: dep.fee,
                locale: selectedLocale,
                onError: { dep.onFeeRefresh() }
            ),

            dataValidationFactory.canSpendAmountInPlank(
                balance: dep.allowedAmount,
                spendingAmount: dep.inputAmount,
                asset: dep.assetDisplayInfo,
                locale: selectedLocale
            ),

            dataValidationFactory.canPayFeeInPlank(
                balance: dep.balance?.transferable,
                fee: dep.fee,
                asset: dep.assetDisplayInfo,
                locale: selectedLocale
            ),

            dataValidationFactory.canPayFeeSpendingAmountInPlank(
                balance: dep.allowedAmount,
                fee: dep.fee,
                spendingAmount: dep.inputAmount,
                asset: dep.assetDisplayInfo,
                locale: selectedLocale
            )
        ]

        if !dep.stakesWithSelectedCollator {
            validations.append(
                dataValidationFactory.hasMinStake(
                    amount: dep.inputAmount,
                    minStake: dep.minStake,
                    locale: selectedLocale
                )
            )
        }

        return validations
    }
}

extension MythosStakePresenterValidating {
    func validateStartStaking(
        for dep: MythosStakePresenterValidatingDep,
        dataValidationFactory: MythosStakingValidationFactoryProtocol,
        selectedLocale: Locale,
        onSuccess: @escaping () -> Void
    ) {
        let validations = createBaseValidations(
            for: dep,
            dataValidationFactory: dataValidationFactory,
            selectedLocale: selectedLocale
        )

        let validator = DataValidationRunner(validators: validations)

        validator.runValidation(notifyingOnSuccess: onSuccess)
    }

    func validateStakeMore(
        for dep: MythosStakePresenterValidatingDep,
        dataValidationFactory: MythosStakingValidationFactoryProtocol,
        selectedLocale: Locale,
        onSuccess: @escaping () -> Void
    ) {
        var validations = createBaseValidations(
            for: dep,
            dataValidationFactory: dataValidationFactory,
            selectedLocale: selectedLocale
        )

        validations.append(
            dataValidationFactory.notExceedsMaxCollators(
                currentCollators: dep.currenctCollators,
                selectedCollator: dep.selectedCollator,
                maxCollatorsAllowed: dep.maxCollatorsPerStaker,
                locale: selectedLocale
            )
        )

        let validator = DataValidationRunner(validators: validations)

        validator.runValidation(notifyingOnSuccess: onSuccess)
    }
}
