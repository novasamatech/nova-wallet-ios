import Foundation
import Foundation_iOS
import SubstrateSdk

struct ParaStkStakeSetupViewFactory {
    static func createView(
        with state: ParachainStakingSharedStateProtocol,
        initialDelegator: ParachainStaking.Delegator?,
        initialScheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        delegationIdentities: [AccountId: AccountIdentity]?
    ) -> CollatorStakingSetupViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(from: state, initialDelegator: initialDelegator) else {
            return nil
        }

        let wireframe = ParaStkStakeSetupWireframe(state: state)

        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let dataValidationFactory = ParachainStaking.ValidatorFactory(
            presentable: wireframe,
            assetDisplayInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let accountDetailsFactory = CollatorStakingAccountViewModelFactory(chainAsset: chainAsset)

        let localizationManager = LocalizationManager.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = ParaStkStakeSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            dataValidatingFactory: dataValidationFactory,
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceViewModelFactory,
            accountDetailsViewModelFactory: accountDetailsFactory,
            initialDelegator: initialDelegator,
            initialScheduledRequests: initialScheduledRequests,
            delegationIdentities: delegationIdentities,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let localizableTitle = CollatorStakingStakeScreenTitle.setup(
            hasStake: initialDelegator != nil,
            assetSymbol: chainAsset.asset.symbol
        )

        let view = CollatorStakingSetupViewController(
            presenter: presenter,
            localizableTitle: localizableTitle(),
            localizationManager: localizationManager
        )

        presenter.view = view
        dataValidationFactory.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        from state: ParachainStakingSharedStateProtocol,
        initialDelegator: ParachainStaking.Delegator?
    ) -> ParaStkStakeSetupInteractor? {
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

        let collatorService = state.collatorService
        let rewardService = state.rewardCalculationService

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
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)
        let identityProxyFactory = IdentityProxyFactory(
            originChain: chainAsset.chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        )

        let preferredCollatorFactory: PreferredStakingCollatorFactory? = if initialDelegator == nil {
            // add pref collators only for first staking

            PreferredStakingCollatorFactory(
                chain: chainAsset.chain,
                connection: connection,
                runtimeService: runtimeProvider,
                collatorService: collatorService,
                rewardService: rewardService,
                identityProxyFactory: identityProxyFactory,
                preferredCollatorProvider: state.preferredCollatorsProvider,
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            )
        } else {
            nil
        }

        return ParaStkStakeSetupInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            preferredCollatorFactory: preferredCollatorFactory,
            rewardService: rewardService,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            connection: connection,
            runtimeProvider: runtimeProvider,
            repositoryFactory: repositoryFactory,
            identityProxyFactory: identityProxyFactory,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
