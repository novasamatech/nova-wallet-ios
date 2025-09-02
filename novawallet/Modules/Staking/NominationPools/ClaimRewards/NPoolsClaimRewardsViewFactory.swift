import Foundation
import Operation_iOS
import Foundation_iOS

struct NPoolsClaimRewardsViewFactory {
    static func createView(for state: NPoolsStakingSharedStateProtocol) -> StakingClaimRewardsViewProtocol? {
        guard
            let interactor = createInteractor(for: state),
            let wallet = SelectedWalletSettings.shared.value,
            let selectedAccount = wallet.fetchMetaChainAccount(for: state.chainAsset.chain.accountRequest()),
            let currencyManager = CurrencyManager.shared,
            let stakingActivity = StakingActivityForValidation(
                wallet: SelectedWalletSettings.shared.value,
                chain: state.chainAsset.chain,
                chainRegistry: ChainRegistryFacade.sharedRegistry,
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            ) else {
            return nil
        }

        let wireframe = NPoolsClaimRewardsWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: state.chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let dataValidatingFactory = NominationPoolDataValidatorFactory(
            presentable: wireframe,
            balanceFactory: balanceViewModelFactory
        )

        let presenter = NPoolsClaimRewardsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedAccount: selectedAccount,
            chainAsset: state.chainAsset,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatorFactory: dataValidatingFactory,
            stakingActivity: stakingActivity,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = StakingClaimRewardsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

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
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount.chainAccount, chain: chainAsset.chain)

        let signingWrapper = SigningWrapperFactory.createSigner(from: selectedAccount)

        return NPoolsClaimRewardsInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            runtimeService: runtimeService,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            signingWrapper: signingWrapper,
            npoolsLocalSubscriptionFactory: state.npLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            operationQueue: operationQueue,
            currencyManager: currencyManager
        )
    }
}
