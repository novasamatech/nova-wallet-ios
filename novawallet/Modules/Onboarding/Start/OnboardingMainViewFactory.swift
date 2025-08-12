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
        guard let urlHandlingFacade = URLHandlingServiceFacade.shared else {
            Logger.shared.error("Url handling has not been setup")
            return nil
        }

        guard
            let secretImportService: SecretImportServiceProtocol = urlHandlingFacade.findInternalService()
        else {
            Logger.shared.error("Can't find required keystore import service")
            return nil
        }

        guard
            let walletMigrationService: WalletMigrationServiceProtocol = urlHandlingFacade.findInternalService()
        else {
            Logger.shared.error("Can't find required migration service")
            return nil
        }

        let applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared

        let legalData = LegalData(
            termsUrl: applicationConfig.termsURL,
            privacyPolicyUrl: applicationConfig.privacyPolicyURL
        )

        let interactor = OnboardingMainInteractor(
            secretImportService: secretImportService,
            walletMigrationService: walletMigrationService
        )

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
