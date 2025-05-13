import Foundation
import Foundation_iOS
import SubstrateSdk
import Operation_iOS

struct MythosStakingSetupViewFactory {
    static func createView(
        for state: MythosStakingSharedStateProtocol,
        initialStakingDetails: MythosStakingDetails?
    ) -> CollatorStakingSetupViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: state,
                initialStakingDetails: initialStakingDetails
            ) else {
            return nil
        }

        let chainAsset = state.stakingOption.chainAsset

        let wireframe = MythosStakingSetupWireframe(state: state)

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let accountDetailsFactory = CollatorStakingAccountViewModelFactory(chainAsset: chainAsset)

        let localizationManager = LocalizationManager.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let dataValidationFactory = MythosStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = MythosStakingSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            dataValidationFactory: dataValidationFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            accountDetailsViewModelFactory: accountDetailsFactory,
            initialStakingDetails: initialStakingDetails,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let localizableTitle = CollatorStakingStakeScreenTitle.setup(
            hasStake: initialStakingDetails != nil,
            assetSymbol: chainAsset.asset.symbol
        )

        let view = CollatorStakingSetupViewController(
            presenter: presenter,
            localizableTitle: localizableTitle(),
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidationFactory.view = view

        return view
    }

    private static func createInteractor(
        for state: MythosStakingSharedStateProtocol,
        initialStakingDetails: MythosStakingDetails?
    ) -> MythosStakingSetupInteractor? {
        let chain = state.stakingOption.chainAsset.chain

        guard
            let selectedAccount = SelectedWalletSettings.shared.value.fetch(
                for: state.stakingOption.chainAsset.chain.accountRequest()
            ),
            let stakingDetailsService = state.detailsSyncService,
            let claimableRewardsService = state.claimableRewardsService,
            let connection = state.chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: chain.chainId),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let repositoryFactory = SubstrateRepositoryFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(
            account: selectedAccount,
            chain: chain
        )

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            )
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)
        let identityProxyFactory = IdentityProxyFactory(
            originChain: chain,
            chainRegistry: state.chainRegistry,
            identityOperationFactory: identityOperationFactory
        )

        let preferredCollatorFactory: PreferredStakingCollatorFactory? = if initialStakingDetails == nil {
            // add pref collators only for first staking

            PreferredStakingCollatorFactory(
                chain: chain,
                connection: connection,
                runtimeService: runtimeProvider,
                collatorService: state.collatorService,
                rewardService: state.rewardCalculatorService,
                identityProxyFactory: identityProxyFactory,
                preferredCollatorProvider: state.preferredCollatorsProvider,
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            )
        } else {
            nil
        }

        return MythosStakingSetupInteractor(
            chainAsset: state.stakingOption.chainAsset,
            selectedAccount: selectedAccount,
            stakingDetailsService: stakingDetailsService,
            claimableRewardsService: claimableRewardsService,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            rewardService: state.rewardCalculatorService,
            preferredCollatorFactory: preferredCollatorFactory,
            extrinsicService: extrinsicService,
            connection: connection,
            runtimeProvider: runtimeProvider,
            repositoryFactory: repositoryFactory,
            identityProxyFactory: identityProxyFactory,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }
}
