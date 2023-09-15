import Foundation
import RobinHood
import SoraFoundation
import SubstrateSdk

extension StakingMainPresenterFactory {
    func createParachainPresenter(
        for stakingOption: Multistaking.ChainAssetOption,
        view: StakingMainViewProtocol
    ) -> StakingParachainPresenter? {
        guard let sharedState = try? sharedStateFactory.createParachain(for: stakingOption) else {
            return nil
        }

        // MARK: - Interactor

        guard let interactor = createParachainInteractor(state: sharedState),
              let currencyManager = CurrencyManager.shared else {
            return nil
        }

        // MARK: - Router

        let wireframe = StakingParachainWireframe(state: sharedState)

        // MARK: - Presenter

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let networkInfoViewModelFactory = ParachainStaking.NetworkInfoViewModelFactory(
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        let stateViewModelFactory = ParaStkStateViewModelFactory(priceAssetInfoFactory: priceAssetInfoFactory)

        let presenter = StakingParachainPresenter(
            interactor: interactor,
            wireframe: wireframe,
            networkInfoViewModelFactory: networkInfoViewModelFactory,
            stateViewModelFactory: stateViewModelFactory,
            priceAssetInfoFactory: priceAssetInfoFactory,
            logger: Logger.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return presenter
    }

    func createParachainInteractor(state: ParachainStakingSharedStateProtocol) -> StakingParachainInteractor? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)

        let eventCenter = EventCenter.shared
        let logger = Logger.shared

        let networkInfoFactory = ParaStkNetworkInfoOperationFactory()

        let chainAsset = state.stakingOption.chainAsset

        let blockTimeFactory = BlockTimeOperationFactory(chain: chainAsset.chain)

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let durationFactory = ParaStkDurationOperationFactory(
            storageRequestFactory: storageRequestFactory,
            blockTimeOperationFactory: blockTimeFactory
        )

        let collatorsOperationFactory = ParaStkCollatorsOperationFactory(
            requestFactory: storageRequestFactory,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory)
        )

        let applicationHandler = ApplicationHandler()

        return StakingParachainInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            sharedState: state,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            networkInfoFactory: networkInfoFactory,
            durationOperationFactory: durationFactory,
            scheduledRequestsFactory: ParachainStaking.ScheduledRequestsQueryFactory(operationQueue: operationQueue),
            collatorsOperationFactory: collatorsOperationFactory,
            yieldBoostSupport: ParaStkYieldBoostSupport(),
            yieldBoostProviderFactory: ParaStkYieldBoostProviderFactory.shared,
            eventCenter: eventCenter,
            applicationHandler: applicationHandler,
            currencyManager: currencyManager,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}
