import Foundation
import SoraFoundation
import SoraKeystore

struct NotificationsSetupViewFactory {
    static func createView(delegate: PushNotificationsStatusDelegate?) -> NotificationsSetupViewProtocol? {
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
            servicesFactory: Web3AlertsServicesFactory.shared,
            selectedWallet: selectedWallet,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            settingsMananger: SettingsManager.shared
        )
        let wireframe = NotificationsSetupWireframe()

        let presenter = NotificationsSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            legalData: legalData,
            delegate: delegate
        )
        let termDecorator = LocalizableResource {
            CompoundAttributedStringDecorator.legal(for: $0)
        }

        let view = NotificationsSetupViewController(
            presenter: presenter,
            termDecorator: termDecorator,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
