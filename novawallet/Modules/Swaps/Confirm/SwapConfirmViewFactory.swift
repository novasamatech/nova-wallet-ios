import Foundation
import SoraFoundation

struct SwapConfirmViewFactory {
    static func createView() -> SwapConfirmViewProtocol? {
        let interactor = SwapConfirmInteractor()
        let wireframe = SwapConfirmWireframe()

        let presenter = SwapConfirmPresenter(interactor: interactor, wireframe: wireframe)

        let view = SwapConfirmViewController(presenter: presenter,
                                             localizationManager: LocalizationManager.shared)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
