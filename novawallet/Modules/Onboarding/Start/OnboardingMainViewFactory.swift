import Foundation
import Keystore_iOS
import Foundation_iOS

final class OnboardingMainViewFactory: OnboardingMainViewFactoryProtocol {
    static func createViewForOnboarding() -> OnboardingMainViewProtocol? {
        let wireframe = OnboardingMainWireframe()
        return createView(for: wireframe)
    }

    private static func createView(
        for wireframe: OnboardingMainWireframeProtocol
    ) -> OnboardingMainViewProtocol? {
        guard let kestoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService()
        else {
            Logger.shared.error("Can't find required keystore import service")
            return nil
        }

        let applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared

        let legalData = LegalData(
            termsUrl: applicationConfig.termsURL,
            privacyPolicyUrl: applicationConfig.privacyPolicyURL
        )

        let interactor = OnboardingMainInteractor(keystoreImportService: kestoreImportService)
        let presenter = OnboardingMainPresenter(
            interactor: interactor,
            wireframe: wireframe,
            legalData: legalData,
            locale: LocalizationManager.shared.selectedLocale
        )

        let view = OnboardingMainViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
