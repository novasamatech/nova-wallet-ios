import Foundation
import CommonWallet
import SoraKeystore
import RobinHood
import IrohaCrypto
import SoraFoundation
import FearlessUtils

enum WalletContextFactoryError: Error {
    case missingAccount
}

protocol WalletContextFactoryProtocol {
    func createContext() throws -> CommonWalletContextProtocol
}

final class WalletContextFactory {
    let chainRepository: AnyDataProviderRepository<ChainModel>
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.chainRepository = chainRepository
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func allChains() throws -> [ChainModel] {
        let operation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([operation], waitUntilFinished: true)
        return try operation.extractNoCancellableResultData()
    }
}

extension WalletContextFactory: WalletContextFactoryProtocol {
    // swiftlint:disable function_body_length
    func createContext() throws -> CommonWalletContextProtocol {
        guard let metaAccount = SelectedWalletSettings.shared.value else {
            throw WalletContextFactoryError.missingAccount
        }

        logger.info("Start wallet for: \(metaAccount.metaId)")

        if let ethereumAddress = metaAccount.ethereumAddress {
            logger.info("Ethereum address: \(ethereumAddress.toHex(includePrefix: true))")
        }

        let chains = try allChains()
        let chainAssets: [ChainAsset] = chains.compactMap { chain in
            guard
                metaAccount.fetch(for: chain.accountRequest()) != nil,
                let asset = chain.utilityAssets().first else {
                return nil
            }

            return ChainAsset(chain: chain, asset: asset)
        }

        let priceAssetInfo = AssetBalanceDisplayInfo.usd()
        let priceAsset = WalletAsset(
            identifier: WalletAssetId.usd.rawValue,
            name: LocalizableResource { _ in "" },
            platform: LocalizableResource { _ in "" },
            symbol: "$",
            precision: priceAssetInfo.assetPrecision,
            modes: .view
        )

        let walletAssets: [WalletAsset] = chainAssets.compactMap { chainAsset in
            // TODO: Remove when runtime fixed
            guard ![Chain.polkadot.genesisHash, Chain.westend.genesisHash, Chain.kusama.genesisHash].contains(
                chainAsset.chain.identifier
            ) else {
                return nil
            }

            return WalletAsset(
                identifier: chainAsset.chainAssetId.walletId,
                name: LocalizableResource { _ in chainAsset.asset.name ?? chainAsset.chain.name },
                platform: LocalizableResource { _ in chainAsset.chain.name },
                symbol: chainAsset.asset.symbol,
                precision: chainAsset.assetDisplayInfo.assetPrecision,
                modes: WalletAssetModes.all
            )
        }

        let accountSettings = WalletAccountSettings(
            accountId: metaAccount.metaId,
            assets: [priceAsset] + walletAssets
        )

        let chainsById: [ChainModel.Id: ChainModel] = chains.reduce(into: [:]) { result, chain in
            result[chain.chainId] = chain
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let substrateFacade = SubstrateDataStorageFacade.shared
        let userFacade = UserDataStorageFacade.shared

        let operationManager = OperationManagerFacade.sharedManager

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let chainStorage = SubstrateRepositoryFactory(storageFacade: substrateFacade)
            .createChainStorageItemRepository()

        let nodeOperationFactory = WalletNetworkOperationFactory(
            metaAccount: metaAccount,
            chains: chainsById,
            accountSettings: accountSettings,
            chainRegistry: chainRegistry,
            requestFactory: requestFactory,
            chainStorage: chainStorage,
            keystore: Keychain()
        )

        let subscanOperationFactory = SubscanOperationFactory()
        let coingeckoOperationFactory = CoingeckoOperationFactory()

        let localStorageRequestFactory = LocalStorageRequestFactory()

        let accountsRepository = AccountRepositoryFactory(storageFacade: userFacade).createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: [NSSortDescriptor.accountsByOrder]
        )

        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        let contactOperationFactory = WalletContactOperationFactory(
            storageFacade: substrateFacade,
            targetAddress: ""
        )

        let networkFacade = WalletNetworkFacade(
            accountSettings: accountSettings,
            metaAccount: metaAccount,
            chains: chainsById,
            chainRegistry: chainRegistry,
            storageFacade: substrateFacade,
            nodeOperationFactory: nodeOperationFactory,
            subscanOperationFactory: subscanOperationFactory,
            coingeckoOperationFactory: coingeckoOperationFactory,
            totalPriceId: priceAsset.identifier,
            totalPriceAssetInfo: priceAssetInfo,
            chainStorage: chainStorage,
            localStorageRequestFactory: localStorageRequestFactory,
            txStorage: AnyDataProviderRepository(txStorage),
            contactsOperationFactory: contactOperationFactory,
            accountsRepository: accountsRepository
        )

        let builder = CommonWalletBuilder.builder(
            with: accountSettings,
            networkOperationFactory: networkFacade
        )

        let localizationManager = LocalizationManager.shared

        WalletCommonConfigurator(
            localizationManager: localizationManager,
            metaAccount: metaAccount,
            assets: walletAssets
        ).configure(builder: builder)

        WalletCommonStyleConfigurator().configure(builder: builder.styleBuilder)

        let purchaseProvider = PurchaseAggregator.defaultAggregator()
        let accountListConfigurator = WalletAccountListConfigurator(
            metaAccount: metaAccount,
            chains: chainsById,
            priceAsset: priceAsset,
            logger: logger
        )

        accountListConfigurator.configure(builder: builder.accountListModuleBuilder)

        let assetDetailsConfigurator = AssetDetailsConfigurator(
            metaAccount: metaAccount,
            chains: chainsById,
            purchaseProvider: purchaseProvider,
            priceAsset: priceAsset
        )

        assetDetailsConfigurator.configure(builder: builder.accountDetailsModuleBuilder)

        let amountFormatterFactory = AmountFormatterFactory()
        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()

        TransactionHistoryConfigurator(
            amountFormatterFactory: amountFormatterFactory,
            assets: accountSettings.assets
        ).configure(builder: builder.historyModuleBuilder)

        let contactsConfigurator = ContactsConfigurator(metaAccount: metaAccount, chains: chainsById)
        contactsConfigurator.configure(builder: builder.contactsModuleBuilder)

        let transferConfigurator = TransferConfigurator(
            assets: accountSettings.assets,
            amountFormatterFactory: amountFormatterFactory,
            localizationManager: localizationManager
        )

        transferConfigurator.configure(builder: builder.transferModuleBuilder)

        let confirmConfigurator = TransferConfirmConfigurator(
            chains: chainsById,
            amountFormatterFactory: assetBalanceFormatterFactory
        )

        confirmConfigurator.configure(builder: builder.transferConfirmationBuilder)

        let context = try builder.build()

        transferConfigurator.commandFactory = context
        confirmConfigurator.commandFactory = context

        return context
    }
    // swiftlint:enable function_body_length
}
