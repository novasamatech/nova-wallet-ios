import XCTest
@testable import novawallet
import BigInt
import CoreData
import Keystore_iOS
import Operation_iOS

final class AssetVisibilitySeedMigratorTests: XCTestCase {
    func testHideZeroOffListIsIdentical() throws {
        // given
        let context = try TestContext.create(hidesZeroBalances: false)

        // when
        try context.migrator.migrate()

        waitForSeedQueue(in: context)

        let seededStates = try context.wallets.map { try context.fetchStates(for: $0.metaId) }

        try context.migrator.migrate()

        waitForSeedQueue(in: context)

        let repeatedStates = try context.wallets.map { try context.fetchStates(for: $0.metaId) }

        // then
        for states in seededStates {
            XCTAssertEqual(states.count, context.allChainAssetIds.count)

            for chainAssetId in context.allChainAssetIds {
                let expectedState: AssetVisibilityState = context.disabledIds.contains(chainAssetId) ? .hidden : .visible
                XCTAssertEqual(states[chainAssetId], expectedState)
            }
        }

        XCTAssertNil(
            context.settingsManager.bool(for: AssetVisibilitySeedMigrator.Constants.legacyHidesZeroBalancesKey)
        )
        XCTAssertTrue(context.settingsManager.assetVisibilitySeeded)
        XCTAssertEqual(repeatedStates, seededStates)
    }

    func testHideZeroOnListIsIdentical() throws {
        // given
        let context = try TestContext.create(hidesZeroBalances: true)
        let revealedId = ChainAssetId(chainId: context.chains[0].chainId, assetId: 1)

        // when
        try context.migrator.migrate()

        context.writer.showIfUndecided(metaId: context.wallets[0].metaId, ids: [revealedId])

        waitForSeedQueue(in: context)

        // then
        for wallet in context.wallets {
            let states = try context.fetchStates(for: wallet.metaId)
            let visibility = AssetVisibility(defaults: .empty, rows: states)
            let revealed = wallet.metaId == context.wallets[0].metaId ? revealedId : nil

            if let revealed {
                XCTAssertEqual(states[revealed], .visible)
            }

            for chainAssetId in context.allChainAssetIds where chainAssetId != revealed {
                let enabled = !context.disabledIds.contains(chainAssetId)
                let hasBalance = try context.totalBalance(of: chainAssetId, for: wallet) > 0

                XCTAssertEqual(states[chainAssetId], expectedState(enabled: enabled, hasBalance: hasBalance))
                XCTAssertEqual(visibility.isVisible(chainAssetId), enabled && hasBalance)
            }
        }
    }
}

// MARK: - Private

private extension AssetVisibilitySeedMigratorTests {
    struct TestContext {
        let settingsManager: InMemorySettingsManager
        let substrateStorageFacade: SubstrateStorageTestFacade
        let userStorageFacade: UserDataStorageTestFacade
        let operationQueue: OperationQueue
        let migrator: AssetVisibilitySeedMigrator
        let writer: AssetVisibilityWriter
        let wallets: [MetaAccountModel]
        let chains: [ChainModel]
        let disabledIds: Set<ChainAssetId>
        let balances: [AssetBalance]

        var allChainAssetIds: [ChainAssetId] {
            chains.flatMap { chain in
                chain.assets.map { ChainAssetId(chainId: chain.chainId, assetId: $0.assetId) }
            }
        }

        static func create(hidesZeroBalances: Bool) throws -> TestContext {
            let settingsManager = InMemorySettingsManager()
            let substrateStorageFacade = SubstrateStorageTestFacade()
            let userStorageFacade = UserDataStorageTestFacade()
            let operationQueue = OperationQueue()
            let seedQueue = OperationQueue()
            seedQueue.maxConcurrentOperationCount = 1

            settingsManager.set(
                value: hidesZeroBalances,
                for: AssetVisibilitySeedMigrator.Constants.legacyHidesZeroBalancesKey
            )

            let chains = createChains()
            let wallets = [
                AccountGenerator.generateMetaAccount(generatingChainAccounts: 0),
                AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
            ]
            let disabledIds: Set<ChainAssetId> = [
                ChainAssetId(chainId: chains[0].chainId, assetId: 2),
                ChainAssetId(chainId: chains[1].chainId, assetId: 1)
            ]
            let balances = try createBalances(for: wallets, chains: chains)

            try store(chains, to: SubstrateRepositoryFactory(storageFacade: substrateStorageFacade).createChainRepository(), using: operationQueue)
            try disable(assets: disabledIds, in: substrateStorageFacade)
            try store(
                wallets.enumerated().map { ManagedMetaAccountModel(info: $1, isSelected: $0 == 0, order: UInt32($0)) },
                to: AccountRepositoryFactory(storageFacade: userStorageFacade).createManagedMetaAccountRepository(
                    for: nil,
                    sortDescriptors: []
                ),
                using: operationQueue
            )
            try store(
                balances,
                to: SubstrateRepositoryFactory(storageFacade: substrateStorageFacade).createAssetBalanceRepository(),
                using: operationQueue
            )

            let migrator = AssetVisibilitySeedMigrator(
                settingsManager: settingsManager,
                substrateStorageFacade: substrateStorageFacade,
                userStorageFacade: userStorageFacade,
                seedQueue: seedQueue,
                workQueue: operationQueue,
                logger: Logger.shared
            )

            let writer = AssetVisibilityWriter(
                storageFacade: userStorageFacade,
                writeQueue: seedQueue,
                workQueue: operationQueue,
                logger: Logger.shared
            )

            return TestContext(
                settingsManager: settingsManager,
                substrateStorageFacade: substrateStorageFacade,
                userStorageFacade: userStorageFacade,
                operationQueue: operationQueue,
                migrator: migrator,
                writer: writer,
                wallets: wallets,
                chains: chains,
                disabledIds: disabledIds,
                balances: balances
            )
        }

