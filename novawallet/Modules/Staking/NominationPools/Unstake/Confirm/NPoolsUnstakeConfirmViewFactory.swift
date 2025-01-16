import Foundation
import Foundation_iOS
import Operation_iOS

struct NPoolsUnstakeConfirmViewFactory {
    static func createView(
        for amount: Decimal,
        state: NPoolsStakingSharedStateProtocol
    ) -> NPoolsUnstakeConfirmViewProtocol? {
        guard
            let interactor = createInteractor(for: state),
            let currencyManager = CurrencyManager.shared,
            let wallet = SelectedWalletSettings.shared.value,
            let selectedAccount = wallet.fetchMetaChainAccount(for: state.chainAsset.chain.accountRequest()),
            let stakingActivity = StakingActivityForValidation(
                wallet: SelectedWalletSettings.shared.value,
                chain: state.chainAsset.chain,
                chainRegistry: ChainRegistryFacade.sharedRegistry,
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            ) else {
            return nil
        }

        let wireframe = NPoolsUnstakeConfirmWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: state.chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let hintsViewModelFactory = NPoolsUnstakeHintsFactory(
            chainAsset: state.chainAsset,
            balanceViewModelFactory: balanceViewModelFactory
        )

        let dataValidatingFactory = NominationPoolDataValidatorFactory(
            presentable: wireframe,
            balanceFactory: balanceViewModelFactory
        )

        let presenter = NPoolsUnstakeConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            unstakingAmount: amount,
            selectedAccount: selectedAccount,
            chainAsset: state.chainAsset,
            hintsViewModelFactory: hintsViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatorFactory: dataValidatingFactory,
            stakingActivity: stakingActivity,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = NPoolsUnstakeConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.baseView = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    static func createInteractor(for state: NPoolsStakingSharedStateProtocol) -> NPoolsUnstakeConfirmInteractor? {
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

        let eraCountdownOperationFactory = state.createEraCountdownOperationFactory(for: operationQueue)
        let durationOperationFactory = state.createStakingDurationOperationFactory()

        let npoolsOperationFactory = NominationPoolsOperationFactory(operationQueue: operationQueue)

        let signingWrapper = SigningWrapperFactory.createSigner(from: selectedAccount)

        return NPoolsUnstakeConfirmInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            signingWrapper: signingWrapper,
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
            unstakeLimitsFactory: NPoolsUnstakeOperationFactory(),
            eventCenter: EventCenter.shared,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }
}
