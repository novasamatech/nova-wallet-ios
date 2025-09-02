import Foundation
import Foundation_iOS
import Keystore_iOS

struct NotificationsSetupViewFactory {
    static func createView() -> NotificationsSetupViewProtocol? {
        createView(completion: nil)
    }

    static func createView(completion: ((Bool) -> Void)? = nil) -> NotificationsSetupViewProtocol? {
        guard
            let selectedWallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared

        let legalData = LegalData(
            termsUrl: applicationConfig.termsURL,
            privacyPolicyUrl: applicationConfig.privacyPolicyURL
        )

        let interactor = NotificationsSetupInteractor(
            selectedWallet: selectedWallet,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            pushNotificationsFacade: PushNotificationsServiceFacade.shared,
            localPushSettingsFactory: PushNotificationSettingsFactory()
        )

        let wireframe = NotificationsSetupWireframe(
            localizationManager: LocalizationManager.shared,
            completion: completion
        )

        let presenter = NotificationsSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            legalData: legalData,
            localizationManager: LocalizationManager.shared
        )

        let view = NotificationsSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
