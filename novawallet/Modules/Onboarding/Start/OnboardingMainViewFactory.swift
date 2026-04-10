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

        // The consent banner uses dedicated novasama.io URLs (placeholder until
        // the canonical pages land — see ConsentBannerConstants). The legacy
        // ApplicationConfig.termsURL / privacyPolicyURL still point at the OLD
        // novawallet.io documents and must NOT be reused here.
        let legalData = LegalData(
            termsUrl: ConsentBannerConstants.termsOfServiceURL,
            privacyPolicyUrl: ConsentBannerConstants.privacyNoticeURL
        )

        let interactor = OnboardingMainInteractor(
            secretImportService: secretImportService,
            walletMigrationService: walletMigrationService
        )

        let presenter = OnboardingMainPresenter(
            interactor: interactor,
            wireframe: wireframe,
            legalData: legalData,
            consentService: ConsentService(),
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
