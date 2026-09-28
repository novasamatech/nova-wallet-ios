import Foundation
import Foundation_iOS
import Operation_iOS
import SubstrateSdk

enum SubtensorStakingSetupViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        initialPosition: SubtensorStakingPosition?
    ) -> CollatorStakingSetupViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(for: state, initialPosition: initialPosition) else {
            return nil
        }

        let chainAsset = state.stakingOption.chainAsset

        let wireframe = SubtensorStakingSetupWireframe(state: state)

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let accountDetailsFactory = CollatorStakingAccountViewModelFactory(chainAsset: chainAsset)

        let localizationManager = LocalizationManager.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let dataValidationFactory = SubtensorStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = SubtensorStakingSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            dataValidationFactory: dataValidationFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            accountDetailsViewModelFactory: accountDetailsFactory,
            quoteViewModelFactory: SubtensorQuoteViewModelFactory(chainAsset: chainAsset),
            initialPosition: initialPosition,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let localizableTitle = CollatorStakingStakeScreenTitle.setup(
            hasStake: initialPosition != nil,
            assetSymbol: chainAsset.asset.symbol
        )

        let view = SubtensorStakingSetupViewController(
            presenter: presenter,
            localizableTitle: localizableTitle(),
            statics: .subtensorValidator,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidationFactory.view = view

        return view
    }

    private static func createInteractor(
        for state: SubtensorStakingSharedStateProtocol,
        initialPosition: SubtensorStakingPosition?
    ) -> SubtensorStakingSetupInteractor? {
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

        let preflightFactory = SubtensorPreflightFactory(
            runtimeConnectionStore: ChainRegistryRuntimeConnectionStore(
                chainId: chain.chainId,
                chainRegistry: state.chainRegistry
            ),
            operationFactory: state.apiOperationFactory,
            operationQueue: operationQueue
        )

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let identityProxyFactory = IdentityProxyFactory(
            originChain: chain,
            chainRegistry: state.chainRegistry,
            identityOperationFactory: IdentityOperationFactory(requestFactory: requestFactory)
        )

        return SubtensorStakingSetupInteractor(
            chainAsset: state.stakingOption.chainAsset,
            selectedAccount: selectedAccount,
            positionsSyncService: positionsSyncService,
            rootClaimableService: rootClaimableService,
            preflightFactory: preflightFactory,
            quoteFactory: SubtensorQuoteOperationFactory(
                operationFactory: state.apiOperationFactory,
                operationQueue: operationQueue
            ),
            rewardCalculatorService: state.rewardCalculatorService,
            subnetsService: state.subnetsService,
            initialNetuid: initialPosition?.netuid,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            extrinsicService: extrinsicService,
            runtimeProvider: runtimeProvider,
            identityProxyFactory: identityProxyFactory,
            currencyManager: currencyManager,
            operationQueue: operationQueue,
            logger: Logger.shared
        )
    }
}
