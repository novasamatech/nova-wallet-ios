import Foundation
import SoraFoundation

struct NominationPoolBondMoreSetupViewFactory {
    static func createView(state: NPoolsStakingSharedStateProtocol) -> NominationPoolBondMoreSetupViewProtocol? {
        guard let currencyManager = CurrencyManager.shared,
              let interactor = createInteractor(state: state) else {
            return nil
        }
        let wireframe = NominationPoolBondMoreSetupWireframe(state: state)
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: state.chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        let hintsViewModelFactory = NominationPoolsBondMoreHintsFactory(
            chainAsset: state.chainAsset,
            balanceViewModelFactory: balanceViewModelFactory
        )
        let localizationManager = LocalizationManager.shared
        let dataValidatorFactory = NominationPoolDataValidatorFactory(
            presentable: wireframe,
            balanceFactory: balanceViewModelFactory
        )

        let presenter = NominationPoolBondMoreSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: state.chainAsset,
            hintsViewModelFactory: hintsViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatorFactory: dataValidatorFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = NominationPoolBondMoreSetupViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.baseView = view
        interactor.basePresenter = presenter
        dataValidatorFactory.view = view
        return view
    }

    static func createInteractor(state: NPoolsStakingSharedStateProtocol) -> NominationPoolBondMoreSetupInteractor? {
        let chainAsset = state.chainAsset

        guard
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared,
            let selectedAccount = selectedMetaAccount.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ) else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeRegistry = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }
        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeRegistry,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager
        )
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        return .init(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            runtimeService: runtimeRegistry,
            feeProxy: ExtrinsicFeeProxy(),
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            callFactory: SubstrateCallFactory(),
            extrinsicServiceFactory: extrinsicServiceFactory,
            npoolsOperationFactory: NominationPoolsOperationFactory(operationQueue: operationQueue),
            npoolsLocalSubscriptionFactory: state.npLocalSubscriptionFactory,
            stakingLocalSubscriptionFactory: state.relaychainLocalSubscriptionFactory,
            assetStorageInfoFactory: AssetStorageInfoOperationFactory(),
            operationQueue: operationQueue,
            currencyManager: currencyManager
        )
    }
}
