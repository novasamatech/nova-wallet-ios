import XCTest
@testable import novawallet
import Operation_iOS

final class AssetVisibilityCleaningTests: XCTestCase {
    func testRemovedWalletRowsDeleted() throws {
        // given
        let context = TestContext.create()
        let removedWallet = createTestWallet()
        let keepWallet = createTestWallet(isSelected: true, order: 1)

        let chainAssetIds = [
            ChainAssetId(chainId: KnowChainId.polkadot, assetId: 0),
            ChainAssetId(chainId: KnowChainId.polkadot, assetId: 1)
        ]

        for wallet in [removedWallet, keepWallet] {
            try save(
                createRows(for: wallet, chainAssetIds: chainAssetIds),
                to: context.visibilityRepository,
                using: context.operationQueue
            )
            try save([createSettings(for: wallet)], to: context.settingsRepository, using: context.operationQueue)
        }

        let cleaner = RemovedWalletAssetVisibilityCleaner(storageFacade: context.facade)

        let providers = createProviders(
            changes: [.delete(deletedIdentifier: removedWallet.identifier)],
            walletsBeforeChanges: [
                removedWallet.identifier: removedWallet,
                keepWallet.identifier: keepWallet
            ]
        )

        // when
        try executeCleanerAndVerify(cleaner, providers: providers, using: context.operationQueue)

        // then
        let remainingRows = try fetchAll(from: context.visibilityRepository, using: context.operationQueue)
        let remainingSettings = try fetchAll(from: context.settingsRepository, using: context.operationQueue)

        XCTAssertEqual(remainingRows.count, chainAssetIds.count)
        XCTAssertTrue(remainingRows.allSatisfy { $0.metaId == keepWallet.info.metaId })
        XCTAssertEqual(remainingSettings.map(\.metaId), [keepWallet.info.metaId])
    }
}

// MARK: - Private

private extension AssetVisibilityCleaningTests {
    struct TestContext {
        let operationQueue: OperationQueue
        let facade: UserDataStorageTestFacade
        let visibilityRepository: AnyDataProviderRepository<AssetVisibilityLocal>
        let settingsRepository: AnyDataProviderRepository<MetaAccountSettingsLocal>

        static func create() -> TestContext {
            let facade = UserDataStorageTestFacade()

            return TestContext(
                operationQueue: OperationQueue(),
                facade: facade,
                visibilityRepository: AssetVisibilityRepositoryFactory.createVisibilityRepository(using: facade),
                settingsRepository: AssetVisibilityRepositoryFactory.createSettingsRepository(using: facade)
            )
        }
    }

    // MARK: - Helpers

    func createTestWallet(
        isSelected: Bool = false,
        order: UInt32 = 0
    ) -> ManagedMetaAccountModel {
        ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 0),
            isSelected: isSelected,
            order: order
        )
    }

    func createRows(
        for wallet: ManagedMetaAccountModel,
        chainAssetIds: [ChainAssetId]
    ) -> [AssetVisibilityLocal] {
        chainAssetIds.map {
            AssetVisibilityLocal(
                metaId: wallet.info.metaId,
                chainId: $0.chainId,
                assetId: $0.assetId,
                state: .visible
            )
        }
    }

    func createSettings(for wallet: ManagedMetaAccountModel) -> MetaAccountSettingsLocal {
        MetaAccountSettingsLocal(metaId: wallet.info.metaId, autoAddTokensWithBalance: false)
    }

    func createProviders(
        changes: [DataProviderChange<ManagedMetaAccountModel>],
        walletsBeforeChanges: [String: ManagedMetaAccountModel]
    ) -> WalletStorageCleaningProviders {
        WalletStorageCleaningProviders(
            changesProvider: { changes },
            walletsBeforeChangesProvider: { walletsBeforeChanges }
        )
    }

    func save<T: Identifiable>(
        _ models: [T],
        to repository: AnyDataProviderRepository<T>,
        using queue: OperationQueue
    ) throws {
        let saveOperation = repository.saveOperation({ models }, { [] })
        queue.addOperations([saveOperation], waitUntilFinished: true)
        try saveOperation.extractNoCancellableResultData()
    }

    func fetchAll<T: Identifiable>(
        from repository: AnyDataProviderRepository<T>,
        using queue: OperationQueue
    ) throws -> [T] {
        let fetchOperation = repository.fetchAllOperation(with: .init())
        queue.addOperations([fetchOperation], waitUntilFinished: true)
        return try fetchOperation.extractNoCancellableResultData()
    }

    func executeCleanerAndVerify(
        _ cleaner: WalletStorageCleaning,
        providers: WalletStorageCleaningProviders,
        using queue: OperationQueue
    ) throws {
        let wrapper = cleaner.cleanStorage(using: providers)
        queue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        XCTAssertNoThrow(try wrapper.targetOperation.extractNoCancellableResultData())
    }
}
