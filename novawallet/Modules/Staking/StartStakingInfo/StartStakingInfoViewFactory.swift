import Foundation
import SubstrateSdk
import SoraFoundation
import RobinHood

struct StartStakingInfoViewFactory {
    static func createView(chainAsset: ChainAsset) -> StartStakingInfoViewProtocol? {
        let optStakingType = chainAsset.asset.stakings?.sorted { type1, type2 in
            type1.isMorePreferred(than: type2)
        }.first

        guard let stakingType = optStakingType else {
            return nil
        }

        switch stakingType {
        case .relaychain:
            return createRelaychainView(chainAsset: chainAsset, consensus: .babe)
        case .auraRelaychain:
            return createRelaychainView(chainAsset: chainAsset, consensus: .auraGeneral)
        case .azero:
            return createRelaychainView(chainAsset: chainAsset, consensus: .auraAzero)
        case .parachain, .turing:
            return createParachainView(for: .init(chainAsset: chainAsset, type: stakingType))
        case .unsupported, .nominationPools:
            return nil
        }
    }

    private static func createRelaychainView(
        chainAsset: ChainAsset,
        consensus: ConsensusType
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
            let state = try? stateFactory.createStartRelaychainStaking(for: chainAsset, consensus: consensus),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = createRelaychainInteractor(
            state: state,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )

        let wireframe = StartStakingInfoRelaychainWireframe(state: state)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )
        let startStakingViewModelFactory = StartStakingViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            estimatedEarningsFormatter: NumberFormatter.percentBase.localizableResource()
        )

        let presenter = StartStakingInfoRelaychainPresenter(
            chainAsset: chainAsset,
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
        state: RelaychainStartStakingStateProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) -> StartStakingRelaychainInteractor {
        let selectedWalletSettings = SelectedWalletSettings.shared
        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory.shared

        let networkOperationFactory = state.createNetworkInfoOperationFactory(for: operationQueue)
        let eraCountdownFactory = state.createEraCountdownOperationFactory(for: operationQueue)

        return StartStakingRelaychainInteractor(
            state: state,
            selectedWalletSettings: selectedWalletSettings,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            currencyManager: currencyManager,
            networkInfoOperationFactory: networkOperationFactory,
            eraCoundownOperationFactory: eraCountdownFactory,
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
            chainAsset: stakingOption.chainAsset,
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
