import Foundation
import SoraFoundation
import SoraKeystore

struct NotificationsSetupViewFactory {
    static func createView(delegate: PushNotificationsStatusDelegate?) -> NotificationsSetupViewProtocol? {
        let applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared

        let legalData = LegalData(
            termsUrl: applicationConfig.termsURL,
            privacyPolicyUrl: applicationConfig.privacyPolicyURL
        )

        let alertService = Web3AlertsSyncServiceFactory.shared.createService()
        let pushNotificationsService = PushNotificationsService(
            service: alertService,
            settingsManager: SettingsManager.shared,
            logger: Logger.shared
        )
        let interactor = NotificationsSetupInteractor(pushNotificationsService: pushNotificationsService)
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
