import Foundation
import SoraFoundation

struct SwipeGovVotingListViewFactory {
    static func createView(
        with sharedState: GovernanceSharedState,
        metaAccount: MetaAccountModel
    ) -> SwipeGovVotingListViewProtocol? {
        let chain = sharedState.settings.value.chain
        let substrateStorage = SubstrateDataStorageFacade.shared
        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared

        let votingBasketSubscriptionFactory = VotingBasketLocalSubscriptionFactory(
            chainRegistry: sharedState.chainRegistry,
            storageFacade: substrateStorage,
            operationManager: operationManager,
            logger: logger
        )

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory(
            chainRegistry: sharedState.chainRegistry,
            storageFacade: substrateStorage,
            operationManager: operationManager,
            logger: logger
        )

        let interactor = SwipeGovVotingListInteractor(
            chain: chain,
            metaAccount: metaAccount,
            votingBasketSubscriptionFactory: votingBasketSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory
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
