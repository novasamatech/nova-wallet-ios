import Foundation
import SoraFoundation

struct SwipeGovVotingListViewFactory {
    static func createView() -> SwipeGovVotingListViewProtocol? {
        let interactor = SwipeGovVotingListInteractor()
        let wireframe = SwipeGovVotingListWireframe()

        let presenter = SwipeGovVotingListPresenter(
            interactor: interactor,
            wireframe: wireframe
        )

        let view = SwipeGovVotingListViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
