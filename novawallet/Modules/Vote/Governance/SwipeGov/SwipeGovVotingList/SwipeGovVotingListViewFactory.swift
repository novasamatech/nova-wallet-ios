import Foundation
import SoraFoundation

struct SwipeGovVotingListViewFactory {
    static func createView(
        with sharedState: GovernanceSharedState,
        metaId: MetaAccountModel.Id
    ) -> SwipeGovVotingListViewProtocol? {
        let substrateStorage = SubstrateDataStorageFacade.shared

        let votingBasketSubscriptionFactory = VotingBasketLocalSubscriptionFactory(
            chainRegistry: sharedState.chainRegistry,
            storageFacade: substrateStorage,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let interactor = SwipeGovVotingListInteractor(
            chainId: sharedState.settings.value.chain.chainId,
            metaId: metaId,
            votingBasketSubscriptionFactory: votingBasketSubscriptionFactory
        )
        let wireframe = SwipeGovVotingListWireframe()

        let presenter = SwipeGovVotingListPresenter(
            interactor: interactor,
            wireframe: wireframe
        )

        let view = SwipeGovVotingListViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
