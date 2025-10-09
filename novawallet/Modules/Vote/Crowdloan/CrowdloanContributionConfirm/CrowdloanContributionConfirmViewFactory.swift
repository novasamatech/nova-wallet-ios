import Foundation
import Foundation_iOS
import Keystore_iOS
import Operation_iOS

struct CrowdloanContributionConfirmViewFactory {
    static func createView(
        with paraId: ParaId,
        inputAmount: Decimal,
        bonusService: CrowdloanBonusServiceProtocol?,
        state: CrowdloanSharedState
    ) -> CrowdloanContributionConfirmViewProtocol? {
        guard
            let chain = state.settings.value,
            let asset = chain.utilityAssets().first,
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: paraId,
                chain: chain,
                asset: asset,
                bonusService: bonusService,
                state: state
            ) else {
            return nil
        }

        let wireframe = CrowdloanContributionConfirmWireframe()

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

        let presenter = CrowdloanContributionConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            contributionViewModelFactory: contributionViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            inputAmount: inputAmount,
            bonusRate: bonusService?.bonusRate,
            assetInfo: assetInfo,
            localizationManager: localizationManager,
            chain: chain,
            logger: Logger.shared
        )

        let view = CrowdloanContributionConfirmVC(
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
        bonusService: CrowdloanBonusServiceProtocol?,
        state: CrowdloanSharedState
    ) -> CrowdloanContributionConfirmInteractor? {
        guard let selectedMetaAccount = SelectedWalletSettings.shared.value,
              let currencyManager = CurrencyManager.shared else {
            return nil
        }

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

        let keystore = Keychain()

        let signingWrapper = SigningWrapperFactory(keystore: keystore).createSigningWrapper(
            for: selectedMetaAccount.metaId,
            accountResponse: accountResponse
        )

        return CrowdloanContributionConfirmInteractor(
            paraId: paraId,
            selectedMetaAccount: selectedMetaAccount,
            chain: chain,
            asset: asset,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            crowdloanLocalSubscriptionFactory: state.crowdloanLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            jsonLocalSubscriptionFactory: JsonDataProviderFactory.shared,
            signingWrapper: signingWrapper,
            bonusService: bonusService,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            currencyManager: currencyManager
        )
    }
}
