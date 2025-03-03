import Foundation
import Operation_iOS

protocol SubstrateRepositoryFactoryProtocol {
    func createChainStorageItemRepository() -> AnyDataProviderRepository<ChainStorageItem>
    func createChainStorageItemRepository(filter: NSPredicate) -> AnyDataProviderRepository<ChainStorageItem>

    func createAssetBalanceRepository() -> AnyDataProviderRepository<AssetBalance>
    func createAssetBalanceRepository(for chainAssetIds: Set<ChainAssetId>) -> AnyDataProviderRepository<AssetBalance>

    func createStashItemRepository(
        for address: AccountAddress,
        chainId: ChainModel.Id
    ) -> AnyDataProviderRepository<StashItem>

    func createSingleValueRepository() -> AnyDataProviderRepository<SingleValueProviderObject>
    func createChainRepository() -> AnyDataProviderRepository<ChainModel>

    func createTxRepository() -> AnyDataProviderRepository<TransactionHistoryItem>
    func createPhishingRepository() -> AnyDataProviderRepository<PhishingItem>

    func createAssetStorageLocksRepository(
        for accountId: AccountId,
        chainAssetId: ChainAssetId
    ) -> AnyDataProviderRepository<AssetLock>

    func createAssetStorageFreezesRepository(
        for accountId: AccountId,
        chainAssetId: ChainAssetId
    ) -> AnyDataProviderRepository<AssetLock>

    func createAssetLocksRepository(
        for accountId: AccountId,
        chainAssetId: ChainAssetId
    ) -> AnyDataProviderRepository<AssetLock>

    func createAssetLocksRepository(chainAssetIds: Set<ChainAssetId>) -> AnyDataProviderRepository<AssetLock>

    func createAssetHoldsRepository(
        for accountId: AccountId,
        chainAssetId: ChainAssetId
    ) -> AnyDataProviderRepository<AssetHold>

    func createChainAddressTxRepository(
        for address: AccountAddress,
        chainId: ChainModel.Id
    ) -> AnyDataProviderRepository<TransactionHistoryItem>

    func createCustomAssetTxRepository(
        for address: AccountAddress,
        chainId: ChainModel.Id,
        assetId: UInt32,
        source: TransactionHistoryItemSource?
    ) -> AnyDataProviderRepository<TransactionHistoryItem>

    func createUtilityAssetTxRepository(
        for address: AccountAddress,
        chainId: ChainModel.Id,
        assetId: UInt32,
        source: TransactionHistoryItemSource?
    ) -> AnyDataProviderRepository<TransactionHistoryItem>

    func createPhishingSitesRepository() -> AnyDataProviderRepository<PhishingSite>

    func createPhishingSitesRepositoryWithPredicate(
        _ filter: NSPredicate
    ) -> AnyDataProviderRepository<PhishingSite>

    func createCrowdloanContributionRepository(
        accountId: AccountId,
        chainId: ChainModel.Id,
        source: String?
    ) -> AnyDataProviderRepository<CrowdloanContributionData>

    func createCrowdloanContributionRepository(
        accountId: AccountId,
        chainId: ChainModel.Id
    ) -> AnyDataProviderRepository<CrowdloanContributionData>

    func createCrowdloanContributionRepository(
        chainIds: Set<ChainModel.Id>
    ) -> AnyDataProviderRepository<CrowdloanContributionData>
}

