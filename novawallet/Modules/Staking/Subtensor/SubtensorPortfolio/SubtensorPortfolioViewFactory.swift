import Foundation
import Foundation_iOS

enum SubtensorPortfolioViewFactory {
    static func createView(for stakingOption: Multistaking.ChainAssetOption) -> SubtensorPortfolioViewProtocol? {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let stateFactory = StakingSharedStateFactory(
            storageFacade: SubstrateDataStorageFacade.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            delegatedAccountSyncService: nil,
            eventCenter: EventCenter.shared,
            syncOperationQueue: operationQueue,
            repositoryOperationQueue: operationQueue,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        guard
            let state = try? stateFactory.createSubtensorStaking(for: stakingOption),
            let account = SelectedWalletSettings.shared.value?.fetchMetaChainAccount(
                for: stakingOption.chainAsset.chain.accountRequest()
            ),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = createInteractor(
            state: state,
            account: account,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )

        let presenter = SubtensorPortfolioPresenter(
            interactor: interactor,
            wireframe: SubtensorPortfolioWireframe(state: state),
            viewModelFactory: SubtensorPortfolioViewModelFactory(
                chainAsset: stakingOption.chainAsset,
                priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
            ),
            account: account,
            chainAsset: stakingOption.chainAsset,
            localizationManager: LocalizationManager.shared
        )

        let view = SubtensorPortfolioViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        view.hidesBottomBarWhenPushed = true

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}

private extension SubtensorPortfolioViewFactory {
    static func createInteractor(
        state: SubtensorStakingSharedStateProtocol,
        account: MetaChainAccountResponse,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) -> SubtensorPortfolioInteractor {
        let earnServices = state.earnServices

        return SubtensorPortfolioInteractor(
            state: state,
            account: account,
            selectedWalletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            applicationHandler: ApplicationHandler(),
            catalogueService: earnServices.catalogueService,
            yieldService: earnServices.yieldService,
            earnConfigProvider: earnServices.earnConfigProvider,
            priceHistoryService: earnServices.priceHistoryService,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            coingeckoFactory: CoingeckoOperationFactory(),
            operationQueue: operationQueue,
            logger: Logger.shared
        )
    }
}
