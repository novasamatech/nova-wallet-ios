import Foundation
import SoraFoundation
import SubstrateSdk

struct ParaStkUnstakeViewFactory {
    static func createView(
        with state: ParachainStakingSharedState,
        initialDelegator: ParachainStaking.Delegator?,
        initialScheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        delegationIdentities: [AccountId: AccountIdentity]?
    ) -> ParaStkUnstakeViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let interactor = createInteractor(from: state) else {
            return nil
        }

        let wireframe = ParaStkUnstakeWireframe(state: state)

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

        let presenter = ParaStkUnstakePresenter(
            interactor: interactor,
            wireframe: wireframe,
            dataValidatingFactory: dataValidationFactory,
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceViewModelFactory,
            accountDetailsViewModelFactory: accountDetailsFactory,
            hintViewModelFactory: ParaStkHintsViewModelFactory(),
            initialDelegator: initialDelegator,
            initialScheduledRequests: initialScheduledRequests,
            delegationIdentities: delegationIdentities,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ParaStkUnstakeViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.basePresenter = presenter
        dataValidationFactory.view = view

        return view
    }

    private static func createInteractor(
        from state: ParachainStakingSharedState
    ) -> ParaStkUnstakeInteractor? {
        let optMetaAccount = SelectedWalletSettings.shared.value
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chainAsset = state.settings.value,
            let selectedAccount = optMetaAccount?.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()),
            let blocktimeService = state.blockTimeService,
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId)
        else {
            return nil
        }

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager
        ).createService(account: selectedAccount.chainAccount, chain: chainAsset.chain)

        let operationManager = OperationManagerFacade.sharedManager

        let storageFacade = SubstrateDataStorageFacade.shared
        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: storageFacade)
        let keyFactory = StorageKeyFactory()
        let requestFactory = StorageRequestFactory(remoteFactory: keyFactory, operationManager: operationManager)

        let identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)
        let stakingDurationFactory = ParaStkDurationOperationFactory(
            blockTimeOperationFactory: BlockTimeOperationFactory(chain: chainAsset.chain)
        )

        return ParaStkUnstakeInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            identityOperationFactory: identityOperationFactory,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            connection: connection,
            runtimeProvider: runtimeProvider,
            stakingDurationFactory: stakingDurationFactory,
            blocktimeEstimationService: blocktimeService,
            repositoryFactory: repositoryFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
