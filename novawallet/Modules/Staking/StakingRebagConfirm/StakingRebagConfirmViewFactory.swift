import Foundation
import SoraFoundation

struct StakingRebagConfirmViewFactory {
    static func createView(with state: StakingSharedState) -> StakingRebagConfirmViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared,
            let selectedAccount = selectedMetaAccount.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()),
            let networkInfoFactory = try? state.createNetworkInfoOperationFactory(for: chainAsset.chain),
            let eraValidatorService = state.eraValidatorService
        else {
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

        let accountRepositoryFactory = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )

        let interactor = StakingRebagConfirmInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            feeProxy: ExtrinsicFeeProxy(),
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            networkInfoFactory: networkInfoFactory,
            eraValidatorService: eraValidatorService,
            runtimeService: runtimeRegistry,
            extrinsicServiceFactory: extrinsicServiceFactory,
            signingWrapperFactory: SigningWrapperFactory(),
            accountRepositoryFactory: accountRepositoryFactory,
            callFactory: SubstrateCallFactory(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            currencyManager: currencyManager
        )

        let wireframe = StakingRebagConfirmWireframe()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let assetDisplayInfo = AssetBalanceDisplayInfo(
            displayPrecision: chainAsset.assetDisplayInfo.displayPrecision,
            assetPrecision: chainAsset.assetDisplayInfo.assetPrecision,
            symbol: "",
            symbolValueSeparator: "",
            symbolPosition: .prefix,
            icon: nil
        )
        let tokenlessBalanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingRebagConfirmPresenter(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            tokenlessBalanceViewModelFactory: tokenlessBalanceViewModelFactory,
            localizationManager: LocalizationManager.shared,
            dataValidatingFactory: dataValidatingFactory,
            logger: Logger.shared
        )

        let view = StakingRebagConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
