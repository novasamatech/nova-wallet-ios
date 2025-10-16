import XCTest
@testable import novawallet
import Operation_iOS
import Cuckoo

final class DAppSettingsCleaningTests: XCTestCase {
    func testRemovedWalletDAppSettingsCleanerRemovesSettings() throws {
        // given
        let context = TestContext.create()
        let removedWallet = createTestWallet()
        let keepWallet = createTestWallet(isSelected: true, order: 1)

        let removedSettings = createDAppSettings(dAppId: "google.com", for: removedWallet)
        let keepSettings = createDAppSettings(dAppId: "novasama.io", for: keepWallet)

        saveSettings([removedSettings, keepSettings], to: context.repository, using: context.operationQueue)

        let cleaner = RemovedWalletDAppSettingsCleaner(
            authorizedDAppRepository: context.repository
        )

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
        let remainingSettings = try fetchAllSettings(from: context.repository, using: context.operationQueue)
        XCTAssertEqual(remainingSettings.count, 1)
        XCTAssertEqual(remainingSettings.first?.metaId, keepWallet.info.metaId)
    }
}

// MARK: - Private

private extension DAppSettingsCleaningTests {
    struct TestContext {
        let operationQueue: OperationQueue
        let facade: UserDataStorageTestFacade
        let repository: AnyDataProviderRepository<DAppSettings>

        static func create() -> TestContext {
            let queue = OperationQueue()
            let facade = UserDataStorageTestFacade()
            let mapper = DAppSettingsMapper()
            let repository = facade.createRepository(mapper: AnyCoreDataMapper(mapper))

            return TestContext(
                operationQueue: queue,
                facade: facade,
                repository: AnyDataProviderRepository(repository)
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

    func createDAppSettings(
        dAppId: String,
        for wallet: ManagedMetaAccountModel
    ) -> DAppSettings {
        DAppSettings(
            dAppId: dAppId,
            metaId: wallet.info.metaId,
            source: nil
        )
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

    func saveSettings(
        _ settings: [DAppSettings],
        to repository: AnyDataProviderRepository<DAppSettings>,
        using queue: OperationQueue
    ) {
        let saveOperation = repository.saveOperation({ settings }, { [] })
        queue.addOperations([saveOperation], waitUntilFinished: true)
    }

    func fetchAllSettings(
        from repository: AnyDataProviderRepository<DAppSettings>,
        using queue: OperationQueue
    ) throws -> [DAppSettings] {
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
