import Foundation
import BigInt

extension ParaStkStakeSetupPresenter {
    private func createStakeMoreValidationRunner(
        for inputAmount: Decimal?,
        existingBond: BigUInt,
        collatorId: AccountId?,
        precision: Int16
    ) -> DataValidationRunner {
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
            dataValidatingFactory.notRevokingWhileStakingMore(
                collator: collatorId,
                scheduledRequests: scheduledRequests,
                locale: selectedLocale
            ),
            dataValidatingFactory.canStakeBottomDelegations(
                amount: inputAmount,
                collator: collatorMetadata,
                existingBond: existingBond,
                locale: selectedLocale
            ),
            dataValidatingFactory.canStakeTopDelegations(
                amount: inputAmount,
                collator: collatorMetadata,
                existingBond: existingBond,
                locale: selectedLocale
            )
        ])
    }

    func stakeMore(above existingBond: BigUInt) {
        let precision = chainAsset.assetDisplayInfo.assetPrecision
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee())

        let collatorId = try? collatorDisplayAddress?.address.toAccountId()

        let runner = createStakeMoreValidationRunner(
            for: inputAmount,
            existingBond: existingBond,
            collatorId: collatorId,
            precision: precision
        )

        runner.runValidation { [weak self] in
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
