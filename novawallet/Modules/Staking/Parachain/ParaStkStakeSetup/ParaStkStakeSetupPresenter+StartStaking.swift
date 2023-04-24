import Foundation
import BigInt

extension ParaStkStakeSetupPresenter {
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

        let precision = assetDisplayInfo.assetPrecision

        return DataValidationRunner(validators: [
            dataValidatingFactory.hasInPlank(
                fee: fee,
                locale: selectedLocale,
                precision: precision,
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

            dataValidatingFactory.notExceedsMaxCollators(
                delegator: delegator,
                maxCollatorsAllowed: maxDelegations,
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
                minTechStake: minStake,
                locale: selectedLocale
            ),

            dataValidatingFactory.canStakeTopDelegations(
                amount: inputAmount,
                collator: collatorMetadata,
                existingBond: nil,
                locale: selectedLocale
            )
        ])
    }

    func startStaking(for allowedAmountToStake: BigUInt?) {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee())

        let validator = createStartStakingValidationRunner(
            for: inputAmount,
            allowedAmountToStake: allowedAmountToStake,
            assetDisplayInfo: chainAsset.assetDisplayInfo
        )

        validator.runValidation { [weak self] in
            guard let collator = self?.collatorDisplayAddress, let amount = inputAmount else {
                return
            }

            self?.wireframe.showConfirmation(
                from: self?.view,
                collator: collator,
                amount: amount,
                initialDelegator: self?.delegator
            )
        }
    }
}
