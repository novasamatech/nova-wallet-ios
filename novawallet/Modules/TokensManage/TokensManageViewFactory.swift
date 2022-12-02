import Foundation
import SoraFoundation

struct TokensManageViewFactory {
    static func createView() -> TokensManageViewProtocol? {
        let interactor = TokensManageInteractor()
        let wireframe = TokensManageWireframe()

        let presenter = TokensManagePresenter(interactor: interactor, wireframe: wireframe)

        let view = TokensManageViewController(presenter: presenter, localizationManager: LocalizationManager.shared)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
