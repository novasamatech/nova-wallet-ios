import Foundation
import SubstrateSdk
import RobinHood
import SoraFoundation

struct NPoolsRedeemViewFactory {
    static func createView(for state: NPoolsStakingSharedStateProtocol) -> NPoolsRedeemViewProtocol? {
        guard
            let interactor = createInteractor(for: state),
            let wallet = SelectedWalletSettings.shared.value,
            let selectedAccount = wallet.fetchMetaChainAccount(for: state.chainAsset.chain.accountRequest()),
            let currencyManager = CurrencyManager.shared else {
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

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue)
        ).createService(account: selectedAccount.chainAccount, chain: chainAsset.chain)

        let signingWrapper = SigningWrapperFactory.createSigner(from: selectedAccount)

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let slashesOperationFactory = SlashesOperationFactory(storageRequestFactory: storageRequestFactory)
        let npoolsOperationFactory = NominationPoolsOperationFactory(operationQueue: operationQueue)

        return NPoolsRedeemInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            extrinsicService: extrinsicService,
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
