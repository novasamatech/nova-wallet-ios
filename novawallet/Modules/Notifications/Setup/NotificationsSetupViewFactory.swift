import Foundation
import SoraFoundation

struct NotificationsSetupViewFactory {
    static func createView(settings _: LocalPushSettings?) -> NotificationsSetupViewProtocol? {
        let applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared

        let legalData = LegalData(
            termsUrl: applicationConfig.termsURL,
            privacyPolicyUrl: applicationConfig.privacyPolicyURL
        )

        let interactor = NotificationsSetupInteractor()
        let wireframe = NotificationsSetupWireframe()

        let presenter = NotificationsSetupPresenter(interactor: interactor, wireframe: wireframe, legalData: legalData)
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
