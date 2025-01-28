import Foundation

struct MythosStkClaimRewardsViewFactory {
    static func createView() -> MythosStkClaimRewardsViewProtocol? {
        let interactor = MythosStkClaimRewardsInteractor()
        let wireframe = MythosStkClaimRewardsWireframe()

        let presenter = MythosStkClaimRewardsPresenter(interactor: interactor, wireframe: wireframe)

        let view = MythosStkClaimRewardsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
