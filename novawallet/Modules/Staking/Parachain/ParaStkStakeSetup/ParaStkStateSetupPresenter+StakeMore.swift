import Foundation
import BigInt

extension ParaStkStakeSetupPresenter {
    func stakeMore(above existingBond: BigUInt) {
        let precision = chainAsset.assetDisplayInfo.assetPrecision
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee())

        DataValidationRunner(validators: [
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
            dataValidatingFactory.canStakeBottomDelegations(
                amount: inputAmount,
                collator: collatorMetadata,
                existingBond: existingBond,
                locale: selectedLocale
            ),
            dataValidatingFactory.hasMinStake(
                amount: inputAmount,
                minTechStake: minDelegationAmount,
                locale: selectedLocale
            ),
            dataValidatingFactory.canStakeTopDelegations(
                amount: inputAmount,
                collator: collatorMetadata,
                existingBond: existingBond,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            guard
                let collator = self?.collatorDisplayAddress,
                let amount = inputAmount else {
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
