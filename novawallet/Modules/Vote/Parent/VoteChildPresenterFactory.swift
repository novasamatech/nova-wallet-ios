import Foundation
import Foundation_iOS
import Operation_iOS
import SubstrateSdk

protocol VoteChildPresenterFactoryProtocol {
    func createCrowdloanPresenter(
        from view: CrowdloansViewProtocol,
        wallet: MetaAccountModel
    ) -> VoteChildPresenterProtocol?

    func createGovernancePresenter(
        from view: ReferendumsViewProtocol,
        wallet: MetaAccountModel,
        referendumsInitState: ReferendumsInitState?
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
    let substrateStorageFacade: StorageFacadeProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        currencyManager: CurrencyManagerProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol = WalletLocalSubscriptionFactory.shared,
        jsonDataProviderFactory: JsonDataProviderFactoryProtocol = JsonDataProviderFactory.shared,
        priceProviderFactory: PriceProviderFactoryProtocol = PriceProviderFactory.shared,
        repositoryFactory: SubstrateRepositoryFactoryProtocol = SubstrateRepositoryFactory(),
        substrateStorageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared,
        eventCenter: EventCenterProtocol = EventCenter.shared,
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
        self.substrateStorageFacade = substrateStorageFacade
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.localizationManager = localizationManager
        self.logger = logger
    }

    private func createCrowdloanInteractor(
        from state: CrowdloanSharedState,
        wallet: MetaAccountModel
    ) -> CrowdloanListInteractor {
        let serviceFactory = VoteServiceFactory(
            chainRegisty: chainRegistry,
            storageFacade: substrateStorageFacade,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )

        return CrowdloanListInteractor(
            selectedMetaAccount: wallet,
            crowdloanState: state,
            chainRegistry: chainRegistry,
            voteServiceFactory: serviceFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            jsonDataProviderFactory: jsonDataProviderFactory,
            priceLocalSubscriptionFactory: priceProviderFactory,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            currencyManager: currencyManager,
            logger: logger
        )
    }

    private func createGovernanceInteractor(
        for state: GovernanceSharedState,
        wallet: MetaAccountModel
    ) -> ReferendumsInteractor {
        let serviceFactory = VoteServiceFactory(
            chainRegisty: chainRegistry,
            storageFacade: substrateStorageFacade,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )

        let localizationManager = LocalizationManager.shared

        let interactor = ReferendumsInteractor(
            eventCenter: EventCenter.shared,
            selectedMetaAccount: wallet,
            governanceState: state,
            chainRegistry: chainRegistry,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceProviderFactory,
            serviceFactory: serviceFactory,
            applicationHandler: applicationHandler,
            operationQueue: operationQueue,
            currencyManager: currencyManager,
            localizationManager: localizationManager
        )

        return interactor
    }
}

extension VoteChildPresenterFactory: VoteChildPresenterFactoryProtocol {
    func createCrowdloanPresenter(
        from view: CrowdloansViewProtocol,
        wallet: MetaAccountModel
    ) -> VoteChildPresenterProtocol? {
        let state = CrowdloanSharedState()

        let interactor = createCrowdloanInteractor(from: state, wallet: wallet)
        let wireframe = CrowdloanListWireframe(state: state)

        let viewModelFactory = CrowdloansViewModelFactory(
            balanceViewModelFactoryFacade: BalanceViewModelFactoryFacade(
                priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
            )
        )

        let presenter = CrowdloanListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            appearanceFacade: AppearanceFacade.shared,
            privacyStateManager: PrivacyStateManager.shared,
            logger: Logger.shared
        )

        presenter.view = view
        view.presenter = presenter
        interactor.presenter = presenter

        return presenter
    }

    func createGovernancePresenter(
        from view: ReferendumsViewProtocol,
        wallet: MetaAccountModel,
        referendumsInitState: ReferendumsInitState?
    ) -> VoteChildPresenterProtocol? {
        let state = GovernanceSharedState()

        let interactor = createGovernanceInteractor(
            for: state,
            wallet: wallet
        )

        let wireframe = ReferendumsWireframe(state: state)

        let statusViewModelFactory = ReferendumStatusViewModelFactory()

        let indexFormatter = NumberFormatter.index.localizableResource()

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()

        let stringDisplayViewModelFactory = ReferendumDisplayStringFactory()

        let viewModelFactory = ReferendumsModelFactory(
            referendumMetadataViewModelFactory: ReferendumMetadataViewModelFactory(indexFormatter: indexFormatter),
            statusViewModelFactory: statusViewModelFactory,
            assetBalanceFormatterFactory: assetBalanceFormatterFactory,
            stringDisplayViewModelFactory: stringDisplayViewModelFactory,
            percentFormatter: NumberFormatter.referendumPercent.localizableResource(),
            indexFormatter: NumberFormatter.index.localizableResource(),
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )

        let activityViewModelFactory = ReferendumsActivityViewModelFactory(
            assetBalanceFormatterFactory: assetBalanceFormatterFactory
        )

        let swipeGovViewModelFactory = SwipeGovViewModelFactory()

        let presenter = ReferendumsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            observableState: state.observableState,
            viewModelFactory: viewModelFactory,
            swipeGovViewModelFactory: swipeGovViewModelFactory,
            activityViewModelFactory: activityViewModelFactory,
            statusViewModelFactory: statusViewModelFactory,
            assetBalanceFormatterFactory: assetBalanceFormatterFactory,
            selectedMetaAccount: wallet,
            accountManagementFilter: AccountManagementFilter(),
            sorting: ReferendumsTimeSortingProvider(),
            govBalanceCalculatorFactory: GovBalanceCalculatorFactory(),
            localizationManager: localizationManager,
            appearanceFacade: AppearanceFacade.shared,
            privacyStateManager: PrivacyStateManager.shared,
            logger: logger
        )

        presenter.view = view
        presenter.referendumsInitState = referendumsInitState
        view.presenter = presenter
        interactor.presenter = presenter

        return presenter
    }
}
