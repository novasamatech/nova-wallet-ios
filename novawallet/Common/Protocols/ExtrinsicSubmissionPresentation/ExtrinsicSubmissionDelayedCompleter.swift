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
    func switchToWalletIfNeeded(
        _ newWallet: MetaAccountModel,
        completion: @escaping () -> Void
    ) {
        guard
            let currentWallet = selectedWalletSettings.value,
            currentWallet.metaId != newWallet.metaId
        else {
            completion()
            return
        }

        selectedWalletSettings.save(
            value: newWallet,
            runningCompletionIn: .main
        ) { result in
            if case .success = result {
                self.eventCenter.notify(with: SelectedWalletSwitched())
            }

            completion()
        }
    }
}

extension ExtrinsicSubmissionDelayedCompleter: ExtrinsicSubmissionCompliting {
    func handleCompletion(
        from view: ControllerBackedProtocol?,
        alertPresenting _: ModalAlertPresenting,
        params: ExtrinsicSubmissionPresentingParams
    ) -> Bool {
        guard
            let sender = params.sender,
            let delayedCallWallets = sender.firstDelayedCallWallets(),
            let controller = view?.controller else {
            return false
        }

        switchToWalletIfNeeded(delayedCallWallets.delaying) {
            MainTransitionHelper.transitToMainTabBarController(
                selectingIndex: MainTabBarIndex.wallet,
                closing: controller,
                postProcessing: .postTransition { tabBar in
                    tabBar.presentDelayedOperationCreated()
                },
                animated: true
            )
        }

        return true
    }
}
