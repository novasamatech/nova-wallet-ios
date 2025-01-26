import Foundation
import SoraFoundation

struct MythosStakingConfirmViewFactory {
    static func createView(
        for state: MythosStakingSharedStateProtocol,
        model: MythosStakingConfirmModel
    ) -> CollatorStakingConfirmViewProtocol? {
        guard
            let interactor = createInteractor(for: state),
            let currencyManager = CurrencyManager.shared,
            let selectedAccount = SelectedWalletSettings.shared.value.fetchMetaChainAccount(
                for: state.stakingOption.chainAsset.chain.accountRequest()
            ) else {
            return nil
        }

        let wireframe = MythosStakingConfirmWireframe()

        let localizationManager = LocalizationManager.shared

        let assetDisplayInfo = state.stakingOption.chainAsset.assetDisplayInfo
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = MythosStakingConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedAccount: selectedAccount,
            chainAsset: state.stakingOption.chainAsset,
            model: model,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let screenTitle = CollatorStakingStakeScreenTitle.confirm(hasStake: model.stakingDetails != nil)

        let view = CollatorStakingConfirmViewController(
            presenter: presenter,
            localizableTitle: screenTitle(),
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for state: MythosStakingSharedStateProtocol
    ) -> MythosStakingConfirmInteractor? {
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

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let extrinsicSubmissionMonitor = ExtrinsicSubmissionMonitorFactory(
            submissionService: extrinsicService,
            statusService: ExtrinsicStatusService(
                connection: connection,
                runtimeProvider: runtimeProvider,
                eventsQueryFactory: BlockEventsQueryFactory(operationQueue: operationQueue)
            ),
            operationQueue: operationQueue
        )

        let signer = SigningWrapperFactory().createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount
        )

        return MythosStakingConfirmInteractor(
            chainAsset: state.stakingOption.chainAsset,
            selectedAccount: selectedAccount,
            stakingDetailsService: stakingDetailsService,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            extrinsicSubmitionMonitor: extrinsicSubmissionMonitor,
            signer: signer,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            runtimeProvider: runtimeProvider,
            currencyManager: currencyManager,
            operationQueue: operationQueue,
            logger: Logger.shared
        )
    }
}
