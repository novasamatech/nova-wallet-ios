import Foundation
import BigInt

extension ParaStkStakeConfirmPresenter {
    func provideStartStakingHintsViewModel() {
        var hints: [String] = []
        let languages = selectedLocale.rLanguages

        if let stakingDuration = stakingDuration {
            let roundDuration = stakingDuration.round.localizedDaysHours(for: selectedLocale)
            let unstakingPeriod = stakingDuration.unstaking.localizedDaysHours(for: selectedLocale)

            hints.append(contentsOf: [
                R.string.localizable.parachainStakingHintRewardsFormat(
                    "~\(roundDuration)",
                    preferredLanguages: languages
                ),
                R.string.localizable.stakingHintUnstakeFormat_v2_2_0(
                    "~\(unstakingPeriod)",
                    preferredLanguages: languages
                )
            ])
        }

        hints.append(contentsOf: [
            R.string.localizable.stakingHintNoRewards_V2_2_0(preferredLanguages: languages),
            R.string.localizable.stakingHintRedeem_v2_2_0(preferredLanguages: languages)
        ])

        view?.didReceiveHints(viewModel: hints)
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

        let precision = chainAsset.assetDisplayInfo.assetPrecision

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
