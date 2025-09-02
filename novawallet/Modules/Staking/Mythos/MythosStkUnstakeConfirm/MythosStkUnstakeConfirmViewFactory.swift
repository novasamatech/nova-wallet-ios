import Foundation
import Foundation_iOS

struct MythosStkUnstakeConfirmViewFactory {
    static func createView(
        for state: MythosStakingSharedStateProtocol,
        selectedCollator: DisplayAddress
    ) -> CollatorStkUnstakeConfirmViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let selectedAccount = SelectedWalletSettings.shared.value.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ),
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: state,
                chainAsset: chainAsset,
                selectedAccount: selectedAccount.chainAccount,
                currencyManager: currencyManager
            ) else {
            return nil
        }

        let wireframe = MythosStkUnstakeConfirmWireframe(state: state)

        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let dataValidatingFactory = MythosStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = MythosStkUnstakeConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            selectedCollator: selectedCollator,
            dataValidatingFactory: dataValidatingFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            hintViewModelFactory: CollatorStakingHintsViewModelFactory(),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = CollatorStkUnstakeConfirmVC(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    // swiftlint:disable:next function_body_length
    private static func createInteractor(
        for state: MythosStakingSharedStateProtocol,
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        currencyManager: CurrencyManagerProtocol
    ) -> MythosStkUnstakeConfirmInteractor? {
        guard
            let stakingDetailsService = state.detailsSyncService,
            let claimableRewardsService = state.claimableRewardsService,
            let connection = state.chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = state.chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount, chain: chainAsset.chain)

        let stakingDurationFactory = MythosStkDurationOperationFactory(
            chainRegistry: state.chainRegistry,
            blockTimeOperationFactory: BlockTimeOperationFactory(chain: chainAsset.chain)
        )

        let eventsFactory = BlockEventsQueryFactory(operationQueue: operationQueue)
        let statusService = ExtrinsicStatusService(
            connection: connection,
            runtimeProvider: runtimeService,
            eventsQueryFactory: eventsFactory,
            logger: Logger.shared
        )
        let submissionFactory = ExtrinsicSubmissionMonitorFactory(
            submissionService: extrinsicService,
            statusService: statusService,
            operationQueue: operationQueue
        )

        let signerFactory = SigningWrapperFactory()
        let signer = signerFactory.createSigningWrapper(for: selectedAccount.metaId, accountResponse: selectedAccount)

        return MythosStkUnstakeConfirmInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            stakingDetailsService: stakingDetailsService,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            claimableRewardsService: claimableRewardsService,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicService: extrinsicService,
            submissionFactory: submissionFactory,
            signer: signer,
            connection: connection,
            runtimeProvider: runtimeService,
            stakingDurationFactory: stakingDurationFactory,
            blocktimeEstimationService: state.blockTimeService,
            currencyManager: currencyManager,
            operationQueue: operationQueue,
            logger: Logger.shared
        )
    }
}
