import Foundation
import BigInt
import Foundation_iOS

extension MythosStkStateViewModelFactory {
    func createAlerts(
        for collatorStatuses: [CollatorStakingDelegationStatus]?,
        releaseQueue: MythosStakingPallet.ReleaseQueue?,
        commonData: MythosStakingCommonData
    ) -> [StakingAlert] {
        var alerts: [StakingAlert] = []

        if let redeem = findRedeemAlertIfNeeded(releaseQueue: releaseQueue, commonData: commonData) {
            alerts.append(redeem)
        }

        if let changeCollator = findChangeCollatorAlert(for: collatorStatuses) {
            alerts.append(changeCollator)
        }

        return alerts
    }

    private func findRedeemAlertIfNeeded(
        releaseQueue: MythosStakingPallet.ReleaseQueue?,
        commonData: MythosStakingCommonData
    ) -> StakingAlert? {
        guard
            let releaseQueue,
            let currentBlock = commonData.blockNumber,
            let assetDisplayInfo = commonData.chainAsset?.assetDisplayInfo else {
            return nil
        }

        let redeemableAmount = releaseQueue.reduce(BigUInt(0)) { total, request in
            if request.isRedeemable(at: currentBlock) {
                return total + request.amount
            } else {
                return total
            }
        }

        guard redeemableAmount > 0 else {
            return nil
        }

        let decimalAmount = redeemableAmount.decimal(assetInfo: assetDisplayInfo)

        let balanceFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let localizableAmount = balanceFactory.amountFromValue(decimalAmount)
        return .redeemUnbonded(localizableAmount)
    }

    private func findChangeCollatorAlert(
        for collatorStatuses: [CollatorStakingDelegationStatus]?
    ) -> StakingAlert? {
        guard
            let statuses = collatorStatuses,
            statuses.contains(where: { $0 == .notElected }) else {
            return nil
        }

        let description = LocalizableResource { locale in
            R.string.localizable.parachainStakingAlertCollatorsChange(
                preferredLanguages: locale.rLanguages
            )
        }

        let title = LocalizableResource { locale in
            R.string.localizable.parachainStakingChangeCollator(preferredLanguages: locale.rLanguages)
        }

        return .nominatorChangeValidators(title: title, details: description)
    }
}
