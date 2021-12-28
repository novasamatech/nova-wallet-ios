import Foundation
import SoraFoundation

struct DAppAuthConfirmViewFactory {
    static func createView(
        for request: DAppAuthRequest,
        delegate: DAppAuthDelegate
    ) -> DAppAuthConfirmViewProtocol? {
        let wireframe = DAppAuthConfirmWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = DAppAuthConfirmPresenter(
            wireframe: wireframe,
            request: request,
            delegate: delegate,
            viewModelFactory: DAppAuthViewModelFactory()
        )

        let view = DAppAuthConfirmViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view

        return view
    }
}
