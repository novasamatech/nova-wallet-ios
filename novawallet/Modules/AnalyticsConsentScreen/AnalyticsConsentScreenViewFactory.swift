import Foundation
import Foundation_iOS

struct AnalyticsConsentScreenViewFactory {
    static func createView(
        applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared,
        onEnable: @escaping () -> Void,
        onDecline: @escaping () -> Void
    ) -> AnalyticsConsentScreenViewProtocol? {
        let interactor = AnalyticsConsentScreenInteractor()
        let wireframe = AnalyticsConsentScreenWireframe(onEnable: onEnable, onDecline: onDecline)
        let presenter = AnalyticsConsentScreenPresenter(
            interactor: interactor,
            wireframe: wireframe,
            privacyPolicyURL: applicationConfig.privacyPolicyURL
        )
        let view = AnalyticsConsentScreenViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        view.modalPresentationStyle = .fullScreen
        view.isModalInPresentation = true

        return view
    }
}
