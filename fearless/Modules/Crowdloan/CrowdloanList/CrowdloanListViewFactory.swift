import Foundation
import SoraFoundation
import SubstrateSdk
import SoraKeystore
import IrohaCrypto
import RobinHood

struct CrowdloanListViewFactory {
    static func createView(with sharedState: CrowdloanSharedState) -> CrowdloanListViewProtocol? {
        guard let interactor = createInteractor(from: sharedState) else {
            return nil
        }

        let wireframe = CrowdloanListWireframe(state: sharedState)

        let localizationManager = LocalizationManager.shared

        let viewModelFactory = CrowdloansViewModelFactory(
            amountFormatterFactory: AssetBalanceFormatterFactory()
        )

        let presenter = CrowdloanListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = CrowdloanListViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        from state: CrowdloanSharedState
    ) -> CrowdloanListInteractor? {
        let selectedMetaAccount: MetaAccountModel = SelectedWalletSettings.shared.value

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let repository = SubstrateRepositoryFactory().createChainStorageItemRepository()

        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared

        let crowdloanRemoteSubscriptionService = CrowdloanRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: AnyDataProviderRepository(repository),
            operationManager: operationManager,
            logger: logger
        )

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let crowdloanOperationFactory = CrowdloanOperationFactory(
            requestOperationFactory: storageRequestFactory,
            operationManager: operationManager
        )

        let chain = state.settings.value!
        guard
            let selectedAccount = SelectedWalletSettings.shared.value,
            let accountResponse = selectedAccount.fetch(for: chain.accountRequest()),
            let selectedAddress = try? accountResponse.accountId.toAddress(
                using: chain.chainFormat
            ) else { return nil }

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
        let parallelSource = ParallelContributionSource()

        return CrowdloanListInteractor(
            selectedMetaAccount: selectedMetaAccount,
            settings: state.settings,
            chainRegistry: chainRegistry,
            crowdloanOperationFactory: crowdloanOperationFactory,
            crowdloanRemoteSubscriptionService: crowdloanRemoteSubscriptionService,
            crowdloanLocalSubscriptionFactory: state.crowdloanLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            jsonDataProviderFactory: JsonDataProviderFactory.shared,
            operationManager: operationManager,
            customContrubutionSources: [acalaService, parallelSource],
            logger: logger
        )
    }
}
