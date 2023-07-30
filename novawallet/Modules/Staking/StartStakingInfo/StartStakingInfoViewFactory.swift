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
            return createRelaychainView(stakingOption: stakingOption)
        case .parachain, .turing:
            return createParachainView(for: stakingOption)
        case .unsupported:
            return nil
        }
    }

    private static func createRelaychainView(
        stakingOption: Multistaking.ChainAssetOption
    ) -> StartStakingInfoViewProtocol? {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let stateFactory = StakingSharedStateFactory(
            storageFacade: SubstrateDataStorageFacade.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            eventCenter: EventCenter.shared,
            syncOperationQueue: operationQueue,
            repositoryOperationQueue: operationQueue,
            logger: Logger.shared
        )

        guard
            let state = try? stateFactory.createRelaychain(for: stakingOption),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let chainAsset = stakingOption.chainAsset

        let interactor = createRelaychainInteractor(
            state: state,
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
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
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
        state: RelaychainStakingSharedStateProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) -> StartStakingRelaychainInteractor {
        let selectedWalletSettings = SelectedWalletSettings.shared
        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory.shared

        return StartStakingRelaychainInteractor(
            selectedWalletSettings: selectedWalletSettings,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            currencyManager: currencyManager,
            state: state,
            operationQueue: operationQueue
        )
    }

    private static func createParachainView(
        for stakingOption: Multistaking.ChainAssetOption
    ) -> StartStakingInfoViewProtocol? {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let stateFactory = StakingSharedStateFactory(
            storageFacade: SubstrateDataStorageFacade.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            eventCenter: EventCenter.shared,
            syncOperationQueue: operationQueue,
            repositoryOperationQueue: operationQueue,
            logger: Logger.shared
        )

        guard
            let state = try? stateFactory.createParachain(for: stakingOption),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = createParachainInteractor(state: state, currencyManager: currencyManager)

        let wireframe = StartStakingInfoWireframe()
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: stakingOption.chainAsset.assetDisplayInfo,
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
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
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
        state: ParachainStakingSharedStateProtocol,
        currencyManager: CurrencyManagerProtocol
    ) -> StartStakingParachainInteractor {
        let selectedWalletSettings = SelectedWalletSettings.shared
        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory.shared
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let stakingDurationFactory = ParaStkDurationOperationFactory(
            storageRequestFactory: storageRequestFactory,
            blockTimeOperationFactory: BlockTimeOperationFactory(chain: state.stakingOption.chainAsset.chain)
        )

        return StartStakingParachainInteractor(
            state: state,
            selectedWalletSettings: selectedWalletSettings,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            currencyManager: currencyManager,
            networkInfoFactory: ParaStkNetworkInfoOperationFactory(),
            durationOperationFactory: stakingDurationFactory,
            operationQueue: operationQueue,
            eventCenter: EventCenter.shared
        )
    }
}
