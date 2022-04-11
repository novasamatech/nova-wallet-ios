import Foundation
import CommonWallet
import SoraKeystore
import RobinHood
import IrohaCrypto
import SoraFoundation
import SubstrateSdk

enum WalletContextFactoryError: Error {
    case missingAccount
    case missingAsset
}

protocol WalletContextFactoryProtocol {
    func createContext(for chain: ChainModel, asset: AssetModel) throws -> CommonWalletContextProtocol
}

final class WalletContextFactory {
    let logger: LoggerProtocol

    init(
        logger: LoggerProtocol = Logger.shared
    ) {
        self.logger = logger
    }
}

extension WalletContextFactory: WalletContextFactoryProtocol {
    // swiftlint:disable function_body_length
    func createContext(for chain: ChainModel, asset: AssetModel) throws -> CommonWalletContextProtocol {
        guard let metaAccount = SelectedWalletSettings.shared.value,
              let chainAccountResponse = metaAccount.fetch(for: chain.accountRequest()) else {
            throw WalletContextFactoryError.missingAccount
        }

        let accountId = chainAccountResponse.accountId
        let address = try accountId.toAddress(using: chain.chainFormat)
        logger.info("Start wallet for: \(address)")

        if let ethereumAddress = metaAccount.ethereumAddress {
            logger.info("Ethereum address: \(ethereumAddress.toHex(includePrefix: true))")
        }

        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let priceAssetInfo = AssetBalanceDisplayInfo.usd()
        let priceAsset = WalletAsset(
            identifier: WalletAssetId.usd.rawValue,
            name: LocalizableResource { _ in "" },
            platform: LocalizableResource { _ in "" },
            symbol: "$",
            precision: priceAssetInfo.assetPrecision,
            modes: .view
        )

        let walletAsset = WalletAsset(
            identifier: chainAsset.chainAssetId.walletId,
            name: LocalizableResource { _ in chainAsset.asset.name ?? chainAsset.chain.name },
            platform: LocalizableResource { _ in chainAsset.chain.name },
            symbol: chainAsset.asset.symbol,
            precision: chainAsset.assetDisplayInfo.assetPrecision,
            modes: WalletAssetModes.all
        )

        let accountSettings = WalletAccountSettings(
            accountId: accountId.toHex(),
            assets: [priceAsset, walletAsset]
        )

        let chainsById: [ChainModel.Id: ChainModel] = [chain].reduce(into: [:]) { result, chain in
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

        let localStorageRequestFactory = LocalStorageRequestFactory()

        let nodeOperationFactory = WalletNetworkOperationFactory(
            metaAccount: metaAccount,
            chains: chainsById,
            accountSettings: accountSettings,
            chainRegistry: chainRegistry,
            requestFactory: requestFactory,
            chainStorage: chainStorage,
            localStorageRequestFactory: localStorageRequestFactory,
            keystore: Keychain()
        )

        let subscanOperationFactory = SubscanOperationFactory()
        let coingeckoOperationFactory = CoingeckoOperationFactory()

        let accountsRepository = AccountRepositoryFactory(storageFacade: userFacade).createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: [NSSortDescriptor.accountsByOrder]
        )

        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: substrateFacade)

        let contactOperationFactory = WalletContactOperationFactory(
            storageFacade: substrateFacade,
            targetAddress: address
        )

        let assetBalanceRepository = repositoryFactory.createAssetBalanceRepository()

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
            repositoryFactory: repositoryFactory,
            contactsOperationFactory: contactOperationFactory,
            accountsRepository: accountsRepository,
            assetBalanceRepository: assetBalanceRepository
        )

        let builder = CommonWalletBuilder.builder(
            with: accountSettings,
            networkOperationFactory: networkFacade
        )

        let localizationManager = LocalizationManager.shared

        WalletCommonConfigurator(
            chainAccount: chainAccountResponse,
            localizationManager: localizationManager,
            assets: [walletAsset]
        ).configure(builder: builder)

        WalletCommonStyleConfigurator().configure(builder: builder.styleBuilder)

        let purchaseProvider = PurchaseAggregator.defaultAggregator()

        let assetDetailsConfigurator = AssetDetailsConfigurator(
            accountId: accountId,
            chainAsset: chainAsset,
            purchaseProvider: purchaseProvider,
            priceAsset: priceAsset,
            localizationManager: localizationManager
        )

        assetDetailsConfigurator.configure(builder: builder.accountDetailsModuleBuilder)

        let amountFormatterFactory = AmountFormatterFactory()

        TransactionHistoryConfigurator(
            chainAsset: chainAsset,
            amountFormatterFactory: amountFormatterFactory,
            assets: accountSettings.assets
        ).configure(builder: builder.historyModuleBuilder)

        let receiveConfigurator = ReceiveConfigurator(
            accountId: accountId,
            chain: chain,
            assetInfo: asset.displayInfo(with: chain.icon),
            explorers: chain.explorers,
            localizationManager: localizationManager
        )

        receiveConfigurator.configure(builder: builder.receiveModuleBuilder)

        let context = try builder.build()

        receiveConfigurator.commandFactory = context

        assetDetailsConfigurator.bind(commandFactory: context)

        return context
    }
    // swiftlint:enable function_body_length
}
