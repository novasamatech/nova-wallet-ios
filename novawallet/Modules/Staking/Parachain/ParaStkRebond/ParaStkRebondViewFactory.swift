import Foundation
import SoraKeystore
import SubstrateSdk
import SoraFoundation

struct ParaStkRebondViewFactory {
    static func createView(
        for state: ParachainStakingSharedState,
        selectedCollator: AccountId,
        collatorIdentity: AccountIdentity?
    ) -> ParaStkRebondViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let interactor = createInteractor(from: state),
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
            let selectedAccount = selectedMetaAccount.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ) else {
            return nil
        }

        let wireframe = ParaStkRebondWireframe()

        let localizationManager = LocalizationManager.shared

        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetDisplayInfo)

        let dataValidationFactory = ParachainStaking.ValidatorFactory(
            presentable: wireframe,
            assetDisplayInfo: assetDisplayInfo
        )

        let hintViewModelFactory = ParaStkHintsViewModelFactory()

        let presenter = ParaStkRebondPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            selectedCollator: selectedCollator,
            collatorIdentity: collatorIdentity,
            dataValidatingFactory: dataValidationFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            hintViewModelFactory: hintViewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ParaStkRebondViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view
        interactor.presenter = presenter
        dataValidationFactory.view = view

        return view
    }

    private static func createInteractor(
        from state: ParachainStakingSharedState
    ) -> ParaStkRebondInteractor? {
        let optMetaAccount = SelectedWalletSettings.shared.value
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chainAsset = state.settings.value,
            let selectedAccount = optMetaAccount?.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId)
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

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageRequestFactory)

        let signer = SigningWrapper(
            keystore: Keychain(),
            metaId: selectedAccount.metaId,
            accountResponse: selectedAccount.chainAccount
        )

        return ParaStkRebondInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            signer: signer,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            identityOperationFactory: identityOperationFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
