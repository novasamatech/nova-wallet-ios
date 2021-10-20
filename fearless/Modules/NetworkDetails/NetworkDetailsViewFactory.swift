import Foundation
import SoraFoundation

struct NetworkDetailsViewFactory {
    static func createView(chainModel: ChainModel) -> NetworkDetailsViewProtocol? {
        let interactor = NetworkDetailsInteractor()
        let wireframe = NetworkDetailsWireframe()

        let presenter = NetworkDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: NetworkDetailsViewModelFactory(),
            chainModel: chainModel,
            localizationManager: LocalizationManager.shared
        )

        let view = NetworkDetailsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
