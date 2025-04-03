import Foundation
import Foundation_iOS
import Operation_iOS

struct SwipeGovVotingListViewFactory {
    static func createView(with sharedState: GovernanceSharedState) -> SwipeGovVotingListViewProtocol? {
        guard
            let option = sharedState.settings.value,
            let assetInfo = option.chain.utilityAssetDisplayInfo(),
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(for: sharedState) else {
            return nil
        }

        let wireframe = SwipeGovVotingListWireframe(sharedState: sharedState)

        let localizationManager = LocalizationManager.shared
        let referendumStringFactory = ReferendumDisplayStringFactory()

        let votingListViewModelFactory = SwipeGovVotingListViewModelFactory(
            votesStringFactory: referendumStringFactory
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let presenter = SwipeGovVotingListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: option.chain,
            observableState: sharedState.observableState,
            votingListViewModelFactory: votingListViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            govBalanceCalculator: GovernanceBalanceCalculator(governanceType: option.type),
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

    private static func createInteractor(for state: GovernanceSharedState) -> SwipeGovVotingListInteractor? {
        guard
            let metaAccount = SelectedWalletSettings.shared.value,
            let option = state.settings.value else {
            return nil
        }

        let chain = option.chain
        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let votingBasketSubscriptionFactory = VotingBasketLocalSubscriptionFactory(
            chainRegistry: state.chainRegistry,
            storageFacade: UserDataStorageFacade.shared,
            operationManager: operationManager,
            logger: logger
        )

        let govMetadataLocalSubscriptionFactory = state.govMetadataLocalSubscriptionFactory

        let repository = SwipeGovRepositoryFactory.createVotingItemsRepository(
            for: chain.chainId,
            metaId: metaAccount.metaId,
            using: UserDataStorageFacade.shared
        )

        return SwipeGovVotingListInteractor(
            observableState: state.observableState,
            chain: chain,
            metaAccount: metaAccount,
            repository: repository,
            selectedGovOption: state.settings.value,
            votingBasketSubscriptionFactory: votingBasketSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            govMetadataLocalSubscriptionFactory: govMetadataLocalSubscriptionFactory,
            govBalanceCalculator: GovernanceBalanceCalculator(governanceType: option.type),
            operationQueue: operationQueue
        )
    }
}
