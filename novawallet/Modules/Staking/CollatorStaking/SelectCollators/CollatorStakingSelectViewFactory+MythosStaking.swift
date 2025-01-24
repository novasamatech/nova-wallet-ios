import Foundation
import Operation_iOS
import SubstrateSdk

extension CollatorStakingSelectViewFactory {
    static func createMythosStakingView(
        with state: MythosStakingSharedStateProtocol,
        delegate: CollatorStakingSelectDelegate
    ) -> CollatorStakingSelectViewProtocol? {
        guard
            let stakableCollatorOperationFactory = createMythosCollatorFactory(for: state),
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

        let wireframe = MythosStkSelectCollatorsWireframe(state: state)

        return createView(
            for: state.stakingOption.chainAsset,
            delegate: delegate,
            interactor: interactor,
            wireframe: wireframe,
            currencyManager: currencyManager
        )
    }

    private static func createMythosCollatorFactory(
        for state: MythosStakingSharedStateProtocol
    ) -> CollatorStakingStakableFactoryProtocol? {
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

        return MythosStakableCollatorOperationFactory(
            collatorService: state.collatorService,
            rewardsService: state.rewardCalculatorService,
            runtimeProvider: runtimeProvider,
            connection: connection,
            identityFactory: identityProxyFactory,
            operationQueue: operationQueue
        )
    }
}
