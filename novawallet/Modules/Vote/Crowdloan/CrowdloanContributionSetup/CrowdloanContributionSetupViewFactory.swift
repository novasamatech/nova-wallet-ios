import Foundation
import Keystore_iOS
import Foundation_iOS

struct CrowdloanContributionSetupViewFactory {
    static func createView(
        for paraId: ParaId,
        state: CrowdloanSharedState,
        bonusService: CrowdloanBonusServiceProtocol? = nil
    ) -> CrowdloanContributionSetupViewProtocol? {
        guard
            let chain = state.settings.value,
            let asset = chain.utilityAssets().first,
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(for: paraId, chain: chain, asset: asset, state: state) else {
            return nil
        }

        let wireframe = CrowdloanContributionSetupWireframe(
            state: state,
            settingsManager: SettingsManager.shared
        )

        let assetInfo = asset.displayInfo(with: chain.icon)
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let localizationManager = LocalizationManager.shared

        let contributionViewModelFactory = CrowdloanContributionViewModelFactory(
            assetInfo: assetInfo,
            chainDateCalculator: ChainDateCalculator()
        )

        let dataValidatingFactory = CrowdloanDataValidatingFactory(
            presentable: wireframe,
            assetInfo: assetInfo
        )

        let presenter = CrowdloanContributionSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            contributionViewModelFactory: contributionViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo,
            localizationManager: localizationManager,
            bonusService: bonusService,
            chain: chain,
            logger: Logger.shared
        )

        let view = CrowdloanContributionSetupViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        for paraId: ParaId,
        chain: ChainModel,
        asset: AssetModel,
        state: CrowdloanSharedState
    ) -> CrowdloanContributionSetupInteractor? {
        guard let selectedMetaAccount = SelectedWalletSettings.shared.value,
              let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        guard let accountResponse = selectedMetaAccount.fetch(for: chain.accountRequest()) else {
            return nil
        }

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: accountResponse, chain: chain)

        let feeProxy = ExtrinsicFeeProxy()

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let priceLocalSubscriptionFactory = PriceProviderFactory.shared

        let jsonLocalSubscriptionFactory = JsonDataProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        return CrowdloanContributionSetupInteractor(
            paraId: paraId,
            selectedMetaAccount: selectedMetaAccount,
            chain: chain,
            asset: asset,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            crowdloanLocalSubscriptionFactory: state.crowdloanLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            jsonLocalSubscriptionFactory: jsonLocalSubscriptionFactory,
            operationManager: operationManager,
            currencyManager: currencyManager
        )
    }
}
