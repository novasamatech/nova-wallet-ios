import Foundation
import BigInt
import SoraFoundation

extension ParaStkStateViewModelFactory {
    func createAlerts(
        for collatorStatuses: [ParaStkDelegationStatus]?,
        scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        commonData: ParachainStaking.CommonData
    ) -> [StakingAlert] {
        var alerts: [StakingAlert] = []

        if let redeem = findRedeemAlertIfNeeded(scheduledRequests: scheduledRequests ?? [], commonData: commonData) {
            alerts.append(redeem)
        }

        if let stakeMore = findStakeMoreAlert(for: collatorStatuses) {
            alerts.append(stakeMore)
        }

        if let changeCollator = findChangeCollatorAlert(for: collatorStatuses) {
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
            let balanceFactory = BalanceViewModelFactory(
                targetAssetInfo: assetDisplayInfo,
                priceAssetInfoFactory: priceAssetInfoFactory
            )
            let localizableAmount = balanceFactory.amountFromValue(decimalAmount)
            return .redeemUnbonded(localizableAmount)
        } else {
            return nil
        }
    }

    private func findStakeMoreAlert(
        for collatorStatuses: [ParaStkDelegationStatus]?
    ) -> StakingAlert? {
        if let statuses = collatorStatuses, statuses.contains(where: { $0 == .notRewarded }) {
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
        for collatorStatuses: [ParaStkDelegationStatus]?
    ) -> StakingAlert? {
        if let statuses = collatorStatuses, statuses.contains(where: { $0 == .notElected }) {
            let description = LocalizableResource { locale in
                R.string.localizable.parachainStakingAlertCollatorsChange(
                    preferredLanguages: locale.rLanguages
                )
            }

            let title = LocalizableResource { locale in
                R.string.localizable.parachainStakingChangeCollator(preferredLanguages: locale.rLanguages)
            }

            return .nominatorChangeValidators(title: title, details: description)
        } else {
            return nil
        }
    }
}
