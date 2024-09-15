import Foundation
import SoraFoundation
import Operation_iOS

struct SwipeGovVotingListViewFactory {
    static func createView(
        with sharedState: GovernanceSharedState,
        metaAccount: MetaAccountModel
    ) -> SwipeGovVotingListViewProtocol? {
        let chain = sharedState.settings.value.chain
        let substrateStorage = SubstrateDataStorageFacade.shared
        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

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

        let govMetadataLocalSubscriptionFactory = sharedState.govMetadataLocalSubscriptionFactory

        let mapper = VotingBasketItemMapper()

        let filter = NSPredicate.votingBasketItems(
            for: chain.chainId,
            metaId: metaAccount.metaId
        )
        let repository = substrateStorage.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let interactor = SwipeGovVotingListInteractor(
            observableState: sharedState.observableState,
            chain: chain,
            metaAccount: metaAccount,
            repository: AnyDataProviderRepository(repository),
            selectedGovOption: sharedState.settings.value,
            votingBasketSubscriptionFactory: votingBasketSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            govMetadataLocalSubscriptionFactory: govMetadataLocalSubscriptionFactory,
            operationQueue: operationQueue
        )

        let wireframe = SwipeGovVotingListWireframe(sharedState: sharedState)

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
