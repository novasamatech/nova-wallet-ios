import Foundation
import BigInt

extension ParaStkStakeConfirmPresenter {
    func provideStakeMoreHintsViewModel() {
        let hints: [String] = [
            R.string.localizable.parastkHintRewardBondMore(preferredLanguages: selectedLocale.rLanguages)
        ]

        view?.didReceiveHints(viewModel: hints)
    }

    func stakeMore(above existingBond: BigUInt, allowedAmountToStake: BigUInt?) {
        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let precision = assetDisplayInfo.assetPrecision
        let collatorId = try? collator.address.toAccountId()

        DataValidationRunner(validators: [
            dataValidatingFactory.hasInPlank(
                fee: fee,
                locale: selectedLocale,
                precision: precision,
                onError: { [weak self] in self?.refreshFee() }
            ),

            dataValidatingFactory.canSpendAmountInPlank(
                balance: allowedAmountToStake,
                spendingAmount: amount,
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
                spendingAmount: amount,
                asset: assetDisplayInfo,
                locale: selectedLocale
            ),

            dataValidatingFactory.notRevokingWhileStakingMore(
                collator: collatorId,
                scheduledRequests: scheduledRequests,
                locale: selectedLocale
            ),

            dataValidatingFactory.canStakeBottomDelegations(
                amount: amount,
                collator: collatorMetadata,
                existingBond: existingBond,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            self?.submitExtrinsic()
        }
    }
}
