import Foundation

final class ExtrinsicSubmissionDelayedCompleter {
    let selectedWalletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol

    init(
        selectedWalletSettings: SelectedWalletSettings = SelectedWalletSettings.shared,
        eventCenter: EventCenterProtocol = EventCenter.shared
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.eventCenter = eventCenter
    }
}

private extension ExtrinsicSubmissionDelayedCompleter {
    func switchToWalletIfNeeded(_ newWallet: MetaAccountModel) {
        guard
            let currentWallet = selectedWalletSettings.value,
            currentWallet.metaId != newWallet.metaId else {
            return
        }

        selectedWalletSettings.save(
            value: newWallet,
            runningCompletionIn: .main
        ) { result in
            if case .success = result {
                self.eventCenter.notify(with: SelectedWalletSwitched())
            }
        }
    }
}

extension ExtrinsicSubmissionDelayedCompleter: ExtrinsicSubmissionCompliting {
    func handleCompletion(
        from view: ControllerBackedProtocol?,
        alertPresenting _: ModalAlertPresenting,
        sender: ExtrinsicSenderResolution?,
        completionAction _: ExtrinsicSubmissionPresentingAction,
        locale _: Locale
    ) -> Bool {
        guard
            let sender,
            let delayedCallWallet = sender.firstDelayedCallWallet(),
            let controller = view?.controller else {
            return false
        }

        MainTransitionHelper.transitToMainTabBarController(
            closing: controller,
            animated: true
        )

        switchToWalletIfNeeded(delayedCallWallet)

        return true
    }
}
