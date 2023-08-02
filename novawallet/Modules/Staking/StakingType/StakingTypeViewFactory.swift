import Foundation

struct StakingTypeViewFactory {
    static func createView() -> StakingTypeViewProtocol? {
        let interactor = StakingTypeInteractor()
        let wireframe = StakingTypeWireframe()

        let presenter = StakingTypePresenter(interactor: interactor, wireframe: wireframe)

        let view = StakingTypeViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
