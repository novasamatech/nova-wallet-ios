import Foundation
import Foundation_iOS
import SubstrateSdk
import Keystore_iOS

struct ParaStkStakeConfirmViewFactory {
    static func createView(
        for state: ParachainStakingSharedStateProtocol,
        collator: DisplayAddress,
        amount: Decimal,
        initialDelegator: ParachainStaking.Delegator?
    ) -> CollatorStakingConfirmViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared,
            let selectedAccount = selectedMetaAccount.fetchMetaChainAccount(for: chainAsset.chain.accountRequest())
        else {
            return nil
        }

        guard let interactor = createInteractor(from: state, collator: collator) else {
            return nil
        }

        let wireframe = ParaStkStakeConfirmWireframe()

        let localizationManager = LocalizationManager.shared

        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let dataValidatingFactory = ParachainStaking.ValidatorFactory(
            presentable: wireframe,
            assetDisplayInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = ParaStkStakeConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            dataValidatingFactory: dataValidatingFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            collator: collator,
            amount: amount,
            initialDelegator: initialDelegator,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let localizableTitle = CollatorStakingStakeScreenTitle.confirm(hasStake: initialDelegator != nil)

        let view = CollatorStakingConfirmViewController(
            presenter: presenter,
            localizableTitle: localizableTitle(),
            localizationManager: localizationManager
        )

        presenter.view = view
        dataValidatingFactory.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        from state: ParachainStakingSharedStateProtocol,
        collator: DisplayAddress
    ) -> ParaStkStakeConfirmInteractor? {
        let optMetaAccount = SelectedWalletSettings.shared.value
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let chainAsset = state.stakingOption.chainAsset

        guard
            let selectedAccount = optMetaAccount?.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let currencyManager = CurrencyManager.shared
        else {
            return nil
        }

        let blockEstimationService = state.blockTimeService

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount.chainAccount, chain: chainAsset.chain)

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

        return ParaStkStakeConfirmInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            selectedCollator: collator,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            signer: signer,
            connection: connection,
            runtimeProvider: runtimeProvider,
            stakingDurationFactory: stakingDurationFactory,
            blockEstimationService: blockEstimationService,
            sharedOperation: state.sharedOperation,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
