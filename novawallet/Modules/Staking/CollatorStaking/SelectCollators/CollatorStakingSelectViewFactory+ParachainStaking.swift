import Foundation
import Foundation_iOS
import Operation_iOS
import SubstrateSdk

extension CollatorStakingSelectViewFactory {
    static func createParachainStakingView(
        with state: ParachainStakingSharedStateProtocol,
        delegate: CollatorStakingSelectDelegate
    ) -> CollatorStakingSelectViewProtocol? {
        guard
            let stakableCollatorOperationFactory = createParachainCollatorFactory(for: state),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = CollatorStakingSelectInteractor(
            chainAsset: state.stakingOption.chainAsset,
            stakableCollatorOperationFactory: stakableCollatorOperationFactory,
            preferredCollatorsProvider: state.preferredCollatorsProvider,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = ParaStkSelectCollatorsWireframe(sharedState: state)

        return createView(
            for: state.stakingOption.chainAsset,
            delegate: delegate,
            interactor: interactor,
            wireframe: wireframe,
            currencyManager: currencyManager
        )
    }

    private static func createParachainCollatorFactory(
        for state: ParachainStakingSharedStateProtocol
    ) -> CollatorStakingStakableFactoryProtocol? {
        let collatorService = state.collatorService
        let rewardEngineService = state.rewardCalculationService

        let chain = state.stakingOption.chainAsset.chain

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)
        let identityProxyFactory = IdentityProxyFactory(
            originChain: chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        )

        let collatorOperationFactory = ParaStkCollatorsOperationFactory(
            requestFactory: requestFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            identityFactory: identityProxyFactory,
            chainFormat: chain.chainFormat
        )

        return ParaStkStakableCollatorsOperationFactory(
            collatorsOperationFactory: collatorOperationFactory,
            collatorService: collatorService,
            rewardsService: rewardEngineService
        )
    }
}
