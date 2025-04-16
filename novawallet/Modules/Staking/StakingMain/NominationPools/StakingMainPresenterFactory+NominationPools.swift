import Foundation
import Foundation_iOS

extension StakingMainPresenterFactory {
    func createNominationPoolsPresenter(
        for chainAsset: ChainAsset,
        view: StakingMainViewProtocol
    ) -> StakingNPoolsPresenter? {
        guard
            let consensus = ConsensusType(asset: chainAsset.asset),
            let state = try? sharedStateFactory.createNominationPools(for: chainAsset, consensus: consensus),
            let currencyManager = CurrencyManager.shared,
            let interactor = createNominationPoolsInteractor(
                state: state,
                currencyManager: currencyManager
            ) else {
            return nil
        }

        let wireframe = StakingNPoolsWireframe(state: state)

        let priceInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let infoViewModelFactory = NetworkInfoViewModelFactory(priceAssetInfoFactory: priceInfoFactory)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceInfoFactory
        )

        let stateViewModelFactory = StakingNPoolsViewModelFactory(balanceViewModelFactory: balanceViewModelFactory)

        let presenter = StakingNPoolsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            infoViewModelFactory: infoViewModelFactory,
            stateViewModelFactory: stateViewModelFactory,
            quantityFormatter: NumberFormatter.quantity.localizableResource(),
            chainAsset: state.chainAsset,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return presenter
    }

    func createNominationPoolsInteractor(
        state: NPoolsStakingSharedStateProtocol,
        currencyManager: CurrencyManagerProtocol
    ) -> StakingNPoolsInteractor? {
        let chainId = state.chainAsset.chain.chainId
        let accountRequest = state.chainAsset.chain.accountRequest()

        guard
            let selectedAccount = SelectedWalletSettings.shared.value?.fetchMetaChainAccount(for: accountRequest),
            let runtimeService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chainId),
            let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: chainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        return .init(
            state: state,
            selectedAccount: selectedAccount,
            npoolsOperationFactory: NominationPoolsOperationFactory(operationQueue: operationQueue),
            connection: connection,
            runtimeCodingService: runtimeService,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            eventCenter: EventCenter.shared,
            applicationHandler: ApplicationHandler(),
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }
}
