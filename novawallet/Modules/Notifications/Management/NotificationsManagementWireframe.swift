import Foundation
import Foundation_iOS

final class NotificationsManagementWireframe: NotificationsManagementWireframeProtocol, ModalAlertPresenting {
    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func showWallets(
        from view: ControllerBackedProtocol?,
        initState: [Web3Alert.LocalWallet]?,
        completion: @escaping ([Web3Alert.LocalWallet]) -> Void
    ) {
        guard let walletsView = NotificationWalletListViewFactory.createView(
            initState: .modified(initState),
            completion: completion
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            walletsView.controller,
            animated: true
        )
    }

    func showStakingRewardsSetup(
        from view: ControllerBackedProtocol?,
        selectedChains: Web3Alert.Selection<Set<Web3Alert.LocalChainId>>?,
        completion: @escaping (Web3Alert.Selection<Set<Web3Alert.LocalChainId>>?) -> Void
    ) {
        guard let stakingRewardsView = StakingRewardsNotificationsViewFactory.createView(
            selectedChains: selectedChains,
            completion: completion
        ) else {
            return
        }
        view?.controller.navigationController?.pushViewController(
            stakingRewardsView.controller,
            animated: true
        )
    }

    func showGovSetup(
        from view: ControllerBackedProtocol?,
        settings: GovernanceNotificationsModel,
        completion: @escaping (GovernanceNotificationsModel) -> Void
    ) {
        guard let govNotificationsView = GovernanceNotificationsViewFactory.createView(
            settings: settings,
            completion: completion
        ) else {
            return
        }
        view?.controller.navigationController?.pushViewController(
            govNotificationsView.controller,
            animated: true
        )
    }

    func showMultisigSetup(
        from view: (any ControllerBackedProtocol)?,
        settings: MultisigNotificationsModel,
        selectedMetaIds: Set<MetaAccountModel.Id>,
        completion: @escaping (MultisigNotificationsModel) -> Void
    ) {
        guard let multisigNotificationsView = MultisigNotificationsViewFactory.createView(
            with: settings,
            selectedMetaIds: selectedMetaIds,
            completion: completion
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            multisigNotificationsView.controller,
            animated: true
        )
    }

    func complete(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

    func saved(on view: ControllerBackedProtocol?) {
        let title = R.string.localizable
            .commonSaved(preferredLanguages: localizationManager.selectedLocale.rLanguages)

        presentSuccessNotification(title, from: view) {
            // Completion is called after viewDidAppear so we need to schedule transition to the next run loop
            DispatchQueue.main.async {
                view?.controller.navigationController?.popViewController(animated: true)
            }
        }
    }
}
