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

    func startStaking() {
        let precision = chainAsset.assetDisplayInfo.assetPrecision

        let validator = createStartStakingValidationRunner(for: amount, precision: precision)

        validator.runValidation { [weak self] in
            self?.submitExtrinsic()
        }
    }
}
