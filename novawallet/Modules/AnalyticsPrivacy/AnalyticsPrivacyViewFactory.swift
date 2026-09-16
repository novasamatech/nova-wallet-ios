import Foundation_iOS
import NovaAnalytics

enum AnalyticsPrivacyViewFactory {
    static func createView(
        consentManager: AnalyticsConsentManagerProtocol = AnalyticsFacadeFactory.createDefault().consent,
        applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared
    ) -> AnalyticsPrivacyViewProtocol? {
        let interactor = AnalyticsPrivacyInteractor(consentManager: consentManager)
        let wireframe = AnalyticsPrivacyWireframe()
        let presenter = AnalyticsPrivacyPresenter(
            interactor: interactor,
            wireframe: wireframe,
            privacyPolicyURL: applicationConfig.privacyPolicyURL
        )
        let view = AnalyticsPrivacyViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
