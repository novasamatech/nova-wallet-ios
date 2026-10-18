import Foundation
import Foundation_iOS
import Operation_iOS

extension StartStakingInfoViewFactory {
    static func createSubtensorView(
        for stakingOption: Multistaking.ChainAssetOption,
        flowState: SubtensorFlowStateProtocol
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
            let state = try? stateFactory.createSubtensorStaking(for: stakingOption, flowState: flowState),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = createSubtensorInteractor(state: state, currencyManager: currencyManager)
        let wireframe = StartStakingInfoSubtensorWireframe(state: state)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: stakingOption.chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let startStakingViewModelFactory = StartStakingViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            estimatedEarningsFormatter: NumberFormatter.subtensorPercent
        )

        let presenter = StartStakingInfoSubtensorPresenter(
            chainAsset: stakingOption.chainAsset,
            interactor: interactor,
            wireframe: wireframe,
            startStakingViewModelFactory: startStakingViewModelFactory,
            subtensorViewModelFactory: StartStakingInfoSubtensorViewModelFactory(),
            balanceDerivationFactory: StakingTypeBalanceFactory(stakingType: stakingOption.type),
            localizationManager: LocalizationManager.shared,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        let view = StartStakingInfoSubtensorViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        wireframe.subnetSelectDelegate = presenter

        return view
    }

    private static func createSubtensorInteractor(
        state: SubtensorSharedStateProtocol,
        currencyManager: CurrencyManagerProtocol
    ) -> StartStakingInfoSubtensorInteractor {
        let stakingDashboardProviderFactory = StakingDashboardProviderFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let maxApyOperationFactory = SubtensorProcessServices.shared.createMaxApyOperationFactory(
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        return StartStakingInfoSubtensorInteractor(
            state: state,
            maxApyOperationFactory: maxApyOperationFactory,
            selectedWalletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            stakingDashboardProviderFactory: stakingDashboardProviderFactory,
            announcementsRepository: AnnouncementsRepository.shared,
            currencyManager: currencyManager,
            sharedOperation: state.startSharedOperation(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }
}
