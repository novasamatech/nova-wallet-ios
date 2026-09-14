import CoreData
import Keystore_iOS
import Operation_iOS
import XCTest
@testable import novawallet

final class AssetVisibilitySeedMigratorTests: XCTestCase {
    private let workQueue = OperationQueue()

    func testMigratesOnlyLegacyDisabledAssetsForEveryExistingWallet() throws {
        // given

        let userStorage = UserDataStorageTestFacade()
        let substrateStorage = SubstrateStorageTestFacade()
        let wallets = (0 ..< 2).map { _ in
            AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        }
        let chains = ChainModelGenerator.generate(count: 2)
        let disabledChain = try XCTUnwrap(chains.first)
        let disabledAsset = try XCTUnwrap(disabledChain.assets.first)
        let disabledAssetId = ChainAssetId(
            chainId: disabledChain.chainId,
            assetId: disabledAsset.assetId
        )

        try save(wallets: wallets, to: userStorage)
        try save(chains: chains, to: substrateStorage)
        try disable(assetId: disabledAssetId, in: substrateStorage)

        let settings = InMemorySettingsManager()
        settings.set(
            value: false,
            for: AssetVisibilitySeedMigrator.Constants.legacyHidesZeroBalancesKey
        )

        let migrator = AssetVisibilitySeedMigrator(
            settingsManager: settings,
            substrateStorageFacade: substrateStorage,
            userStorageFacade: userStorage,
            workQueue: workQueue
        )

        // when

        try migrator.migrate()

        // then

        let rows = try fetchVisibilityRows(from: userStorage)

        XCTAssertEqual(rows.count, wallets.count)
        XCTAssertEqual(Set(rows.map(\.metaId)), Set(wallets.map(\.metaId)))
        XCTAssertEqual(Set(rows.map(\.chainAssetId)), [disabledAssetId])
        XCTAssertTrue(rows.allSatisfy { $0.state == .hidden })
        XCTAssertTrue(settings.assetVisibilitySeeded)
        XCTAssertNil(
            settings.bool(for: AssetVisibilitySeedMigrator.Constants.legacyHidesZeroBalancesKey)
        )
    }
}

private extension AssetVisibilitySeedMigratorTests {
    func save(wallets: [MetaAccountModel], to storage: StorageFacadeProtocol) throws {
        let repository = AccountRepositoryFactory(storageFacade: storage)
            .createManagedMetaAccountRepository(for: nil, sortDescriptors: [])
        let managedWallets = wallets.enumerated().map { index, wallet in
            ManagedMetaAccountModel(
                info: wallet,
                isSelected: index == 0,
                order: UInt32(index)
            )
        }
        let operation = repository.saveOperation({ managedWallets }, { [] })

        workQueue.addOperations([operation], waitUntilFinished: true)
        try operation.extractNoCancellableResultData()
    }

    func save(chains: [ChainModel], to storage: StorageFacadeProtocol) throws {
        let repository = SubstrateRepositoryFactory(storageFacade: storage).createChainRepository()
        let operation = repository.saveOperation({ chains }, { [] })

        workQueue.addOperations([operation], waitUntilFinished: true)
        try operation.extractNoCancellableResultData()
    }

    func disable(assetId: ChainAssetId, in storage: SubstrateStorageTestFacade) throws {
        let completion = expectation(description: "Disable legacy asset")
        var result: Result<Void, Error>?

        storage.databaseService.performAsync { context, error in
            defer { completion.fulfill() }

            do {
                if let error {
                    throw error
                }

                let context = try XCTUnwrap(context)
                let request = NSFetchRequest<CDAsset>(entityName: "CDAsset")
                let assets = try context.fetch(request)
                let asset = try XCTUnwrap(
                    assets.first {
                        $0.chain?.chainId == assetId.chainId &&
                            UInt32(bitPattern: $0.assetId) == assetId.assetId
                    }
                )

                asset.enabled = false
                try context.save()
                result = .success(())
            } catch {
                result = .failure(error)
            }
        }

        wait(for: [completion], timeout: Constants.defaultExpectationDuration)
        try XCTUnwrap(result).get()
    }

    func fetchVisibilityRows(from storage: StorageFacadeProtocol) throws -> [AssetVisibilityLocal] {
        let repository = AssetVisibilityRepositoryFactory.createVisibilityRepository(using: storage)
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        workQueue.addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }
}
