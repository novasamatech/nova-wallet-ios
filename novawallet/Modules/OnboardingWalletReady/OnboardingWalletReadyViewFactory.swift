import Foundation
import SoraFoundation

struct OnboardingWalletReadyViewFactory {
    static func createView(walletName: String) -> OnboardingWalletReadyViewProtocol? {
        let interactor = OnboardingWalletReadyInteractor()
        let wireframe = OnboardingWalletReadyWireframe()

        let presenter = OnboardingWalletReadyPresenter(
            interactor: interactor,
            wireframe: wireframe,
            walletName: walletName
        )

        let view = OnboardingWalletReadyViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
