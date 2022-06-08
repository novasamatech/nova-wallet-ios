import Foundation
import BigInt

extension ParaStkStakeSetupPresenter {
    private func createStartStakingValidationRunner(
        for inputAmount: Decimal?,
        precision: Int16
    ) -> DataValidationRunner {
        let minStake: BigUInt?

        if delegator != nil {
            minStake = minDelegationAmount
        } else {
            minStake = minTechStake
        }

        return DataValidationRunner(validators: [
            dataValidatingFactory.hasInPlank(
                fee: fee,
                locale: selectedLocale,
                precision: precision,
                onError: { [weak self] in self?.refreshFee() }
            ),
            dataValidatingFactory.canPayFeeAndAmountInPlank(
                balance: balance?.transferable,
                fee: fee,
                spendingAmount: inputAmount,
                precision: precision,
                locale: selectedLocale
            ),
            dataValidatingFactory.notExceedsMaxCollators(
                delegator: delegator,
                maxCollatorsAllowed: maxDelegations,
                locale: selectedLocale
            ),
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

    func startStaking() {
        let precision = chainAsset.assetDisplayInfo.assetPrecision
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee())

        let validator = createStartStakingValidationRunner(for: inputAmount, precision: precision)

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
