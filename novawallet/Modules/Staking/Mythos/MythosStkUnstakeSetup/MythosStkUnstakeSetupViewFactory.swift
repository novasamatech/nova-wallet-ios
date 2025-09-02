import Foundation
import Foundation_iOS

struct MythosStkUnstakeSetupViewFactory {
    static func createView(
        for state: MythosStakingSharedStateProtocol
    ) -> CollatorStkFullUnstakeSetupViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: state,
                chainAsset: chainAsset,
                currencyManager: currencyManager
            ) else {
            return nil
        }

        let wireframe = MythosStkUnstakeSetupWireframe(state: state)

        let assetDisplayInfo = chainAsset.assetDisplayInfo

        let priceInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceInfoFactory
        )

        let dataValidatingFactory = MythosStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceInfoFactory
        )

        let presenter = MythosStkUnstakeSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactory(chainAsset: chainAsset),
            hintViewModelFactory: CollatorStakingHintsViewModelFactory(),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = CollatorStkFullUnstakeSetupVC(
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
        currencyManager: CurrencyManagerProtocol
    ) -> MythosStkUnstakeSetupInteractor? {
        guard
            let stakingDetailsService = state.detailsSyncService,
            let claimableRewardsService = state.claimableRewardsService,
            let identitiesService = state.collatorIdentitiesSyncService,
            let selectedAccount = SelectedWalletSettings.shared.value?.fetch(
                for: chainAsset.chain.accountRequest()
            ),
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

        return MythosStkUnstakeSetupInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            stakingDetailsService: stakingDetailsService,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            claimableRewardsService: claimableRewardsService,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicService: extrinsicService,
            connection: connection,
            runtimeProvider: runtimeService,
            stakingDurationFactory: stakingDurationFactory,
            blocktimeEstimationService: state.blockTimeService,
            identitySyncService: identitiesService,
            currencyManager: currencyManager,
            operationQueue: operationQueue,
            logger: Logger.shared
        )
    }
}
