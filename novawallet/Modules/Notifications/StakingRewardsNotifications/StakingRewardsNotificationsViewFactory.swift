import Foundation
import SoraFoundation

struct StakingRewardsNotificationsViewFactory {
    static func createView() -> StakingRewardsNotificationsViewProtocol? {
        let interactor = StakingRewardsNotificationsInteractor()
        let wireframe = StakingRewardsNotificationsWireframe()

        let presenter = StakingRewardsNotificationsPresenter(interactor: interactor, wireframe: wireframe)

        let view = StakingRewardsNotificationsViewController(presenter: presenter, localizationManager: LocalizationManager.shared)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
