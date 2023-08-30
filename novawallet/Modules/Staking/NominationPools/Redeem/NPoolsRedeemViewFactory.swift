import Foundation
import SubstrateSdk
import RobinHood

struct NPoolsRedeemViewFactory {
    static func createView(for state: NPoolsStakingSharedStateProtocol) -> NPoolsRedeemViewProtocol? {
        guard let interactor = createInteractor(for: state) else {
            return nil
        }

        let wireframe = NPoolsRedeemWireframe()

        let presenter = NPoolsRedeemPresenter(interactor: interactor, wireframe: wireframe)

        let view = NPoolsRedeemViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for state: NPoolsStakingSharedStateProtocol
    ) -> NPoolsRedeemInteractor? {
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

        let signingWrapper = SigningWrapperFactory.createSigner(from: selectedAccount)

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let slashesOperationFactory = SlashesOperationFactory(storageRequestFactory: storageRequestFactory)
        let npoolsOperationFactory = NominationPoolsOperationFactory(operationQueue: operationQueue)

        return NPoolsRedeemInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            signingWrapper: signingWrapper,
            slashesOperationFactory: slashesOperationFactory,
            npoolsLocalSubscriptionFactory: state.npLocalSubscriptionFactory,
            stakingLocalSubscriptionFactory: state.relaychainLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            npoolsOperationFactory: npoolsOperationFactory,
            connection: connection,
            runtimeService: runtimeService,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }
}
