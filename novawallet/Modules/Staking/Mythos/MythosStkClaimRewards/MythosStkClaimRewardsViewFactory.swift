import Foundation
import Foundation_iOS
import Keystore_iOS

struct MythosStkClaimRewardsViewFactory {
    static func createView(for state: MythosStakingSharedStateProtocol) -> StakingGenericRewardsViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let selectedAccount = SelectedWalletSettings.shared.value.fetchMetaChainAccount(
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

        let wireframe = MythosStkClaimRewardsWireframe()

        let priceAssetInfo = PriceAssetInfoFactory(currencyManager: currencyManager)

        let dataValidationFactory = MythosStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfo
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfo
        )

        let presenter = MythosStkClaimRewardsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            dataValidatorFactory: dataValidationFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = MythosStkClaimRewardsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidationFactory.view = view

        return view
    }

    private static func createInteractor(
        for state: MythosStakingSharedStateProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        currencyManager: CurrencyManagerProtocol
    ) -> MythosStkClaimRewardsInteractor? {
        guard
            let rewardsSyncService = state.claimableRewardsService,
            let detailsSyncService = state.detailsSyncService,
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

        return MythosStkClaimRewardsInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            extrinsicService: extrinsicService,
            submissionMonitor: submissionMonitor,
            signingWrapper: signingWrapper,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            stakingDetailsService: detailsSyncService,
            rewardsSyncService: rewardsSyncService,
            settingsManager: SettingsManager.shared,
            operationQueue: operationQueue,
            currencyManager: currencyManager,
            logger: Logger.shared
        )
    }
}
