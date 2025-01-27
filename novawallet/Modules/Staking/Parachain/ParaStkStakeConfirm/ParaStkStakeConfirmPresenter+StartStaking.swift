import Foundation
import BigInt

extension ParaStkStakeConfirmPresenter {
    func provideStartStakingHintsViewModel() {
        view?.didReceiveHints(viewModel: [])
    }

    private func createStartStakingValidationRunner(
        for inputAmount: Decimal?,
        allowedAmountToStake: BigUInt?,
        assetDisplayInfo: AssetBalanceDisplayInfo
    ) -> DataValidationRunner {
        let minStake: BigUInt?

        if delegator != nil {
            minStake = minDelegationAmount
        } else {
            minStake = minTechStake
        }

        return DataValidationRunner(validators: [
            dataValidatingFactory.has(
                fee: fee,
                locale: selectedLocale,
                onError: { [weak self] in self?.refreshFee() }
            ),

            dataValidatingFactory.canSpendAmountInPlank(
                balance: allowedAmountToStake,
                spendingAmount: inputAmount,
                asset: assetDisplayInfo,
                locale: selectedLocale
            ),

            dataValidatingFactory.canPayFeeInPlank(
                balance: balance?.transferable,
                fee: fee,
                asset: assetDisplayInfo,
                locale: selectedLocale
            ),

            dataValidatingFactory.canPayFeeSpendingAmountInPlank(
                balance: allowedAmountToStake,
                fee: fee,
                spendingAmount: inputAmount,
                asset: assetDisplayInfo,
                locale: selectedLocale
            ),

            dataValidatingFactory.isActiveCollator(for: collatorMetadata, locale: selectedLocale),

            dataValidatingFactory.canStakeBottomDelegations(
                amount: inputAmount,
                collator: collatorMetadata,
                existingBond: nil,
                locale: selectedLocale
            ),

            dataValidatingFactory.hasMinStake(
                amount: inputAmount,
                minStake: minStake,
                locale: selectedLocale
            )
        ])
    }

    func startStaking(for allowedAmountToStake: BigUInt?) {
        let validator = createStartStakingValidationRunner(
            for: amount,
            allowedAmountToStake: allowedAmountToStake,
            assetDisplayInfo: chainAsset.assetDisplayInfo
        )

        validator.runValidation { [weak self] in
            self?.submitExtrinsic()
        }
    }
}
