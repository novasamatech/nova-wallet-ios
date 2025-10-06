import Foundation
import SubstrateSdk
import Operation_iOS
import Foundation_iOS

struct NPoolsRedeemViewFactory {
    static func createView(for state: NPoolsStakingSharedStateProtocol) -> NPoolsRedeemViewProtocol? {
        guard
            let interactor = createInteractor(for: state),
            let wallet = SelectedWalletSettings.shared.value,
            let selectedAccount = wallet.fetchMetaChainAccount(for: state.chainAsset.chain.accountRequest()),
            let currencyManager = CurrencyManager.shared,
            let stakingActivity = StakingActivityForValidation(
                wallet: SelectedWalletSettings.shared.value,
                chain: state.chainAsset.chain,
                chainRegistry: ChainRegistryFacade.sharedRegistry,
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            ) else {
            return nil
        }

        let wireframe = NPoolsRedeemWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: state.chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let dataValidatingFactory = NominationPoolDataValidatorFactory(
            presentable: wireframe,
            balanceFactory: balanceViewModelFactory
        )

        let presenter = NPoolsRedeemPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedAccount: selectedAccount,
            chainAsset: state.chainAsset,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatorFactory: dataValidatingFactory,
            stakingActivity: stakingActivity,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = NPoolsRedeemViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        for state: NPoolsStakingSharedStateProtocol
    ) -> NPoolsRedeemInteractor? {
        let chainAsset = state.chainAsset
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let selectedAccount = SelectedWalletSettings.shared.value?.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        )

        let extrinsicService = extrinsicServiceFactory.createService(
            account: selectedAccount.chainAccount,
            chain: chainAsset.chain
        )

        let extrinsicMonitorFactory = extrinsicServiceFactory.createExtrinsicSubmissionMonitor(
            with: extrinsicService
        )

        let signingWrapper = SigningWrapperFactory.createSigner(from: selectedAccount)

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let slashesOperationFactory = SlashesOperationFactory(
            storageRequestFactory: storageRequestFactory,
            operationQueue: operationQueue
        )
        let npoolsOperationFactory = NominationPoolsOperationFactory(operationQueue: operationQueue)

        return NPoolsRedeemInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            extrinsicService: extrinsicService,
            extrinsicServiceMonitor: extrinsicMonitorFactory,
            feeProxy: ExtrinsicFeeProxy(),
            signingWrapper: signingWrapper,
            slashesOperationFactory: slashesOperationFactory,
            npoolsLocalSubscriptionFactory: state.npLocalSubscriptionFactory,
            stakingLocalSubscriptionFactory: state.relaychainLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            npoolsOperationFactory: npoolsOperationFactory,
            connection: connection,
            runtimeService: runtimeService,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }
}
