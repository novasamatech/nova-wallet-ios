import Foundation

struct ReferendumFullDescriptionViewFactory {
    static func createView(state _: GovernanceSharedState, referendum _: ReferendumLocal) -> ReferendumFullDescriptionViewProtocol? {
        let interactor = ReferendumFullDescriptionInteractor()
        let wireframe = ReferendumFullDescriptionWireframe()

        let presenter = ReferendumFullDescriptionPresenter(interactor: interactor, wireframe: wireframe)

        let view = ReferendumFullDescriptionViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