        func fetchStates(for metaId: MetaAccountModel.Id) throws -> [ChainAssetId: AssetVisibilityState] {
            let repository = AssetVisibilityRepositoryFactory.createVisibilityRepository(
                for: metaId,
                using: userStorageFacade
            )

            let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
            operationQueue.addOperations([fetchOperation], waitUntilFinished: true)

            return try fetchOperation.extractNoCancellableResultData().reduce(into: [:]) {
                $0[$1.chainAssetId] = $1.state
            }
        }

        func totalBalance(of chainAssetId: ChainAssetId, for wallet: MetaAccountModel) throws -> BigUInt {
            let chain = try XCTUnwrap(chains.first { $0.chainId == chainAssetId.chainId })
            let accountId = try XCTUnwrap(wallet.fetch(for: chain.accountRequest())?.accountId)
            let identifier = AssetBalance.createIdentifier(for: chainAssetId, accountId: accountId)

            return balances.first { $0.identifier == identifier }?.totalInPlank ?? 0
        }

        private static func createChains() -> [ChainModel] {
            [
                ChainModelGenerator.generateChain(
                    assets: (0 ..< 3).map { ChainModelGenerator.generateAssetWithId($0) },
                    addressPrefix: 0
                ),
                ChainModelGenerator.generateChain(
                    assets: (0 ..< 2).map { ChainModelGenerator.generateAssetWithId($0) },
                    addressPrefix: 2
                )
            ]
        }

        private static func createBalances(for wallets: [MetaAccountModel], chains: [ChainModel]) throws -> [AssetBalance] {
            [
                try createBalance(assetId: 0, of: chains[0], for: wallets[0], free: 100),
                try createBalance(assetId: 1, of: chains[0], for: wallets[0], free: 0),
                try createBalance(assetId: 2, of: chains[0], for: wallets[0], free: 100),
                try createBalance(assetId: 0, of: chains[1], for: wallets[1], free: 100)
            ]
        }

        private static func createBalance(
            assetId: AssetModel.Id,
            of chain: ChainModel,
            for wallet: MetaAccountModel,
            free: BigUInt
        ) throws -> AssetBalance {
            AssetBalance(
                chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: assetId),
                accountId: try XCTUnwrap(wallet.fetch(for: chain.accountRequest())?.accountId),
                freeInPlank: free,
                reservedInPlank: 0,
                frozenInPlank: 0,
                edCountMode: .basedOnFree,
                transferrableMode: .regular,
                blocked: false
            )
        }

        private static func store<T: Identifiable>(
            _ models: [T],
            to repository: AnyDataProviderRepository<T>,
            using queue: OperationQueue
        ) throws {
            let saveOperation = repository.saveOperation({ models }, { [] })
            queue.addOperations([saveOperation], waitUntilFinished: true)
            try saveOperation.extractNoCancellableResultData()
        }

        private static func disable(assets: Set<ChainAssetId>, in storageFacade: StorageFacadeProtocol) throws {
            let semaphore = DispatchSemaphore(value: 0)
            var disableError: Error?

            storageFacade.databaseService.performAsync { context, error in
                defer {
                    semaphore.signal()
                }

                do {
                    guard let context else {
                        throw error ?? CommonError.undefined
                    }

                    for chainAssetId in assets {
                        let request: NSFetchRequest<CDAsset> = CDAsset.fetchRequest()
                        request.predicate = NSPredicate(
                            format: "%K == %@ AND %K == %d",
                            #keyPath(CDAsset.chain.chainId), chainAssetId.chainId,
                            #keyPath(CDAsset.assetId), Int32(bitPattern: chainAssetId.assetId)
                        )

                        try context.fetch(request).forEach { $0.enabled = false }
                    }

                    try context.save()
                } catch {
                    disableError = error
                }
            }

            semaphore.wait()

            if let disableError {
                throw disableError
            }
        }
    }

    func waitForSeedQueue(in context: TestContext) {
        let expectation = XCTestExpectation()

        context.writer.enqueueBarrier(callbackIn: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func expectedState(enabled: Bool, hasBalance: Bool) -> AssetVisibilityState {
        guard enabled else {
            return .hidden
        }

        return hasBalance ? .visible : .hiddenUntilBalance
    }
}
