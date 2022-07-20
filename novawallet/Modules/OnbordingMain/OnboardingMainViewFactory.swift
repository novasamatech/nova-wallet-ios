import Foundation
import SoraKeystore
import SoraFoundation

final class OnboardingMainViewFactory: OnboardingMainViewFactoryProtocol {
    static func createViewForOnboarding() -> OnboardingMainViewProtocol? {
        let wireframe = OnboardingMainWireframe()
        return createView(for: wireframe)
    }

    static func createViewForAdding() -> OnboardingMainViewProtocol? {
        let wireframe = AddAccount.OnboardingMainWireframe()
        return createView(for: wireframe)
    }

    static func createViewForAccountSwitch() -> OnboardingMainViewProtocol? {
        let wireframe = SwitchAccount.OnboardingMainWireframe()
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

        let locale: Locale = LocalizationManager.shared.selectedLocale

        let legalData = LegalData(
            termsUrl: applicationConfig.termsURL,
            privacyPolicyUrl: applicationConfig.privacyPolicyURL
        )

        let interactor = OnboardingMainInteractor(keystoreImportService: kestoreImportService)
        let presenter = OnboardingMainPresenter(
            interactor: interactor,
            wireframe: wireframe,
            legalData: legalData,
            locale: locale
        )

        let termDecorator = CompoundAttributedStringDecorator.legal(for: locale)

        let view = OnboardingMainViewController(
            presenter: presenter,
            termDecorator: termDecorator,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
