import Foundation
import Foundation_iOS

extension StakingStateViewModelFactory {
    func stakingAlertsForNominatorState(_ state: NominatorState) -> [StakingAlert] {
        [
            findMinStakeNotSatisfied(commonData: state.commonData, ledgerInfo: state.ledgerInfo),
            findInactiveAlert(state: state),
            findRedeemUnbondedAlert(commonData: state.commonData, ledgerInfo: state.ledgerInfo),
            findRebagAlert(state: state),
            findWaitingNextEraAlert(nominationStatus: state.status)
        ].compactMap { $0 }
    }

    func stakingAlertsForValidatorState(_ state: ValidatorState) -> [StakingAlert] {
        [
            findRedeemUnbondedAlert(commonData: state.commonData, ledgerInfo: state.ledgerInfo)
        ].compactMap { $0 }
    }

    func stakingAlertsForBondedState(_ state: BondedState) -> [StakingAlert] {
        [
            findMinStakeNotSatisfied(commonData: state.commonData, ledgerInfo: state.ledgerInfo),
            .bondedSetValidators,
            findRedeemUnbondedAlert(commonData: state.commonData, ledgerInfo: state.ledgerInfo)
        ].compactMap { $0 }
    }

    private func findRedeemUnbondedAlert(
        commonData: StakingStateCommonData,
        ledgerInfo: Staking.Ledger
    ) -> StakingAlert? {
        guard
            let era = commonData.eraStakersInfo?.activeEra,
            let precision = commonData.chainAsset?.assetDisplayInfo.assetPrecision,
            let redeemable = Decimal.fromSubstrateAmount(
                ledgerInfo.redeemable(inEra: era),
                precision: precision
            ),
            redeemable > 0,
            let redeemableAmount = balanceViewModelFactory?.amountFromValue(redeemable)
        else { return nil }

        let localizedString = LocalizableResource<String> { locale in
            redeemableAmount.value(for: locale)
        }
        return .redeemUnbonded(localizedString)
    }

    private func findMinStakeNotSatisfied(
        commonData: StakingStateCommonData,
        ledgerInfo: Staking.Ledger
    ) -> StakingAlert? {
        if let minStake = commonData.minStake, ledgerInfo.active < minStake {
            guard
                let chainAsset = commonData.chainAsset,
                let minActiveDecimal = Decimal.fromSubstrateAmount(
                    minStake,
                    precision: chainAsset.assetDisplayInfo.assetPrecision
                ),
                let localizedMinActiveAmount = balanceViewModelFactory?.balanceFromPrice(
                    minActiveDecimal,
                    priceData: commonData.price,
                    roundingMode: .up
                )
            else {
                return nil
            }

            let localizedString = LocalizableResource<String> { locale in
                let minActiveAmount = localizedMinActiveAmount.value(for: locale)
                let message = minActiveAmount.price.map { "\(minActiveAmount.amount) (\($0))" }
                    ?? minActiveAmount.amount

                return R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.stakingInactiveCurrentMinimalStake(message)
            }
            return .nominatorLowStake(localizedString)
        } else {
            return nil
        }
    }

    private func findInactiveAlert(state: NominatorState) -> StakingAlert? {
        guard case .inactive = state.status else { return nil }

        let minStakeViolated = state.commonData.minStake.map { state.ledgerInfo.active < $0 } ?? false

        if !minStakeViolated, !state.hasElectedValidators {
            let description = LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingNominatorStatusAlertNoValidators()
            }

            let title = LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingChangeYourValidators()
            }

            return .nominatorChangeValidators(title: title, details: description)
        } else if state.allValidatorsWithoutReward {
            return .nominatorAllOversubscribed
        }

        return nil
    }

    private func findWaitingNextEraAlert(nominationStatus: NominationViewStatus) -> StakingAlert? {
        if case NominationViewStatus.waiting = nominationStatus {
            return .waitingNextEra
        }
        return nil
    }

    private func findRebagAlert(state: NominatorState) -> StakingAlert? {
        guard
            let bagListNode = state.bagListNode,
            let scoreFactor = state.commonData.bagListScoreFactor,
            BagList.scoreOf(stake: state.ledgerInfo.active, given: scoreFactor) > bagListNode.bagUpper else {
            return nil
        }

        return .rebag
    }
}
