import Foundation
import SubstrateSdk
import SoraFoundation
import RobinHood

struct StartStakingInfoViewFactory {
    static func createView(
        stakingOption: Multistaking.ChainAssetOption
    ) -> StartStakingInfoViewProtocol? {
        switch stakingOption.type {
        case .relaychain, .auraRelaychain, .azero, .nominationPools:
            let operationQueue = OperationManagerFacade.sharedDefaultQueue
            let factory = RelaychainStakingStateFactory(
                stakingOption: stakingOption,
                chainRegistry: ChainRegistryFacade.sharedRegistry,
                storageFacade: SubstrateDataStorageFacade.shared,
                eventCenter: EventCenter.shared,
                logger: Logger.shared,
                operationQueue: operationQueue
            )
            return createRelaychainView(
                chainAsset: stakingOption.chainAsset,
                factory: factory,
                operationQueue: operationQueue
            )
        case .parachain, .turing:
            let factory = ParachainStakingStateFactory(
                stakingOption: stakingOption,
                chainRegistry: ChainRegistryFacade.sharedRegistry,
                storageFacade: SubstrateDataStorageFacade.shared,
                eventCenter: EventCenter.shared,
                operationQueue: OperationManagerFacade.sharedDefaultQueue,
                logger: Logger.shared
            )
            return createParachainView(
                chainAsset: stakingOption.chainAsset,
                factory: factory,
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            )
        case .unsupported:
            return nil
        }
    }

    private static func createRelaychainView(
        chainAsset: ChainAsset,
        factory: RelaychainStakingStateFactoryProtocol,
        operationQueue: OperationQueue
    ) -> StartStakingInfoViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = createRelaychainInteractor(
            factory: factory,
            chainAsset: chainAsset,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )

        let wireframe = StartStakingInfoWireframe()
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )
        let startStakingViewModelFactory = StartStakingViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            estimatedEarningsFormatter: NumberFormatter.percentBase.localizableResource()
        )

        let presenter = StartStakingInfoRelaychainPresenter(
            interactor: interactor,
            wireframe: wireframe,
            startStakingViewModelFactory: startStakingViewModelFactory,
            localizationManager: LocalizationManager.shared,
            applicationConfig: ApplicationConfig.shared
        )

        let view = StartStakingInfoViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createRelaychainInteractor(
        factory: RelaychainStakingStateFactoryProtocol,
        chainAsset: ChainAsset,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) -> StartStakingRelaychainInteractor {
        let selectedWalletSettings = SelectedWalletSettings.shared
        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let operationManager = OperationManager(operationQueue: operationQueue)
        let logger = Logger.shared
        let storageFacade = SubstrateDataStorageFacade.shared
        let eventCenter = EventCenter.shared

        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: storageFacade
        )
        let chainItemRepository = substrateRepositoryFactory.createChainStorageItemRepository()

        let stakingRemoteSubscriptionService = StakingRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: chainItemRepository,
            syncOperationManager: operationManager,
            repositoryOperationManager: operationManager,
            logger: logger
        )

        let serviceFactory = StakingServiceFactory(
            chainRegisty: chainRegistry,
            storageFacade: storageFacade,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )

        let substrateDataProviderFactory = SubstrateDataProviderFactory(
            facade: storageFacade,
            operationManager: operationManager
        )

        let childSubscriptionFactory = ChildSubscriptionFactory(
            storageFacade: storageFacade,
            operationManager: operationManager,
            eventCenter: eventCenter,
            logger: logger
        )

        let stakingAccountUpdatingService = StakingAccountUpdatingService(
            chainRegistry: chainRegistry,
            substrateRepositoryFactory: substrateRepositoryFactory,
            substrateDataProviderFactory: substrateDataProviderFactory,
            childSubscriptionFactory: childSubscriptionFactory,
            operationQueue: operationQueue
        )

        return StartStakingRelaychainInteractor(
            chainAsset: chainAsset,
            selectedWalletSettings: selectedWalletSettings,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingAssetSubscriptionService: stakingRemoteSubscriptionService,
            stakingAccountUpdatingService: stakingAccountUpdatingService,
            currencyManager: currencyManager,
            stateFactory: factory,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
    }

    private static func createParachainView(
        chainAsset: ChainAsset,
        factory: ParachainStakingStateFactoryProtocol,
        operationQueue: OperationQueue
    ) -> StartStakingInfoViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = createParachainInteractor(
            factory: factory,
            chainAsset: chainAsset,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )

        let wireframe = StartStakingInfoWireframe()
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )
        let startStakingViewModelFactory = StartStakingViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            estimatedEarningsFormatter: NumberFormatter.percentBase.localizableResource()
        )

        let presenter = StartStakingInfoParachainPresenter(
            interactor: interactor,
            wireframe: wireframe,
            startStakingViewModelFactory: startStakingViewModelFactory,
            localizationManager: LocalizationManager.shared,
            applicationConfig: ApplicationConfig.shared
        )

        let view = StartStakingInfoViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createParachainInteractor(
        factory: ParachainStakingStateFactoryProtocol,
        chainAsset: ChainAsset,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) -> StartStakingParachainInteractor {
        let selectedWalletSettings = SelectedWalletSettings.shared
        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let operationManager = OperationManager(operationQueue: operationQueue)
        let logger = Logger.shared

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let stakingDurationFactory = ParaStkDurationOperationFactory(
            storageRequestFactory: storageRequestFactory,
            blockTimeOperationFactory: BlockTimeOperationFactory(chain: chainAsset.chain)
        )
        let repositoryFactory = SubstrateRepositoryFactory()
        let repository = repositoryFactory.createChainStorageItemRepository()

        let stakingAccountService = ParachainStaking.AccountSubscriptionService(
            chainRegistry: chainRegistry,
            repository: repository,
            syncOperationManager: operationManager,
            repositoryOperationManager: operationManager,
            logger: logger
        )

        let stakingAssetService = ParachainStaking.StakingRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: repository,
            syncOperationManager: operationManager,
            repositoryOperationManager: operationManager,
            logger: logger
        )

        return StartStakingParachainInteractor(
            chainAsset: chainAsset,
            selectedWalletSettings: selectedWalletSettings,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingAssetSubscriptionService: stakingAssetService,
            stakingAccountSubscriptionService: stakingAccountService,
            currencyManager: currencyManager,
            stateFactory: factory,
            chainRegistry: chainRegistry,
            networkInfoFactory: ParaStkNetworkInfoOperationFactory(),
            durationOperationFactory: stakingDurationFactory,
            operationQueue: operationQueue,
            eventCenter: EventCenter.shared
        )
    }
}
