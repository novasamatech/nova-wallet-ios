import Foundation
import BigInt

extension ParaStkStakeSetupPresenter {
    private func createStakeMoreValidationRunner(
        for inputAmount: Decimal?,
        allowedAmountToStake: BigUInt?,
        existingBond: BigUInt,
        collatorId: AccountId?,
        assetDisplayInfo: AssetBalanceDisplayInfo
    ) -> DataValidationRunner {
        let precision = assetDisplayInfo.assetPrecision

        return DataValidationRunner(validators: [
            dataValidatingFactory.hasInPlank(
                fee: fee,
                locale: selectedLocale,
                precision: precision,
                onError: { [weak self] in self?.refreshFee() }
            ),
            dataValidatingFactory.canPayFeeInPlank(
                balance: balance?.transferable,
                fee: fee,
                asset: assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.canPayFeeAndAmountInPlank(
                balance: allowedAmountToStake,
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

    func stakeMore(above existingBond: BigUInt, allowedAmountToStake: BigUInt?) {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee())

        let collatorId = try? collatorDisplayAddress?.address.toAccountId()

        let runner = createStakeMoreValidationRunner(
            for: inputAmount,
            allowedAmountToStake: allowedAmountToStake,
            existingBond: existingBond,
            collatorId: collatorId,
            assetDisplayInfo: chainAsset.assetDisplayInfo
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
