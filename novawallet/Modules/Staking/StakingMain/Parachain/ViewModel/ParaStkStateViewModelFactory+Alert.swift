import Foundation
import BigInt
import SoraFoundation

extension ParaStkStateViewModelFactory {
    func createAlerts(
        for response: ParachainStaking.DelegatorCollatorsResponse?,
        delegator _: ParachainStaking.Delegator,
        scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        commonData: ParachainStaking.CommonData
    ) -> [StakingAlert] {
        var alerts: [StakingAlert] = []

        if let redeem = findRedeemAlertIfNeeded(scheduledRequests: scheduledRequests ?? [], commonData: commonData) {
            alerts.append(redeem)
        }

        if let stakeMore = findStakeMoreAlert(for: response) {
            alerts.append(stakeMore)
        }

        if let changeCollator = findChangeCollatorAlert(for: response) {
            alerts.append(changeCollator)
        }

        return alerts
    }

    private func findRedeemAlertIfNeeded(
        scheduledRequests: [ParachainStaking.DelegatorScheduledRequest],
        commonData: ParachainStaking.CommonData
    ) -> StakingAlert? {
        guard
            let currentRound = commonData.roundInfo?.current,
            let assetDisplayInfo = commonData.chainAsset?.assetDisplayInfo else {
            return nil
        }

        let redeembaleAmount = scheduledRequests.reduce(BigUInt(0)) { total, request in
            if request.whenExecutable <= currentRound {
                return total + request.unstakingAmount
            } else {
                return total
            }
        }

        if
            redeembaleAmount > 0,
            let decimalAmount = Decimal.fromSubstrateAmount(
                redeembaleAmount,
                precision: assetDisplayInfo.assetPrecision
            ) {
            let balanceFactory = BalanceViewModelFactory(targetAssetInfo: assetDisplayInfo)
            let localizableAmount = balanceFactory.amountFromValue(decimalAmount)
            return .redeemUnbonded(localizableAmount)
        } else {
            return nil
        }
    }

    private func findStakeMoreAlert(
        for response: ParachainStaking.DelegatorCollatorsResponse?
    ) -> StakingAlert? {
        if let pendingCollators = response?.pending, pendingCollators.contains(where: { !$0.hasEnoughBond }) {
            let description = LocalizableResource { locale in
                R.string.localizable.parachainStakingAlertCollatorsWithNoRewards(
                    preferredLanguages: locale.rLanguages
                )
            }

            return .nominatorLowStake(description)
        } else {
            return nil
        }
    }

    private func findChangeCollatorAlert(
        for response: ParachainStaking.DelegatorCollatorsResponse?
    ) -> StakingAlert? {
        if let notElectedCollators = response?.notElected, !notElectedCollators.isEmpty {
            let description = LocalizableResource { locale in
                R.string.localizable.parachainStakingAlertCollatorsChange(
                    preferredLanguages: locale.rLanguages
                )
            }

            return .nominatorChangeValidators(description)
        } else {
            return nil
        }
    }
}
