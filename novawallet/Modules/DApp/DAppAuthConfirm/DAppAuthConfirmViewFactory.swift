import Foundation
import Foundation_iOS

struct DAppAuthConfirmViewFactory {
    static func createView(
        for request: DAppAuthRequest,
        delegate: DAppAuthDelegate
    ) -> DAppAuthConfirmViewProtocol? {
        let wireframe = DAppAuthConfirmWireframe()

        let localizationManager = LocalizationManager.shared

        let viewModelFactory = DAppAuthViewModelFactory(
            iconViewModelFactory: DAppIconViewModelFactory()
        )

        let presenter = DAppAuthConfirmPresenter(
            wireframe: wireframe,
            request: request,
            delegate: delegate,
            viewModelFactory: viewModelFactory
        )

        let view = DAppAuthConfirmViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view

        return view
    }
}
