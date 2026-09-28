import Foundation
import Operation_iOS
import SubstrateSdk

extension CollatorStakingSelectViewFactory {
    static func createSubtensorStakingView(
        with state: SubtensorStakingSharedStateProtocol,
        delegate: CollatorStakingSelectDelegate
    ) -> CollatorStakingSelectViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let chain = state.stakingOption.chainAsset.chain

        let networkInfoFactory = SubtensorNetworkInfoFactory(
            runtimeConnectionStore: ChainRegistryRuntimeConnectionStore(
                chainId: chain.chainId,
                chainRegistry: state.chainRegistry
            ),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let stakableDelegateOperationFactory = SubtensorStakableDelegateOperationFactory(
            delegatesService: state.delegatesService,
            networkInfoFactory: networkInfoFactory
        )

        let preferredDelegatesProvider = PreferredValidatorsProvider(
            remoteUrl: ApplicationConfig.shared.preferredValidatorsURL
        )

        let interactor = CollatorStakingSelectInteractor(
            chainAsset: state.stakingOption.chainAsset,
            stakableCollatorOperationFactory: stakableDelegateOperationFactory,
            preferredCollatorsProvider: preferredDelegatesProvider,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = SubtensorSelectDelegatesWireframe(state: state)

        return createView(
            for: state.stakingOption.chainAsset,
            delegate: delegate,
            interactor: interactor,
            wireframe: wireframe,
            currencyManager: currencyManager,
            defaultSorting: .totalStake,
            displaysRewards: false,
            showsValidatorsCount: true,
            statics: .subtensorValidator
        )
    }
}
