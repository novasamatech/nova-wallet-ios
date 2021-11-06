import Foundation
import SoraKeystore
import SoraFoundation

struct AcalaContributionSetupViewFactory {
    static func createView(
        for paraId: ParaId,
        state: CrowdloanSharedState
    ) -> CrowdloanContributionSetupViewProtocol? {
        guard
            let chain = state.settings.value,
            let asset = chain.utilityAssets().first,
            let selectedAccount = SelectedWalletSettings.shared.value,
            let accountResponse = selectedAccount.fetch(for: chain.accountRequest()),
            let selectedAddress = try? accountResponse.accountId.toAddress(
                using: chain.chainFormat
            ),
            let interactor = createInteractor(
                for: paraId,
                chain: chain,
                asset: asset,
                state: state,
                selectedMetaAccount: selectedAccount,
                accountResponse: accountResponse
            )
        else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let accountAddressDependingOnChain: String? = {
            switch chain.chainId {
            case Chain.rococo.genesisHash:
                // requires polkadot address even in rococo testnet
                return try? accountResponse.accountId.toAddress(
                    using: ChainFormat.substrate(UInt16(SNAddressType.polkadotMain.rawValue))
                )
            default:
                return selectedAddress
            }
        }()
        guard let address = accountAddressDependingOnChain else { return nil }

        let signingWrapper = SigningWrapper(
            keystore: Keychain(),
            metaId: selectedAccount.metaId,
            accountResponse: accountResponse
        )

        let acalaService = AcalaBonusService(
            address: address,
            signingWrapper: signingWrapper,
            operationManager: operationManager
        )
        let wireframe = AcalaContributionSetupWireframe(state: state, acalaService: acalaService)

        let assetInfo = asset.displayInfo(with: chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let localizationManager = LocalizationManager.shared

        let contributionViewModelFactory = CrowdloanContributionViewModelFactory(
            assetInfo: assetInfo,
            chainDateCalculator: ChainDateCalculator()
        )

        let dataValidatingFactory = CrowdloanDataValidatingFactory(
            presentable: wireframe,
            assetInfo: assetInfo
        )

        let presenter = AcalaContributionSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            contributionViewModelFactory: contributionViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo,
            localizationManager: localizationManager,
            bonusService: acalaService,
            explorers: chain.explorers,
            logger: Logger.shared
        )

        let view = AcalaContributionSetupViewController(
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
        state: CrowdloanSharedState,
        selectedMetaAccount: MetaAccountModel,
        accountResponse: ChainAccountResponse
    ) -> CrowdloanContributionSetupInteractor? {
        let operationManager = OperationManagerFacade.sharedManager
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
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

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

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
            operationManager: operationManager
        )
    }
}
