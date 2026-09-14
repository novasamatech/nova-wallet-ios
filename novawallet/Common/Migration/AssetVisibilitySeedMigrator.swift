import Foundation
import CoreData
import Keystore_iOS
import Operation_iOS

final class AssetVisibilitySeedMigrator {
    enum Constants {
        static let legacyHidesZeroBalancesKey = "hidesZeroBalances"
    }

    private let settingsManager: SettingsManagerProtocol
    private let substrateStorageFacade: StorageFacadeProtocol
    private let userStorageFacade: StorageFacadeProtocol
    private let workQueue: OperationQueue

    init(
        settingsManager: SettingsManagerProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        userStorageFacade: StorageFacadeProtocol,
        workQueue: OperationQueue
    ) {
        self.settingsManager = settingsManager
        self.substrateStorageFacade = substrateStorageFacade
        self.userStorageFacade = userStorageFacade
        self.workQueue = workQueue
    }
}

// MARK: Migrating

extension AssetVisibilitySeedMigrator: Migrating {
    func migrate() throws {
        guard !settingsManager.assetVisibilitySeeded else {
            return
        }

        let disabledIds = try fetchDisabledAssetIds()
        let wallets = try fetchWallets()

        try saveVisibility(for: wallets, disabledIds: disabledIds)

        settingsManager.removeValue(for: Constants.legacyHidesZeroBalancesKey)
        settingsManager.assetVisibilitySeeded = true
    }
}

// MARK: Private

private extension AssetVisibilitySeedMigrator {
    struct DisabledAssetLocal: Identifiable {
        let identifier: String
        let chainAssetId: ChainAssetId?
    }

    final class DisabledAssetMapper: CoreDataMapperProtocol {
        typealias DataProviderModel = DisabledAssetLocal
        typealias CoreDataEntity = CDAsset

        var entityIdentifierFieldName: String { #keyPath(CDAsset.assetId) }

        func transform(entity: CoreDataEntity) throws -> DataProviderModel {
            let chainAssetId = entity.chain?.chainId.map {
                ChainAssetId(chainId: $0, assetId: UInt32(bitPattern: entity.assetId))
            }

            return DisabledAssetLocal(
                identifier: entity.objectID.uriRepresentation().absoluteString,
                chainAssetId: chainAssetId
            )
        }

        func populate(
            entity _: CoreDataEntity,
            from _: DataProviderModel,
            using _: NSManagedObjectContext
        ) throws {
            throw CommonError.undefined
        }
    }

    func fetchDisabledAssetIds() throws -> Set<ChainAssetId> {
        let repository: CoreDataRepository<DisabledAssetLocal, CDAsset> = substrateStorageFacade.createRepository(
            filter: NSPredicate(format: "%K == NO", #keyPath(CDAsset.enabled)),
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(DisabledAssetMapper())
        )

        let disabledAssets = try fetchAll(from: AnyDataProviderRepository(repository))

        return Set(disabledAssets.compactMap(\.chainAssetId))
    }

    func fetchWallets() throws -> [MetaAccountModel] {
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: userStorageFacade)
        return try fetchAll(
            from: accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])
        )
    }

    func saveVisibility(
        for wallets: [MetaAccountModel],
        disabledIds: Set<ChainAssetId>
    ) throws {
        guard !wallets.isEmpty, !disabledIds.isEmpty else {
            return
        }

        let rows = wallets.flatMap { wallet in
            disabledIds.map { chainAssetId in
                AssetVisibilityLocal(
                    metaId: wallet.metaId,
                    chainId: chainAssetId.chainId,
                    assetId: chainAssetId.assetId,
                    state: .hidden
                )
            }
        }

        let repository = AssetVisibilityRepositoryFactory.createVisibilityRepository(using: userStorageFacade)

        let saveOperation = repository.saveOperation({ rows }, { [] })

        workQueue.addOperations([saveOperation], waitUntilFinished: true)

        try saveOperation.extractNoCancellableResultData()
    }

    func fetchAll<T: Identifiable>(from repository: AnyDataProviderRepository<T>) throws -> [T] {
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        workQueue.addOperations([fetchOperation], waitUntilFinished: true)

        return try fetchOperation.extractNoCancellableResultData()
    }
}
