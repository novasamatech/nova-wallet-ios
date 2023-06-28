import Foundation
import SoraFoundation
import RobinHood

struct StartStakingInfoViewFactory {
    static func createView(stakingOption: Multistaking.ChainAssetOption) -> StartStakingInfoViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        guard let interactor = createInteractor(
            stakingOption: stakingOption,
            currencyManager: currencyManager
        ) else {
            return nil
        }

        let wireframe = StartStakingInfoWireframe()
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: stakingOption.chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )
        let startStakingViewModelFactory = StartStakingViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory)

        let presenter = StartStakingInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            startStakingViewModelFactory: startStakingViewModelFactory
        )

        let view = StartStakingInfoViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        stakingOption: Multistaking.ChainAssetOption,
        currencyManager: CurrencyManagerProtocol
    ) -> StartStakingInfoInteractor? {
        let selectedWalletSettings = SelectedWalletSettings.shared
        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory.shared
        let operationQueue = OperationQueue()
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let storageFacade = SubstrateDataStorageFacade.shared
        let operationManager = OperationManager(operationQueue: operationQueue)
        let logger = Logger.shared

        switch stakingOption.type {
        case .relaychain, .auraRelaychain, .azero, .nominationPools:
            let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactory(
                chainRegistry: chainRegistry,
                storageFacade: storageFacade,
                operationManager: operationManager,
                logger: logger
            )
            return StartStakingRelaychainInteractor(
                chainAsset: stakingOption.chainAsset,
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                selectedWalletSettings: selectedWalletSettings,
                walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
                priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
                currencyManager: currencyManager,
                stateFactory: RelaychainStakingStateFactory(
                    stakingOption: stakingOption,
                    stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                    operationQueue: operationQueue
                ),
                chainRegistry: chainRegistry,
                operationQueue: operationQueue
            )
        case .parachain, .turing:
            let stakingLocalSubscriptionFactory = ParachainStakingLocalSubscriptionFactory(
                chainRegistry: chainRegistry,
                storageFacade: storageFacade,
                operationManager: operationManager,
                logger: logger
            )

            return StartStakingParachainInteractor(
                chainAsset: stakingOption.chainAsset,
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                selectedWalletSettings: selectedWalletSettings,
                walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
                priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
                currencyManager: currencyManager,
                stateFactory: ParachainStakingStateFactory(
                    stakingOption: stakingOption,
                    stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                    operationQueue: operationQueue
                ),
                chainRegistry: chainRegistry,
                networkInfoFactory: ParaStkNetworkInfoOperationFactory(),
                operationQueue: operationQueue,
                eventCenter: EventCenter.shared
            )
        case .unsupported:
            return nil
        }
    }
}
