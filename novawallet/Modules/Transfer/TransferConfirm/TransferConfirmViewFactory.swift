import Foundation
import SoraFoundation
import SoraKeystore

// swiftlint:disable function_body_length
struct TransferConfirmViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        recepient: AccountAddress,
        amount: Decimal
    ) -> TransferConfirmViewProtocol? {
        let walletSettings = SelectedWalletSettings.shared

        guard
            let wallet = walletSettings.value,
            let selectedAccount = wallet.fetch(for: chainAsset.chain.accountRequest()),
            let senderAccountAddress = selectedAccount.toAddress(),
            let interactor = createInteractor(
                for: chainAsset,
                account: selectedAccount,
                accountMetaId: wallet.metaId
            ) else {
            return nil
        }

        let wireframe = TransferConfirmWireframe()

        let localizationManager = LocalizationManager.shared

        let networkViewModelFactory = NetworkViewModelFactory()
        let sendingBalanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo
        )

        let utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?

        if
            let utilityAsset = chainAsset.chain.utilityAssets().first,
            utilityAsset.assetId != chainAsset.asset.assetId {
            let utilityAssetInfo = utilityAsset.displayInfo(with: chainAsset.chain.icon)
            utilityBalanceViewModelFactory = BalanceViewModelFactory(
                targetAssetInfo: utilityAssetInfo
            )
        } else {
            utilityBalanceViewModelFactory = nil
        }

        let dataValidatingFactory = TransferDataValidatorFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            utilityAssetInfo: chainAsset.chain.utilityAssets().first?.displayInfo
        )

        let presenter = TransferConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            wallet: wallet,
            recepient: recepient,
            amount: amount,
            displayAddressViewModelFactory: DisplayAddressViewModelFactory(),
            chainAsset: chainAsset,
            networkViewModelFactory: networkViewModelFactory,
            sendingBalanceViewModelFactory: sendingBalanceViewModelFactory,
            utilityBalanceViewModelFactory: utilityBalanceViewModelFactory,
            senderAccountAddress: senderAccountAddress,
            dataValidatingFactory: dataValidatingFactory,
            localizationManager: localizationManager
        )

        let view = TransferConfirmViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        dataValidatingFactory.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for chainAsset: ChainAsset,
        account: ChainAccountResponse,
        accountMetaId: String
    ) -> TransferConfirmInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chain = chainAsset.chain
        let asset = chainAsset.asset

        guard
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let connection = chainRegistry.getConnection(for: chain.chainId) else {
            return nil
        }

        let repositoryFactory = SubstrateRepositoryFactory()
        let repository = repositoryFactory.createChainStorageItemRepository()

        let walletRemoteSubscriptionService = WalletRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: repository,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let walletRemoteSubscriptionWrapper = WalletRemoteSubscriptionWrapper(
            remoteSubscriptionService: walletRemoteSubscriptionService,
            chainRegistry: chainRegistry,
            repositoryFactory: repositoryFactory,
            eventCenter: EventCenter.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let extrinsicService = ExtrinsicService(
            accountId: account.accountId,
            chain: chain,
            cryptoType: account.cryptoType,
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager
        )

        let signingWrapper = SigningWrapper(
            keystore: Keychain(),
            metaId: accountMetaId,
            accountResponse: account
        )

        let transactionStorage = repositoryFactory.createTxRepository()
        let persistentExtrinsicService = PersistentExtrinsicService(
            repository: transactionStorage,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return TransferConfirmInteractor(
            selectedAccount: account,
            chain: chain,
            asset: asset,
            runtimeService: runtimeProvider,
            feeProxy: ExtrinsicFeeProxy(),
            extrinsicService: extrinsicService,
            signingWrapper: signingWrapper,
            persistExtrinsicService: persistentExtrinsicService,
            eventCenter: EventCenter.shared,
            walletRemoteWrapper: walletRemoteSubscriptionWrapper,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}

// swiftlint:enable function_body_length
