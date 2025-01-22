import Foundation
import SoraFoundation

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

        let wireframe = MythosStakingSetupWireframe()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let accountDetailsFactory = CollatorStakingAccountViewModelFactory(chainAsset: chainAsset)

        let localizationManager = LocalizationManager.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = MythosStakingSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceViewModelFactory,
            accountDetailsViewModelFactory: accountDetailsFactory,
            initialStakingDetails: initialStakingDetails,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let localizableTitle = createTitle(for: initialStakingDetails, chainAsset: chainAsset)

        let view = CollatorStakingSetupViewController(
            presenter: presenter,
            localizableTitle: localizableTitle,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createTitle(
        for stakingDetails: MythosStakingDetails?,
        chainAsset: ChainAsset
    ) -> LocalizableResource<String> {
        if stakingDetails != nil {
            return LocalizableResource { locale in
                R.string.localizable.stakingBondMore_v190(preferredLanguages: locale.rLanguages)
            }
        } else {
            return LocalizableResource { locale in
                R.string.localizable.stakingStakeFormat(chainAsset.asset.symbol, preferredLanguages: locale.rLanguages)
            }
        }
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

        let preferredCollatorFactory: PreferredStakingCollatorFactory? = if initialStakingDetails == nil {
            // add pref collators only for first staking

            // TODO: Add implementation here

            /* PreferredStakingCollatorFactory(
                 chain: chainAsset.chain,
                 connection: connection,
                 runtimeService: runtimeProvider,
                 collatorService: collatorService,
                 rewardService: rewardService,
                 identityProxyFactory: identityProxyFactory,
                 preferredCollatorProvider: state.preferredCollatorsProvider,
                 operationQueue: OperationManagerFacade.sharedDefaultQueue
             ) */
            nil
        } else {
            nil
        }

        return MythosStakingSetupInteractor(
            chainAsset: state.stakingOption.chainAsset,
            selectedAccount: selectedAccount,
            stakingDetailsService: stakingDetailsService,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            preferredCollatorFactory: preferredCollatorFactory,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            connection: connection,
            runtimeProvider: runtimeProvider,
            repositoryFactory: repositoryFactory,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }
}
