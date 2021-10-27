import Foundation
import SoraFoundation
import SoraKeystore

struct MoonbeamTermsViewFactory {
    static func createView(
        state: CrowdloanSharedState,
        paraId: ParaId,
        service: MoonbeamBonusServiceProtocol
    ) -> MoonbeamTermsViewProtocol? {
        guard
            let chain = state.settings.value,
            let asset = chain.utilityAssets().first,
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
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)
        let presenter = MoonbeamTermsPresenter(
            paraId: paraId,
            moonbeamService: service,
            state: state,
            assetInfo: assetInfo,
            balanceViewModelFactory: balanceViewModelFactory,
            interactor: interactor,
            wireframe: wireframe,
            logger: Logger.shared
        )

        let view = MoonbeamTermsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        paraId: ParaId,
        chain: ChainModel,
        asset: AssetModel,
        moonbeamService: MoonbeamBonusServiceProtocol
    ) -> MoonbeamTermsInteractor? {
        guard let selectedMetaAccount = SelectedWalletSettings.shared.value else {
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

        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )
        let feeProxy = ExtrinsicFeeProxy()

        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let signingWrapper = SigningWrapper(
            keystore: Keychain(),
            metaId: selectedMetaAccount.metaId,
            accountResponse: accountResponse
        )

        return MoonbeamTermsInteractor(
            paraId: paraId,
            chainId: chain.chainId,
            asset: asset,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            callFactory: SubstrateCallFactory(),
            moonbeamService: moonbeamService,
            operationManager: operationManager,
            signingWrapper: signingWrapper,
            chainConnection: connection,
            logger: Logger.shared
        )
    }
}
