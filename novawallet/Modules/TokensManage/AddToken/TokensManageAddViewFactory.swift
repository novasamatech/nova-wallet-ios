import Foundation
import SoraFoundation

struct TokensManageAddViewFactory {
    static func createView(for _: ChainModel) -> TokensManageAddViewProtocol? {
        let interactor = TokensManageAddInteractor()
        let wireframe = TokensManageAddWireframe()

        let presenter = TokensManageAddPresenter(interactor: interactor, wireframe: wireframe)

        let view = TokensManageAddViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
