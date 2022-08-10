import Foundation
import SoraFoundation
import SubstrateSdk
import SoraKeystore

struct ParaStkStakeConfirmViewFactory {
    static func createView(
        for state: ParachainStakingSharedState,
        collator: DisplayAddress,
        amount: Decimal,
        initialDelegator: ParachainStaking.Delegator?
    ) -> ParaStkStakeConfirmViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
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
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetDisplayInfo)

        let dataValidatingFactory = ParachainStaking.ValidatorFactory(
            presentable: wireframe,
            assetDisplayInfo: assetDisplayInfo
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

        let localizableTitle: LocalizableResource<String>

        if initialDelegator != nil {
            localizableTitle = LocalizableResource { locale in
                R.string.localizable.stakingBondMore_v190(preferredLanguages: locale.rLanguages)
            }
        } else {
            localizableTitle = LocalizableResource { locale in
                R.string.localizable.stakingStartTitle(preferredLanguages: locale.rLanguages)
            }
        }

        let view = ParaStkStakeConfirmViewController(
            presenter: presenter,
            localizableTitle: localizableTitle,
            localizationManager: localizationManager
        )

        presenter.view = view
        dataValidatingFactory.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        from state: ParachainStakingSharedState,
        collator: DisplayAddress
    ) -> ParaStkStakeConfirmInteractor? {
        let optMetaAccount = SelectedWalletSettings.shared.value
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chainAsset = state.settings.value,
            let selectedAccount = optMetaAccount?.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let blockEstimationService = state.blockTimeService,
            let currencyManager = CurrencyManager.shared
        else {
            return nil
        }

        let extrinsicService = ExtrinsicService(
            accountId: selectedAccount.chainAccount.accountId,
            chain: chainAsset.chain,
            cryptoType: selectedAccount.chainAccount.cryptoType,
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager
        )

        let stakingDurationFactory = ParaStkDurationOperationFactory(
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
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
