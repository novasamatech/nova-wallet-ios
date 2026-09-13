import Foundation
import BigInt
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
    private let seedQueue: OperationQueue
    private let workQueue: OperationQueue
    private let logger: LoggerProtocol

    init(
        settingsManager: SettingsManagerProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        userStorageFacade: StorageFacadeProtocol,
        seedQueue: OperationQueue,
        workQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.settingsManager = settingsManager
        self.substrateStorageFacade = substrateStorageFacade
        self.userStorageFacade = userStorageFacade
        self.seedQueue = seedQueue
        self.workQueue = workQueue
        self.logger = logger
    }
}

// MARK: Migrating

extension AssetVisibilitySeedMigrator: Migrating {
    func migrate() throws {
        guard !settingsManager.assetVisibilitySeeded else {
            return
        }

        let input = SeedInput(
            hidesZeroBalances: settingsManager.bool(for: Constants.legacyHidesZeroBalancesKey) ?? false,
            disabledIds: try fetchDisabledAssetIds()
        )

        // The root module owning the migrator is released right after launch,
        // so the queued seed keeps the migrator alive until it completes.
        let seedOperation = ClosureOperation<Void> {
            try self.seed(with: input)
        }

        execute(
            operation: seedOperation,
            inOperationQueue: seedQueue,
            runningCallbackIn: nil
        ) { result in
            switch result {
            case .success:
                self.settingsManager.removeValue(for: Constants.legacyHidesZeroBalancesKey)
                self.settingsManager.assetVisibilitySeeded = true
            case let .failure(error):
                self.logger.error("Asset visibility seed failed: \(error)")
            }
        }
    }
}

// MARK: Private

private extension AssetVisibilitySeedMigrator {
    struct SeedInput {
        let hidesZeroBalances: Bool
        let disabledIds: Set<ChainAssetId>
    }

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

    func seed(with input: SeedInput) throws {
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: userStorageFacade)
        let wallets = try fetchAll(
            from: accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])
        )

        guard !wallets.isEmpty else {
            return
        }

        let substrateRepositoryFactory = SubstrateRepositoryFactory(storageFacade: substrateStorageFacade)
        let chains = try fetchAll(from: substrateRepositoryFactory.createChainRepository())
        let balances = try fetchAll(from: substrateRepositoryFactory.createAssetBalanceRepository())
            .reduce(into: [String: AssetBalance]()) { $0[$1.identifier] = $1 }

        for wallet in wallets {
            let rows = chains.flatMap { chain in
                createRows(for: wallet, chain: chain, balances: balances, input: input)
            }

            try save(rows: rows, for: wallet.metaId)
        }
    }

    func createRows(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        balances: [String: AssetBalance],
        input: SeedInput
    ) -> [AssetVisibilityLocal] {
        let accountId = wallet.fetch(for: chain.accountRequest())?.accountId

        return chain.assets.map { asset in
            let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)

            let balance = accountId.flatMap {
                balances[AssetBalance.createIdentifier(for: chainAssetId, accountId: $0)]?.totalInPlank
            }

            return AssetVisibilityLocal(
                metaId: wallet.metaId,
                chainId: chain.chainId,
                assetId: asset.assetId,
                state: resolveState(for: chainAssetId, balance: balance ?? 0, input: input)
            )
        }
    }

    func resolveState(
        for chainAssetId: ChainAssetId,
        balance: BigUInt,
        input: SeedInput
    ) -> AssetVisibilityState {
        if input.disabledIds.contains(chainAssetId) {
            return .hidden
        }

        guard input.hidesZeroBalances else {
            return .visible
        }

        return balance > 0 ? .visible : .hiddenUntilBalance
    }

    func save(rows: [AssetVisibilityLocal], for metaId: MetaAccountModel.Id) throws {
        let repository = AssetVisibilityRepositoryFactory.createVisibilityRepository(
            for: metaId,
            using: userStorageFacade
        )

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
