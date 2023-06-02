import Foundation

struct StakingDashboardViewFactory {
    static func createView() -> StakingDashboardViewProtocol? {
        let interactor = StakingDashboardInteractor()
        let wireframe = StakingDashboardWireframe()

        let presenter = StakingDashboardPresenter(interactor: interactor, wireframe: wireframe)

        let view = StakingDashboardViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}