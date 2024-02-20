import Foundation
import SoraFoundation

struct StakingRewardsNotificationsViewFactory {
    static func createView(
        selectedChains _: Set<ChainModel.Id>,
        completion: @escaping (Set<ChainModel.Id>, StakingChainsCount) -> Void
    ) -> StakingRewardsNotificationsViewProtocol? {
        let interactor = StakingRewardsNotificationsInteractor(chainRegistry: ChainRegistryFacade.sharedRegistry)
        let wireframe = StakingRewardsNotificationsWireframe(completion: completion)

        let presenter = StakingRewardsNotificationsPresenter(
            interactor: interactor,
            wireframe: wireframe
        )

        let view = StakingRewardsNotificationsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
