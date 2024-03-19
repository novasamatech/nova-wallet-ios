import Foundation
import SoraFoundation
import SoraKeystore

struct NotificationsManagementViewFactory {
    static func createView() -> NotificationsManagementViewProtocol? {
        guard
            let selectedWallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let interactor = NotificationsManagementInteractor(
            pushNotificationsFacade: PushNotificationsServiceFacade.shared,
            settingsLocalSubscriptionFactory: SettingsLocalSubscriptionFactory.shared,
            localPushSettingsFactory: PushNotificationSettingsFactory(),
            selectedWallet: selectedWallet,
            chainRegistry: ChainRegistryFacade.sharedRegistry
        )

        let wireframe = NotificationsManagementWireframe()

        let viewModelFactory = NotificationsManagemenViewModelFactory(
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )

        let presenter = NotificationsManagementPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = NotificationsManagementViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
