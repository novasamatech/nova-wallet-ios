import Foundation
import RobinHood

struct NPoolsUnstakeSetupViewFactory {
    static func createView(for state: NPoolsStakingSharedStateProtocol) -> NPoolsUnstakeSetupViewProtocol? {
        guard let interactor = createInteractor(for: state) else {
            return nil
        }

        let wireframe = NPoolsUnstakeSetupWireframe()

        let presenter = NPoolsUnstakeSetupPresenter(interactor: interactor, wireframe: wireframe)

        let view = NPoolsUnstakeSetupViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for state: NPoolsStakingSharedStateProtocol
    ) -> NPoolsUnstakeSetupInteractor? {
        let chainAsset = state.chainAsset
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let selectedAccount = SelectedWalletSettings.shared.value?.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue)
        ).createService(account: selectedAccount.chainAccount, chain: chainAsset.chain)

        let eraCountdownOperationFactory = state.createEraCountdownOperationFactory(for: operationQueue)
        let durationOperationFactory = state.createStakingDurationOperationFactory()

        let npoolsOperationFactory = NominationPoolsOperationFactory(operationQueue: operationQueue)

        return NPoolsUnstakeSetupInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            npoolsLocalSubscriptionFactory: state.npLocalSubscriptionFactory,
            stakingLocalSubscriptionFactory: state.relaychainLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            connection: connection,
            runtimeService: runtimeService,
            eraCountdownOperationFactory: eraCountdownOperationFactory,
            durationFactory: durationOperationFactory,
            npoolsOperationFactory: npoolsOperationFactory,
            eventCenter: EventCenter.shared,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }
}
