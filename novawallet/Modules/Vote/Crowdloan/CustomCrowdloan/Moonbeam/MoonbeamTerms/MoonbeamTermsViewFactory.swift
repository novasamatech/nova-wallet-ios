import Foundation
import Foundation_iOS
import Keystore_iOS

struct MoonbeamTermsViewFactory {
    static func createView(
        state: CrowdloanSharedState,
        paraId: ParaId,
        service: MoonbeamBonusServiceProtocol
    ) -> MoonbeamTermsViewProtocol? {
        guard
            let chain = state.settings.value,
            let asset = chain.utilityAssets().first,
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                paraId: paraId,
                chain: chain,
                asset: asset,
                moonbeamService: service
            ) else {
            return nil
        }

        let wireframe = MoonbeamTermsWireframe()

        let assetInfo = asset.displayInfo(with: chain.icon)
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        let dataValidatingFactory = CrowdloanDataValidatingFactory(presentable: wireframe, assetInfo: assetInfo)

        let presenter = MoonbeamTermsPresenter(
            paraId: paraId,
            moonbeamService: service,
            state: state,
            assetInfo: assetInfo,
            balanceViewModelFactory: balanceViewModelFactory,
            interactor: interactor,
            wireframe: wireframe,
            dataValidatingFactory: dataValidatingFactory,
            logger: Logger.shared
        )

        let view = MoonbeamTermsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        paraId: ParaId,
        chain: ChainModel,
        asset: AssetModel,
        moonbeamService: MoonbeamBonusServiceProtocol
    ) -> MoonbeamTermsInteractor? {
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

        let priceLocalSubscriptionFactory = PriceProviderFactory.shared

        let signingWrapper = SigningWrapperFactory().createSigningWrapper(
            for: selectedMetaAccount.metaId,
            accountResponse: accountResponse
        )

        return MoonbeamTermsInteractor(
            accountId: accountResponse.accountId,
            paraId: paraId,
            chainId: chain.chainId,
            asset: asset,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            callFactory: SubstrateCallFactory(),
            moonbeamService: moonbeamService,
            operationManager: operationManager,
            signingWrapper: signingWrapper,
            chainConnection: connection,
            currencyManager: currencyManager,
            logger: Logger.shared
        )
    }
}
