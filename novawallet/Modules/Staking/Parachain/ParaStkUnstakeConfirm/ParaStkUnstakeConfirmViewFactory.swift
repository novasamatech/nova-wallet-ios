import Foundation
import Foundation_iOS
import SubstrateSdk
import Keystore_iOS

struct ParaStkUnstakeConfirmViewFactory {
    static func createView(
        for state: ParachainStakingSharedStateProtocol,
        callWrapper: UnstakeCallWrapper,
        collator: DisplayAddress
    ) -> CollatorStkUnstakeConfirmViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let interactor = createInteractor(from: state),
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared,
            let selectedAccount = selectedMetaAccount.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ) else {
            return nil
        }

        let wireframe = ParaStkUnstakeConfirmWireframe()

        let localizationManager = LocalizationManager.shared

        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let dataValidationFactory = ParachainStaking.ValidatorFactory(
            presentable: wireframe,
            assetDisplayInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = ParaStkUnstakeConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            selectedCollator: collator,
            callWrapper: callWrapper,
            dataValidatingFactory: dataValidationFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            hintViewModelFactory: CollatorStakingHintsViewModelFactory(),
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = CollatorStkUnstakeConfirmVC(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.basePresenter = presenter
        dataValidationFactory.view = view

        return view
    }

    private static func createInteractor(
        from state: ParachainStakingSharedStateProtocol
    ) -> ParaStkUnstakeConfirmInteractor? {
        let optMetaAccount = SelectedWalletSettings.shared.value
        let chainRegistry = state.chainRegistry

        let chainAsset = state.stakingOption.chainAsset

        guard
            let selectedAccount = optMetaAccount?.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let currencyManager = CurrencyManager.shared
        else {
            return nil
        }

        let blocktimeService = state.blockTimeService

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount.chainAccount, chain: chainAsset.chain)

        let storageFacade = SubstrateDataStorageFacade.shared
        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: storageFacade)

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let stakingDurationFactory = ParaStkDurationOperationFactory(
            storageRequestFactory: storageRequestFactory,
            blockTimeOperationFactory: BlockTimeOperationFactory(chain: chainAsset.chain)
        )

        let signer = SigningWrapperFactory().createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount.chainAccount
        )

        return ParaStkUnstakeConfirmInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            signer: signer,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            connection: connection,
            runtimeProvider: runtimeProvider,
            stakingDurationFactory: stakingDurationFactory,
            blocktimeEstimationService: blocktimeService,
            repositoryFactory: repositoryFactory,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
