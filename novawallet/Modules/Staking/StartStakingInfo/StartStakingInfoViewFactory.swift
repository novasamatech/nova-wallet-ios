import Foundation
import SoraFoundation
import RobinHood

struct StartStakingInfoViewFactory {
    static func createView(
        stakingOption: Multistaking.ChainAssetOption,
        dashboardItem: Multistaking.DashboardItem
    ) -> StartStakingInfoViewProtocol? {
        switch stakingOption.type {
        case .relaychain, .auraRelaychain, .azero, .nominationPools:
            let factory = RelaychainStakingStateFactory(
                stakingOption: stakingOption,
                chainRegistry: ChainRegistryFacade.sharedRegistry,
                storageFacade: SubstrateDataStorageFacade.shared,
                eventCenter: EventCenter.shared,
                logger: Logger.shared,
                operationQueue: OperationQueue()
            )
            return createRelaychainView(
                chainAsset: stakingOption.chainAsset,
                factory: factory,
                dashboardItem: dashboardItem
            )
        case .parachain, .turing:
            // TODO:
            return nil
        case .unsupported:
            return nil
        }
    }

    private static func createRelaychainView(
        chainAsset: ChainAsset,
        factory: RelaychainStakingStateFactoryProtocol,
        dashboardItem: Multistaking.DashboardItem
    ) -> StartStakingInfoViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = createRelaychainInteractor(
            factory: factory,
            chainAsset: chainAsset,
            currencyManager: currencyManager
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
            dashboardItem: dashboardItem,
            wireframe: wireframe,
            startStakingViewModelFactory: startStakingViewModelFactory,
            localizationManager: LocalizationManager.shared
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
        currencyManager: CurrencyManagerProtocol
    ) -> StartStakingRelaychainInteractor {
        let selectedWalletSettings = SelectedWalletSettings.shared
        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory.shared
        let operationQueue = OperationQueue()
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let storageFacade = SubstrateDataStorageFacade.shared
        let operationManager = OperationManager(operationQueue: operationQueue)
        let logger = Logger.shared

        return StartStakingRelaychainInteractor(
            chainAsset: chainAsset,
            selectedWalletSettings: selectedWalletSettings,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            currencyManager: currencyManager,
            stateFactory: factory,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
    }
}
