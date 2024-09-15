import Foundation
import SoraFoundation

struct SwipeGovVotingListViewFactory {
    static func createView(
        with sharedState: GovernanceSharedState,
        metaId: MetaAccountModel.Id
    ) -> SwipeGovVotingListViewProtocol? {
        let chain = sharedState.settings.value.chain
        let substrateStorage = SubstrateDataStorageFacade.shared

        let votingBasketSubscriptionFactory = VotingBasketLocalSubscriptionFactory(
            chainRegistry: sharedState.chainRegistry,
            storageFacade: substrateStorage,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let interactor = SwipeGovVotingListInteractor(
            chain: chain,
            metaId: metaId,
            votingBasketSubscriptionFactory: votingBasketSubscriptionFactory
        )
        let wireframe = SwipeGovVotingListWireframe()

        let localizationManager = LocalizationManager.shared
        let referendumStringFactory = ReferendumDisplayStringFactory()
        let viewModelfactory = SwipeGovVotingListViewModelFactory(votesStringFactory: referendumStringFactory)

        let presenter = SwipeGovVotingListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            viewModelFactory: viewModelfactory,
            localizationManager: localizationManager
        )

        let view = SwipeGovVotingListViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
