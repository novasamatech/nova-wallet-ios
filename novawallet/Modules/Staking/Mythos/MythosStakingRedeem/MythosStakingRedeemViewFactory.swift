import Foundation
import Foundation_iOS

struct MythosStakingRedeemViewFactory {
    static func createView(
        for state: MythosStakingSharedStateProtocol
    ) -> CollatorStakingRedeemViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let selectedAccount = SelectedWalletSettings.shared.value?.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ),
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: state,
                chainAsset: chainAsset,
                selectedAccount: selectedAccount,
                currencyManager: currencyManager
            ) else {
            return nil
        }

        let wireframe = MythosStakingRedeemWireframe()

        let assetInfo = chainAsset.assetDisplayInfo
        let priceInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceInfoFactory
        )

        let dataValidatingFactory = MythosStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: assetInfo,
            priceAssetInfoFactory: priceInfoFactory
        )

        let presenter = MythosStakingRedeemPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            dataValidatingFactory: dataValidatingFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = CollatorStakingRedeemViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        for state: MythosStakingSharedStateProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        currencyManager: CurrencyManagerProtocol
    ) -> MythosStakingRedeemInteractor? {
        guard
            let runtimeService = state.chainRegistry.getRuntimeProvider(
                for: chainAsset.chain.chainId
            ),
            let connection = state.chainRegistry.getConnection(
                for: chainAsset.chain.chainId
            ) else {
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

        let signingWrapper = SigningWrapperFactory().createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount.chainAccount
        )

        let submissionMonitor = ExtrinsicSubmissionMonitorFactory(
            submissionService: extrinsicService,
            statusService: ExtrinsicStatusService(
                connection: connection,
                runtimeProvider: runtimeService,
                eventsQueryFactory: BlockEventsQueryFactory(operationQueue: operationQueue),
                logger: Logger.shared
            ),
            operationQueue: operationQueue
        )

        return MythosStakingRedeemInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            extrinsicService: extrinsicService,
            submissionMonitor: submissionMonitor,
            signingWrapper: signingWrapper,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            operationQueue: operationQueue,
            currencyManager: currencyManager,
            logger: Logger.shared
        )
    }
}
