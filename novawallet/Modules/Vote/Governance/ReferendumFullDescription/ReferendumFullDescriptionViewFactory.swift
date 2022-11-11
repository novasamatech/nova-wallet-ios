import Foundation

struct ReferendumFullDescriptionViewFactory {
    static func createView(
        for title: String,
        description: String
    ) -> ReferendumFullDescriptionViewProtocol? {
        let interactor = ReferendumFullDescriptionInteractor()
        let wireframe = ReferendumFullDescriptionWireframe()

        let presenter = ReferendumFullDescriptionPresenter(
            title: title,
            description: description,
            interactor: interactor,
            wireframe: wireframe
        )

        let view = ReferendumFullDescriptionViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
