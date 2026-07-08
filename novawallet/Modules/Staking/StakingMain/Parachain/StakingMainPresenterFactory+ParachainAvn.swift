import Foundation
import Operation_iOS
import Foundation_iOS
import SubstrateSdk

extension StakingMainPresenterFactory {
    func createParachainAvnPresenter(
        for stakingOption: Multistaking.ChainAssetOption,
        view: StakingMainViewProtocol
    ) -> StakingParachainPresenter? {
        guard let sharedState = try? sharedStateFactory.createParachainAvn(for: stakingOption) else {
            return nil
        }

        guard let interactor = createParachainAvnInteractor(state: sharedState),
              let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = StakingParachainWireframe(state: sharedState)

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let networkInfoViewModelFactory = CollatorStkNetworkInfoViewModelFactory(
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        let stateViewModelFactory = ParaStkStateViewModelFactory(priceAssetInfoFactory: priceAssetInfoFactory)

        let presenter = StakingParachainPresenter(
            interactor: interactor,
            wireframe: wireframe,
            networkInfoViewModelFactory: networkInfoViewModelFactory,
            stateViewModelFactory: stateViewModelFactory,
            priceAssetInfoFactory: priceAssetInfoFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return presenter
    }

    private func createParachainAvnInteractor(
        state: ParachainStakingSharedStateProtocol
    ) -> StakingParachainInteractor? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let currencyManager = CurrencyManager.shared,
            let connection = state.chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)

        let networkInfoFactory = ParachainAvnNetworkInfoOperationFactory()

        let blockTimeFactory = BlockTimeOperationFactory(chain: chainAsset.chain)

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let durationFactory = ParachainAvnDurationOperationFactory(
            storageRequestFactory: storageRequestFactory,
            blockTimeOperationFactory: blockTimeFactory
        )

        // EWX has no `pallet-identity` — without this flag the operation
        // factory throws when storage isn't found. No-op on chains where
        // the pallet exists.
        let identityOperationFactory = IdentityOperationFactory(
            requestFactory: storageRequestFactory,
            emptyIdentitiesWhenNoStorage: true
        )
        let identityProxyFactory = IdentityProxyFactory(
            originChain: chainAsset.chain,
            chainRegistry: state.chainRegistry,
            identityOperationFactory: identityOperationFactory
        )

        let collatorsOperationFactory = ParaStkCollatorsOperationFactory(
            requestFactory: storageRequestFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            identityFactory: identityProxyFactory,
            chainFormat: chainAsset.chain.chainFormat
        )

        let queryWrapperFactory = ParaStkScheduledRequestsQueryWrapperFactory(
            storageRequestFactory: storageRequestFactory,
            operationManager: operationManager
        )
        let scheduledRequestsFactory = ParachainStaking.ScheduledRequestsQueryFactory(
            queryWrapperFactory: queryWrapperFactory
        )

        return StakingParachainInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            sharedState: state,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            networkInfoFactory: networkInfoFactory,
            durationOperationFactory: durationFactory,
            scheduledRequestsFactory: scheduledRequestsFactory,
            collatorsOperationFactory: collatorsOperationFactory,
            yieldBoostSupport: ParaStkYieldBoostSupport(),
            yieldBoostProviderFactory: ParaStkYieldBoostProviderFactory.shared,
            eventCenter: EventCenter.shared,
            applicationHandler: applicationHandler,
            currencyManager: currencyManager,
            operationQueue: operationQueue,
            logger: Logger.shared
        )
    }
}
