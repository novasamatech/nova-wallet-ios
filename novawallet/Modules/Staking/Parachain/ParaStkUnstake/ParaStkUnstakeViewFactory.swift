import Foundation
import Foundation_iOS
import SubstrateSdk

struct ParaStkUnstakeViewFactory {
    static func createView(
        with state: ParachainStakingSharedStateProtocol,
        initialDelegator: ParachainStaking.Delegator?,
        initialScheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        delegationIdentities: [AccountId: AccountIdentity]?
    ) -> CollatorStkPartialUnstakeSetupViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let interactor = createInteractor(from: state),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = ParaStkUnstakeWireframe(state: state)

        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let dataValidationFactory = ParachainStaking.ValidatorFactory(
            presentable: wireframe,
            assetDisplayInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let accountDetailsFactory = CollatorStakingAccountViewModelFactory(chainAsset: chainAsset)

        let localizationManager = LocalizationManager.shared

        let presenter = ParaStkUnstakePresenter(
            interactor: interactor,
            wireframe: wireframe,
            dataValidatingFactory: dataValidationFactory,
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceViewModelFactory,
            accountDetailsViewModelFactory: accountDetailsFactory,
            hintViewModelFactory: CollatorStakingHintsViewModelFactory(),
            initialDelegator: initialDelegator,
            initialScheduledRequests: initialScheduledRequests,
            delegationIdentities: delegationIdentities,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = CollatorStkPartialUnstakeSetupVC(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.basePresenter = presenter
        dataValidationFactory.view = view

        return view
    }

    private static func createInteractor(
        from state: ParachainStakingSharedStateProtocol
    ) -> ParaStkUnstakeInteractor? {
        let optMetaAccount = SelectedWalletSettings.shared.value
        let chainRegistry = state.chainRegistry

        let chainAsset = state.stakingOption.chainAsset

        guard
            let selectedAccount = optMetaAccount?.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let currencyManager = CurrencyManager.shared
        else {
            return nil
        }

        let blocktimeService = state.blockTimeService

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount.chainAccount, chain: chainAsset.chain)

        let operationManager = OperationManagerFacade.sharedManager

        let storageFacade = SubstrateDataStorageFacade.shared
        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: storageFacade)
        let keyFactory = StorageKeyFactory()
        let requestFactory = StorageRequestFactory(remoteFactory: keyFactory, operationManager: operationManager)

        let identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)
        let identityProxyFactory = IdentityProxyFactory(
            originChain: chainAsset.chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        )

        let stakingDurationFactory = ParaStkDurationOperationFactory(
            storageRequestFactory: requestFactory,
            blockTimeOperationFactory: BlockTimeOperationFactory(chain: chainAsset.chain)
        )

        return ParaStkUnstakeInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            identityProxyFactory: identityProxyFactory,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            connection: connection,
            runtimeProvider: runtimeProvider,
            stakingDurationFactory: stakingDurationFactory,
            blocktimeEstimationService: blocktimeService,
            repositoryFactory: repositoryFactory,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
