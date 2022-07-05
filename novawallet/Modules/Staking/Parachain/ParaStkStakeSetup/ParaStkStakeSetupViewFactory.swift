import Foundation
import SoraFoundation
import SubstrateSdk

struct ParaStkStakeSetupViewFactory {
    static func createView(
        with state: ParachainStakingSharedState,
        initialDelegator: ParachainStaking.Delegator?,
        initialScheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        delegationIdentities: [AccountId: AccountIdentity]?
    ) -> ParaStkStakeSetupViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let interactor = createInteractor(from: state) else {
            return nil
        }

        let wireframe = ParaStkStakeSetupWireframe(state: state)

        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetDisplayInfo)

        let dataValidationFactory = ParachainStaking.ValidatorFactory(
            presentable: wireframe,
            assetDisplayInfo: assetDisplayInfo
        )

        let accountDetailsFactory = ParaStkAccountDetailsViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            chainFormat: chainAsset.chain.chainFormat,
            assetPrecision: assetDisplayInfo.assetPrecision
        )

        let localizationManager = LocalizationManager.shared
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

        let localizableTitle = createTitle(for: initialDelegator, chainAsset: chainAsset)

        let view = ParaStkStakeSetupViewController(
            presenter: presenter,
            localizableTitle: localizableTitle,
            localizationManager: localizationManager
        )

        presenter.view = view
        dataValidationFactory.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createTitle(
        for delegator: ParachainStaking.Delegator?,
        chainAsset: ChainAsset
    ) -> LocalizableResource<String> {
        if delegator != nil {
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
        from state: ParachainStakingSharedState
    ) -> ParaStkStakeSetupInteractor? {
        let optMetaAccount = SelectedWalletSettings.shared.value
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chainAsset = state.settings.value,
            let selectedAccount = optMetaAccount?.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()),
            let collatorService = state.collatorService,
            let rewardService = state.rewardCalculationService,
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId)
        else {
            return nil
        }

        let extrinsicService = ExtrinsicService(
            accountId: selectedAccount.chainAccount.accountId,
            chain: chainAsset.chain,
            cryptoType: selectedAccount.chainAccount.cryptoType,
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager
        )

        let operationManager = OperationManagerFacade.sharedManager

        let storageFacade = SubstrateDataStorageFacade.shared
        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: storageFacade)
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)

        return ParaStkStakeSetupInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            collatorService: collatorService,
            rewardService: rewardService,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            connection: connection,
            runtimeProvider: runtimeProvider,
            repositoryFactory: repositoryFactory,
            identityOperationFactory: identityOperationFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
