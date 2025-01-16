import Foundation
import Foundation_iOS
import Operation_iOS

struct StakingSetupProxyViewFactory {
    static func createView(state: RelaychainStakingSharedStateProtocol) -> StakingSetupProxyViewProtocol? {
        guard let wallet = SelectedWalletSettings.shared.value,
              let currencyManager = CurrencyManager.shared else {
            return nil
        }
        guard let interactor = createInteractor(state: state) else {
            return nil
        }
        let wireframe = StakingSetupProxyWireframe(state: state)
        let chainAsset = state.stakingOption.chainAsset

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        let dataValidatingFactory = ProxyDataValidatorFactory(
            presentable: wireframe,
            balanceViewModelFactoryFacade: BalanceViewModelFactoryFacade(
                priceAssetInfoFactory: priceAssetInfoFactory
            )
        )
        let presenter = StakingSetupProxyPresenter(
            wallet: wallet,
            chainAsset: chainAsset,
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            web3NameViewModelFactory: Web3NameViewModelFactory(
                displayAddressViewModelFactory: DisplayAddressViewModelFactory()
            ),
            localizationManager: LocalizationManager.shared
        )

        let view = StakingSetupProxyViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.baseView = view
        interactor.basePresenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        state: RelaychainStakingSharedStateProtocol
    ) -> StakingSetupProxyInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chainAsset = state.stakingOption.chainAsset
        guard
            let selectedAccount = SelectedWalletSettings.shared.value.fetch(
                for: chainAsset.chain.accountRequest()
            ),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeRegistry = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeRegistry,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount, chain: chainAsset.chain)

        let accountProviderFactory = AccountProviderFactory(
            storageFacade: UserDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let web3NamesService = Web3NameServiceFactory(operationQueue: operationQueue).createService()
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(
            for: nil,
            sortDescriptors: [NSSortDescriptor.accountsByOrder]
        )

        return StakingSetupProxyInteractor(
            web3NamesService: web3NamesService,
            accountRepository: accountRepository,
            runtimeService: runtimeRegistry,
            sharedState: state,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            accountProviderFactory: accountProviderFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            callFactory: SubstrateCallFactory(),
            feeProxy: ExtrinsicFeeProxy(),
            extrinsicService: extrinsicService,
            selectedAccount: selectedAccount,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }

    private static func createWeb3NameService() -> Web3NameServiceProtocol? {
        let kiltChainId = KnowChainId.kiltOnEnviroment
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard let kiltConnection = chainRegistry.getConnection(for: kiltChainId),
              let kiltRuntimeService = chainRegistry.getRuntimeProvider(for: kiltChainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let web3NamesOperationFactory = KiltWeb3NamesOperationFactory(operationQueue: operationQueue)

        let recipientRepositoryFactory = Web3TransferRecipientRepositoryFactory(
            integrityVerifierFactory: Web3TransferRecipientIntegrityVerifierFactory()
        )

        let slip44CoinsUrl = ApplicationConfig.shared.slip44URL
        let slip44CoinsProvider: AnySingleValueProvider<Slip44CoinList> = JsonDataProviderFactory.shared.getJson(
            for: slip44CoinsUrl
        )

        return Web3NameService(
            providerName: Web3NameProvider.kilt,
            slip44CoinsProvider: slip44CoinsProvider,
            web3NamesOperationFactory: web3NamesOperationFactory,
            runtimeService: kiltRuntimeService,
            connection: kiltConnection,
            transferRecipientRepositoryFactory: recipientRepositoryFactory,
            operationQueue: operationQueue
        )
    }
}
