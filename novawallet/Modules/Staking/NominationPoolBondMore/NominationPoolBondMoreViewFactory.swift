import Foundation

struct NominationPoolBondMoreViewFactory {
    static func createView(state: NPoolsStakingSharedStateProtocol) -> NominationPoolBondMoreViewProtocol? {
        guard let interactor = createInteractor(state: state) else {
            return nil
        }
        let wireframe = NominationPoolBondMoreWireframe()

        let presenter = NominationPoolBondMorePresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: state.chainAsset,
            logger: Logger.shared
        )

        let view = NominationPoolBondMoreViewController(presenter: presenter)

        presenter.view = view
        interactor.basePresenter = presenter

        return view
    }

    static func createInteractor(state: NPoolsStakingSharedStateProtocol) -> NominationPoolBondMoreInteractor? {
        let chainAsset = state.chainAsset

        guard
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared,
            let selectedAccount = selectedMetaAccount.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ) else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeRegistry = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }
        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeRegistry,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager
        )
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        return .init(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            runtimeService: runtimeRegistry,
            feeProxy: ExtrinsicFeeProxy(),
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            callFactory: SubstrateCallFactory(),
            extrinsicServiceFactory: extrinsicServiceFactory,
            npoolsOperationFactory: NominationPoolsOperationFactory(operationQueue: operationQueue),
            npoolsLocalSubscriptionFactory: state.npLocalSubscriptionFactory,
            stakingLocalSubscriptionFactory: state.relaychainLocalSubscriptionFactory,
            operationQueue: operationQueue,
            currencyManager: currencyManager
        )
    }
}