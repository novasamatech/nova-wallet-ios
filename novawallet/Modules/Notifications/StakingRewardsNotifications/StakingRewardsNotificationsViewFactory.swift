import Foundation
import SoraFoundation

struct StakingRewardsNotificationsViewFactory {
    static func createView(
        selectedChains: Web3Alert.Selection<Set<ChainModel.Id>>?,
        completion: @escaping (Web3Alert.Selection<Set<ChainModel.Id>>?) -> Void
    ) -> StakingRewardsNotificationsViewProtocol? {
        let interactor = StakingRewardsNotificationsInteractor(chainRegistry: ChainRegistryFacade.sharedRegistry)
        let wireframe = StakingRewardsNotificationsWireframe(completion: completion)

        let presenter = StakingRewardsNotificationsPresenter(
            initialState: selectedChains,
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
