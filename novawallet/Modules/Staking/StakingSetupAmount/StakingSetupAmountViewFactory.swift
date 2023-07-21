import Foundation

struct StakingSetupAmountViewFactory {
    static func createView() -> StakingSetupAmountViewProtocol? {
        let interactor = StakingSetupAmountInteractor()
        let wireframe = StakingSetupAmountWireframe()

        let presenter = StakingSetupAmountPresenter(interactor: interactor, wireframe: wireframe)

        let view = StakingSetupAmountViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
