import Foundation
import Foundation_iOS

extension SubtensorStkStateViewModelFactory {
    func createAlerts(
        for stakingState: Multistaking.SubtensorStakingState,
        commonData: SubtensorStakingCommonData
    ) -> [StakingAlert] {
        [
            findSafeModeAlert(for: commonData),
            findStaleDataAlert(for: commonData),
            findClaimableAlert(for: commonData),
            findUnregisteredDelegateAlert(for: stakingState)
        ].compactMap { $0 }
    }

    /// spec §4.4.7 / §9 risk 11 — chain-wide and non-alarming; the same read gates every staking
    /// call at proceed time, so this only tells the user why nothing works
    private func findSafeModeAlert(
        for commonData: SubtensorStakingCommonData
    ) -> StakingAlert? {
        guard commonData.networkInfo?.isSafeModeActive == true else {
            return nil
        }

        return .chainMaintenance(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorSafeModeTitle()
            },
            details: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorSafeModeMessage()
            }
        )
    }

    private func findStaleDataAlert(
        for commonData: SubtensorStakingCommonData
    ) -> StakingAlert? {
        guard commonData.positionsSyncFailed else {
            return nil
        }

        return .chainMaintenance(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorAlertStaleTitle()
            },
            details: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorAlertStaleMessage()
            }
        )
    }

    /// spec §6.5 — threshold-filtered so the alert can never point at an amount the chain refuses
    /// to pay out; shares the eligible total with the reward row so the two cannot disagree
    private func findClaimableAlert(
        for commonData: SubtensorStakingCommonData
    ) -> StakingAlert? {
        guard
            let chainAsset = commonData.chainAsset,
            let eligibleTotal = eligibleClaimableTotal(for: commonData),
            eligibleTotal > 0 else {
            return nil
        }

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let localizedAmount = balanceViewModelFactory.amountFromValue(
            eligibleTotal.decimal(assetInfo: chainAsset.assetDisplayInfo)
        )

        return .claimRewards(
            title: LocalizableResource { locale in
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorAlertClaimTitle()
            },
            details: LocalizableResource { locale in
                R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.stakingSubtensorAlertClaimMessage(localizedAmount.value(for: locale))
            }
        )
    }

    private func findUnregisteredDelegateAlert(
        for stakingState: Multistaking.SubtensorStakingState
    ) -> StakingAlert? {
        guard stakingState.positions.contains(where: { !$0.isRegistered }) else {
            return nil
        }

        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorHotkeyNotFoundTitle()
        }

        let details = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorHotkeyNotFoundMessage()
        }

        return .nominatorChangeValidators(title: title, details: details)
    }
}
