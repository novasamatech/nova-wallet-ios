import Foundation
import SoraFoundation
import RobinHood
import SubstrateSdk

protocol VoteChildPresenterFactoryProtocol {
    func createCrowdloanPresenter(
        from view: CrowdloansViewProtocol,
        wallet: MetaAccountModel
    ) -> VoteChildPresenterProtocol?

    func createGovernancePresenter(
        from view: ReferendumsViewProtocol,
        wallet: MetaAccountModel
    ) -> VoteChildPresenterProtocol?
}

final class VoteChildPresenterFactory {
    let currencyManager: CurrencyManagerProtocol
    let localizationManager: LocalizationManagerProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let jsonDataProviderFactory: JsonDataProviderFactoryProtocol
    let priceProviderFactory: PriceProviderFactoryProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        currencyManager: CurrencyManagerProtocol,
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol = WalletLocalSubscriptionFactory.shared,
        jsonDataProviderFactory: JsonDataProviderFactoryProtocol = JsonDataProviderFactory.shared,
        priceProviderFactory: PriceProviderFactoryProtocol = PriceProviderFactory.shared,
        repositoryFactory: SubstrateRepositoryFactoryProtocol = SubstrateRepositoryFactory(),
        applicationHandler: ApplicationHandlerProtocol = ApplicationHandler(),
        operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue,
        localizationManager: LocalizationManagerProtocol = LocalizationManager.shared,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.currencyManager = currencyManager
        self.chainRegistry = chainRegistry
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.jsonDataProviderFactory = jsonDataProviderFactory
        self.priceProviderFactory = priceProviderFactory
        self.repositoryFactory = repositoryFactory
        self.applicationHandler = applicationHandler
        self.operationQueue = operationQueue
        self.localizationManager = localizationManager
        self.logger = logger
    }

    private func createCrowdloanInteractor(
        from state: CrowdloanSharedState,
        wallet: MetaAccountModel
    ) -> CrowdloanListInteractor {
        let repository = repositoryFactory.createChainStorageItemRepository()

        let operationManager = OperationManager(operationQueue: operationQueue)

        let crowdloanRemoteSubscriptionService = CrowdloanRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: AnyDataProviderRepository(repository),
            operationManager: operationManager,
            logger: logger
        )

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let crowdloanOperationFactory = CrowdloanOperationFactory(
            requestOperationFactory: storageRequestFactory,
            operationManager: operationManager
        )

        return CrowdloanListInteractor(
            selectedMetaAccount: wallet,
            crowdloanState: state,
            chainRegistry: chainRegistry,
            crowdloanOperationFactory: crowdloanOperationFactory,
            crowdloanRemoteSubscriptionService: crowdloanRemoteSubscriptionService,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            jsonDataProviderFactory: jsonDataProviderFactory,
            operationManager: operationManager,
            applicationHandler: applicationHandler,
            currencyManager: currencyManager,
            priceLocalSubscriptionFactory: priceProviderFactory,
            logger: logger
        )
    }
}

extension VoteChildPresenterFactory: VoteChildPresenterFactoryProtocol {
    func createCrowdloanPresenter(
        from _: CrowdloansViewProtocol,
        wallet: MetaAccountModel
    ) -> VoteChildPresenterProtocol? {
        let state = CrowdloanSharedState()

        let interactor = createCrowdloanInteractor(from: state, wallet: wallet)
        let wireframe = CrowdloanListWireframe(state: state)

        let viewModelFactory = CrowdloansViewModelFactory(
            amountFormatterFactory: AssetBalanceFormatterFactory(),
            balanceViewModelFactoryFacade: BalanceViewModelFactoryFacade(
                priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
            )
        )

        let presenter = CrowdloanListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            wallet: wallet,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            crowdloansCalculator: CrowdloansCalculator(),
            accountManagementFilter: AccountManagementFilter(),
            logger: Logger.shared
        )

        return presenter
    }

    func createGovernancePresenter(
        from _: ReferendumsViewProtocol,
        wallet _: MetaAccountModel
    ) -> VoteChildPresenterProtocol? {}
}
