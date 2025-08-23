import Foundation
import SubstrateSdk
import Foundation_iOS
import Operation_iOS

struct StartStakingInfoViewFactory {
    static func createView(chainAsset: ChainAsset, selectedStakingType: StakingType?) -> StartStakingInfoViewProtocol? {
        let optMainStakingType = chainAsset.asset.stakings?.sorted { type1, type2 in
            type1.isMorePreferred(than: type2)
        }.first

        guard let mainStakingType = optMainStakingType else {
            return nil
        }

        switch mainStakingType {
        case .relaychain:
            return createRelaychainView(
                chainAsset: chainAsset,
                consensus: .babe,
                selectedStakingType: selectedStakingType
            )
        case .auraRelaychain:
            return createRelaychainView(
                chainAsset: chainAsset,
                consensus: .auraGeneral,
                selectedStakingType: selectedStakingType
            )
        case .azero:
            return createRelaychainView(
                chainAsset: chainAsset,
                consensus: .auraAzero,
                selectedStakingType: selectedStakingType
            )
        case .parachain, .turing:
            return createParachainView(
                for: .init(
                    chainAsset: chainAsset,
                    type: selectedStakingType ?? mainStakingType
                )
            )
        case .mythos:
            return createMythosView(
                for: .init(
                    chainAsset: chainAsset,
                    type: selectedStakingType ?? mainStakingType
                )
            )
        case .unsupported, .nominationPools:
            return nil
        }
    }

    private static func createRelaychainView(
        chainAsset: ChainAsset,
        consensus: ConsensusType,
        selectedStakingType: StakingType?
    ) -> StartStakingInfoViewProtocol? {
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
            let state = try? stateFactory.createStartRelaychainStaking(
                for: chainAsset,
                consensus: consensus,
                selectedStakingType: selectedStakingType
            ),
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
            selectedStakingType: state.stakingType,
            chainAsset: chainAsset,
            interactor: interactor,
            wireframe: wireframe,
            startStakingViewModelFactory: startStakingViewModelFactory,
            balanceDerivationFactory: StakingTypeBalanceFactory(stakingType: state.stakingType),
            localizationManager: LocalizationManager.shared,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        let view = StartStakingInfoViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared,
            themeColor: chainAsset.chain.themeColor ?? R.color.colorPolkadotBrand()!
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

        let stakingDashboardProviderFactory = StakingDashboardProviderFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        return StartStakingRelaychainInteractor(
            state: state,
            selectedWalletSettings: selectedWalletSettings,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingDashboardProviderFactory: stakingDashboardProviderFactory,
            currencyManager: currencyManager,
            networkInfoOperationFactory: networkOperationFactory,
            eraCoundownOperationFactory: eraCountdownFactory,
            sharedOperation: state.startSharedOperation(),
            eventCenter: EventCenter.shared,
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
            delegatedAccountSyncService: nil,
            eventCenter: EventCenter.shared,
            syncOperationQueue: operationQueue,
            repositoryOperationQueue: operationQueue,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        guard
            let state = try? stateFactory.createParachain(for: stakingOption),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = createParachainInteractor(state: state, currencyManager: currencyManager)

        let wireframe = StartStakingInfoParachainWireframe(state: state)
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
            balanceDerivationFactory: StakingTypeBalanceFactory(stakingType: stakingOption.type),
            localizationManager: LocalizationManager.shared,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        let view = StartStakingInfoViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared,
            themeColor: stakingOption.chainAsset.chain.themeColor ?? R.color.colorPolkadotBrand()!
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

        let stakingDashboardProviderFactory = StakingDashboardProviderFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        return StartStakingParachainInteractor(
            state: state,
            selectedWalletSettings: selectedWalletSettings,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingDashboardProviderFactory: stakingDashboardProviderFactory,
            currencyManager: currencyManager,
            networkInfoFactory: ParaStkNetworkInfoOperationFactory(),
            durationOperationFactory: stakingDurationFactory,
            sharedOperation: state.startSharedOperation(),
            operationQueue: operationQueue,
            eventCenter: EventCenter.shared
        )
    }
}
