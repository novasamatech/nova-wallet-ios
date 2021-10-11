import Foundation
import CommonWallet
import IrohaCrypto
import RobinHood

final class WalletNetworkFacade {
    let accountSettings: WalletAccountSettings
    let metaAccount: MetaAccountModel
    let chains: [ChainModel.Id: ChainModel]
    let chainRegistry: ChainRegistryProtocol
    let storageFacade: StorageFacadeProtocol
    let nodeOperationFactory: WalletNetworkOperationFactoryProtocol
    let subscanOperationFactory: SubscanOperationFactoryProtocol
    let coingeckoOperationFactory: CoingeckoOperationFactoryProtocol
    let totalPriceId: String
    let totalPriceAssetInfo: AssetBalanceDisplayInfo
    let chainStorage: AnyDataProviderRepository<ChainStorageItem>
    let localStorageRequestFactory: LocalStorageRequestFactoryProtocol
    let txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    let contactsOperationFactory: WalletContactOperationFactoryProtocol
    let accountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>

    init(
        accountSettings: WalletAccountSettings,
        metaAccount: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel],
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        nodeOperationFactory: WalletNetworkOperationFactoryProtocol,
        subscanOperationFactory: SubscanOperationFactoryProtocol,
        coingeckoOperationFactory: CoingeckoOperationFactoryProtocol,
        totalPriceId: String,
        totalPriceAssetInfo: AssetBalanceDisplayInfo,
        chainStorage: AnyDataProviderRepository<ChainStorageItem>,
        localStorageRequestFactory: LocalStorageRequestFactoryProtocol,
        txStorage: AnyDataProviderRepository<TransactionHistoryItem>,
        contactsOperationFactory: WalletContactOperationFactoryProtocol,
        accountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    ) {
        self.accountSettings = accountSettings
        self.metaAccount = metaAccount
        self.chains = chains
        self.chainRegistry = chainRegistry
        self.storageFacade = storageFacade
        self.nodeOperationFactory = nodeOperationFactory
        self.subscanOperationFactory = subscanOperationFactory
        self.localStorageRequestFactory = localStorageRequestFactory
        self.coingeckoOperationFactory = coingeckoOperationFactory
        self.totalPriceId = totalPriceId
        self.totalPriceAssetInfo = totalPriceAssetInfo
        self.chainStorage = chainStorage
        self.txStorage = txStorage
        self.contactsOperationFactory = contactsOperationFactory
        self.accountsRepository = accountsRepository
    }
}
