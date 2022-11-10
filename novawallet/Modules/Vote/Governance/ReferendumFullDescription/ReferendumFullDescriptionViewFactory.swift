import Foundation

struct ReferendumFullDescriptionViewFactory {
    static func createView(
        for _: ReferendumMetadataLocal
    ) -> ReferendumFullDescriptionViewProtocol? {
        let interactor = ReferendumFullDescriptionInteractor()
        let wireframe = ReferendumFullDescriptionWireframe()

        let presenter = ReferendumFullDescriptionPresenter(interactor: interactor, wireframe: wireframe)

        let view = ReferendumFullDescriptionViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
