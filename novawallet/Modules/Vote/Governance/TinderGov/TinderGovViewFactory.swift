import Foundation

struct TinderGovViewFactory {
    static func createView(with referendums: [ReferendumLocal]) -> TinderGovViewProtocol? {
        let wireframe = TinderGovWireframe()
        let interactor = TinderGovInteractor(referendums: referendums)

        let presenter = TinderGovPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: TinderGovViewModelFactory()
        )

        let view = TinderGovViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
