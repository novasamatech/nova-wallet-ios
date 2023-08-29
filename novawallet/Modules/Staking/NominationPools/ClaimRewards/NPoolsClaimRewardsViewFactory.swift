import Foundation
import RobinHood

struct NPoolsClaimRewardsViewFactory {
    static func createView(for state: NPoolsStakingSharedStateProtocol) -> NPoolsClaimRewardsViewProtocol? {
        guard let interactor = createInteractor(for: state) else {
            return nil
        }

        let wireframe = NPoolsClaimRewardsWireframe()

        let presenter = NPoolsClaimRewardsPresenter(interactor: interactor, wireframe: wireframe)

        let view = NPoolsClaimRewardsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for state: NPoolsStakingSharedStateProtocol
    ) -> NPoolsClaimRewardsInteractor? {
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

        return NPoolsClaimRewardsInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            signingWrapper: signingWrapper,
            npoolsLocalSubscriptionFactory: state.npLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            currencyManager: currencyManager
        )
    }
}
