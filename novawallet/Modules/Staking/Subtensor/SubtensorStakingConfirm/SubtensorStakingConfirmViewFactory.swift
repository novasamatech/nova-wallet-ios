import Foundation
import Foundation_iOS
import Operation_iOS

enum SubtensorStakingConfirmViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        model: SubtensorStakingConfirmModel
    ) -> CollatorStakingConfirmViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let interactor = createInteractor(for: state),
            let currencyManager = CurrencyManager.shared,
            let selectedAccount = SelectedWalletSettings.shared.value.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ) else {
            return nil
        }

        let wireframe = SubtensorStakingConfirmWireframe(state: state)

        let localizationManager = LocalizationManager.shared

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let dataValidationFactory = SubtensorStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = SubtensorStakingConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            model: model,
            dataValidationFactory: dataValidationFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let screenTitle = CollatorStakingStakeScreenTitle.confirm(hasStake: model.isStakeMore)

        let view = CollatorStakingConfirmViewController(
            presenter: presenter,
            localizableTitle: screenTitle(),
            statics: .subtensorValidator,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidationFactory.view = view

        return view
    }

    private static func createInteractor(
        for state: SubtensorStakingSharedStateProtocol
    ) -> SubtensorStakingConfirmInteractor? {
        let chain = state.stakingOption.chainAsset.chain

        guard
            let selectedAccount = SelectedWalletSettings.shared.value.fetch(
                for: chain.accountRequest()
            ),
            let positionsSyncService = state.positionsSyncService,
            let rootClaimableService = state.rootClaimableService,
            let connection = state.chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: chain.chainId),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(
            account: selectedAccount,
            chain: chain
        )

        let extrinsicSubmitMonitor = ExtrinsicSubmissionMonitorFactory(
            submissionService: extrinsicService,
            statusService: ExtrinsicStatusService(
                connection: connection,
                runtimeProvider: runtimeProvider,
                eventsQueryFactory: BlockEventsQueryFactory(operationQueue: operationQueue),
                logger: Logger.shared
            ),
            operationQueue: operationQueue
        )

        let signer = SigningWrapperFactory().createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount
        )

        let preflightFactory = SubtensorPreflightFactory(
            runtimeConnectionStore: ChainRegistryRuntimeConnectionStore(
                chainId: chain.chainId,
                chainRegistry: state.chainRegistry
            ),
            operationFactory: state.apiOperationFactory,
            operationQueue: operationQueue
        )

        return SubtensorStakingConfirmInteractor(
            chainAsset: state.stakingOption.chainAsset,
            selectedAccount: selectedAccount,
            positionsSyncService: positionsSyncService,
            rootClaimableService: rootClaimableService,
            preflightFactory: preflightFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            extrinsicSubmitMonitor: extrinsicSubmitMonitor,
            signer: signer,
            sharedOperation: state.sharedOperation,
            extrinsicService: extrinsicService,
            runtimeProvider: runtimeProvider,
            currencyManager: currencyManager,
            operationQueue: operationQueue,
            logger: Logger.shared
        )
    }
}