final class SubstrateRepositoryFactory: SubstrateRepositoryFactoryProtocol {
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared) {
        self.storageFacade = storageFacade
    }

    func createChainStorageItemRepository() -> AnyDataProviderRepository<ChainStorageItem> {
        let repository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository()

        return AnyDataProviderRepository(repository)
    }

    func createChainStorageItemRepository(
        filter: NSPredicate
    ) -> AnyDataProviderRepository<ChainStorageItem> {
        let repository: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            storageFacade.createRepository(filter: filter)

        return AnyDataProviderRepository(repository)
    }

    func createSingleValueRepository() -> AnyDataProviderRepository<SingleValueProviderObject> {
        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            storageFacade.createRepository()

        return AnyDataProviderRepository(repository)
    }

    func createChainRepository() -> AnyDataProviderRepository<ChainModel> {
        let repository: CoreDataRepository<ChainModel, CDChain> =
            storageFacade.createRepository(
                filter: nil,
                sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix],
                mapper: AnyCoreDataMapper(ChainModelMapper())
            )

        return AnyDataProviderRepository(repository)
    }

    func createTxRepository() -> AnyDataProviderRepository<TransactionHistoryItem> {
        let repository: CoreDataRepository<TransactionHistoryItem, CDTransactionItem> =
            storageFacade.createRepository()
        return AnyDataProviderRepository(repository)
    }

    func createPhishingRepository() -> AnyDataProviderRepository<PhishingItem> {
        let repository: CoreDataRepository<PhishingItem, CDPhishingItem> =
            storageFacade.createRepository()
        return AnyDataProviderRepository(repository)
    }

    func createCustomAssetTxRepository(
        for address: AccountAddress,
        chainId: ChainModel.Id,
        assetId: UInt32,
        source: TransactionHistoryItemSource?
    ) -> AnyDataProviderRepository<TransactionHistoryItem> {
        let txFilter = NSPredicate.filterTransactionsBy(
            address: address,
            chainId: chainId,
            assetId: assetId,
            source: source
        )

        return createTxRepository(for: txFilter)
    }

    func createChainAddressTxRepository(
        for address: AccountAddress,
        chainId: ChainModel.Id
    ) -> AnyDataProviderRepository<TransactionHistoryItem> {
        let txFilter = NSPredicate.filterTransactionsBy(
            address: address,
            chainId: chainId
        )

        return createTxRepository(for: txFilter)
    }

    func createUtilityAssetTxRepository(
        for address: AccountAddress,
        chainId: ChainModel.Id,
        assetId: UInt32,
        source: TransactionHistoryItemSource?
    ) -> AnyDataProviderRepository<TransactionHistoryItem> {
        let txFilter = NSPredicate.filterUtilityAssetTransactionsBy(
            address: address,
            chainId: chainId,
            utilityAssetId: assetId,
            source: source
        )

        return createTxRepository(for: txFilter)
    }

    func createAssetBalanceRepository() -> AnyDataProviderRepository<AssetBalance> {
        let mapper = AssetBalanceMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        return AnyDataProviderRepository(repository)
    }

    func createAssetBalanceRepository(
        for chainAssetIds: Set<ChainAssetId>
    ) -> AnyDataProviderRepository<AssetBalance> {
        let mapper = AssetBalanceMapper()
        let filter = NSPredicate.assetBalance(chainAssetIds: chainAssetIds)

        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }

    private func createTxRepository(
        for filter: NSPredicate
    ) -> AnyDataProviderRepository<TransactionHistoryItem> {
        let sortDescriptor = NSSortDescriptor(
            key: #keyPath(CDTransactionItem.timestamp),
            ascending: false
        )
        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionItem> =
            storageFacade.createRepository(filter: filter, sortDescriptors: [sortDescriptor])
        return AnyDataProviderRepository(txStorage)
    }

    func createPhishingSitesRepository() -> AnyDataProviderRepository<PhishingSite> {
        let mapper = PhishingSiteMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        return AnyDataProviderRepository(repository)
    }

    func createPhishingSitesRepositoryWithPredicate(
        _ filter: NSPredicate
    ) -> AnyDataProviderRepository<PhishingSite> {
        let mapper = PhishingSiteMapper()
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }

    func createAssetLocksRepository(
        for accountId: AccountId,
        chainAssetId: ChainAssetId
    ) -> AnyDataProviderRepository<AssetLock> {
        createAssetLocksRepository(.assetLock(for: accountId, chainAssetId: chainAssetId))
    }

    func createAssetStorageLocksRepository(
        for accountId: AccountId,
        chainAssetId: ChainAssetId
    ) -> AnyDataProviderRepository<AssetLock> {
        createAssetLocksRepository(
            .assetLock(
                for: accountId,
                chainAssetId: chainAssetId,
                storage: AssetLockStorage.locks.rawValue
            )
        )
    }

    func createAssetStorageFreezesRepository(
        for accountId: AccountId,
        chainAssetId: ChainAssetId
    ) -> AnyDataProviderRepository<AssetLock> {
        createAssetLocksRepository(
            .assetLock(
                for: accountId,
                chainAssetId: chainAssetId,
                storage: AssetLockStorage.freezes.rawValue
            )
        )
    }

    func createAssetLocksRepository(chainAssetIds: Set<ChainAssetId>) -> AnyDataProviderRepository<AssetLock> {
        createAssetLocksRepository(.assetLock(chainAssetIds: chainAssetIds))
    }

    func createAssetHoldsRepository(
        for accountId: AccountId,
        chainAssetId: ChainAssetId
    ) -> AnyDataProviderRepository<AssetHold> {
        createAssetHoldsRepository(.assetHold(for: accountId, chainAssetId: chainAssetId))
    }

    private func createAssetLocksRepository(_ filter: NSPredicate) -> AnyDataProviderRepository<AssetLock> {
        let mapper = AssetLockMapper()
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )
        return AnyDataProviderRepository(repository)
    }

    private func createAssetHoldsRepository(_ filter: NSPredicate) -> AnyDataProviderRepository<AssetHold> {
        let mapper = AssetHoldMapper()
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }

    func createCrowdloanContributionRepository(
        accountId: AccountId,
        chainId: ChainModel.Id,
        source: String?
    ) -> AnyDataProviderRepository<CrowdloanContributionData> {
        let filter = NSPredicate.crowdloanContribution(
            for: chainId,
            accountId: accountId,
            source: source
        )

        return createCrowdloanContributionRepository(for: filter)
    }

    func createCrowdloanContributionRepository(
        accountId: AccountId,
        chainId: ChainModel.Id
    ) -> AnyDataProviderRepository<CrowdloanContributionData> {
        let filter = NSPredicate.crowdloanContribution(
            for: chainId,
            accountId: accountId
        )

        return createCrowdloanContributionRepository(for: filter)
    }

    func createCrowdloanContributionRepository(
        chainIds: Set<ChainModel.Id>
    ) -> AnyDataProviderRepository<CrowdloanContributionData> {
        let filter = NSPredicate.crowdloanContribution(chainIds: chainIds)
        return createCrowdloanContributionRepository(for: filter)
    }

    private func createCrowdloanContributionRepository(
        for filter: NSPredicate
    ) -> AnyDataProviderRepository<CrowdloanContributionData> {
        let mapper = CrowdloanContributionDataMapper()
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )
        return AnyDataProviderRepository(repository)
    }

    func createStashItemRepository(
        for address: AccountAddress,
        chainId: ChainModel.Id
    ) -> AnyDataProviderRepository<StashItem> {
        let filter = NSPredicate.filterByStashOrController(address, chainId: chainId)

        let mapper = StashItemMapper()

        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }
}
