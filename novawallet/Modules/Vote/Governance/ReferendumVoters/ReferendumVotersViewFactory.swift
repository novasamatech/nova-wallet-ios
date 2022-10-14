import Foundation

struct ReferendumVotersViewFactory {
    static func createView(
        state: GovernanceSharedState,
        referendum: ReferendumLocal,
        type: ReferendumVotersType
    ) -> ReferendumVotersViewProtocol? {
        let interactor = ReferendumVotersInteractor()
        let wireframe = ReferendumVotersWireframe()

        let presenter = ReferendumVotersPresenter(interactor: interactor, wireframe: wireframe)

        let view = ReferendumVotersViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
