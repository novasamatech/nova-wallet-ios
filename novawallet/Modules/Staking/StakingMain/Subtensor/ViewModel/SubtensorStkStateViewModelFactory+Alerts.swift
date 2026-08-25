import Foundation
import Foundation_iOS

extension SubtensorStkStateViewModelFactory {
    func createAlerts(
        for stakingState: Multistaking.SubtensorStakingState
    ) -> [StakingAlert] {
        var alerts: [StakingAlert] = []

        if let unregisteredDelegate = findUnregisteredDelegateAlert(for: stakingState) {
            alerts.append(unregisteredDelegate)
        }

        return alerts
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
