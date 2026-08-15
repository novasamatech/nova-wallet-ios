import Foundation
import UIKit_iOS
import Foundation_iOS

struct LegalConsentViewFactory {
    static func createView(
        legalConsentRepository: LegalConsentRepositoryProtocol = LegalConsentRepository.shared,
        completion: @escaping () -> Void
    ) -> LegalConsentViewProtocol {
        let applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared

        let legalData = LegalData(
            termsUrl: applicationConfig.termsURL,
            privacyPolicyUrl: applicationConfig.privacyPolicyURL
        )

        let interactor = LegalConsentInteractor(legalConsentRepository: legalConsentRepository)
        let wireframe = LegalConsentWireframe(completion: completion)

        let presenter = LegalConsentPresenter(
            interactor: interactor,
            wireframe: wireframe,
            legalData: legalData,
            localizationManager: LocalizationManager.shared
        )

        let view = LegalConsentViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        let factory = ModalSheetPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.novaNonDismissable
        )

        view.modalTransitioningFactory = factory
        view.modalPresentationStyle = .custom

        return view
    }
}
