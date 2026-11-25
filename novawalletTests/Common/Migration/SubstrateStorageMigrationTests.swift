import CoreData
@testable import novawallet
import XCTest

final class SubstrateStorageMigrationTests: XCTestCase {
    private let storeURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).sqlite")

    override func tearDown() {
        ["", "-wal", "-shm"].forEach { try? FileManager.default.removeItem(atPath: storeURL.path + $0) }
        super.tearDown()
    }

    func testTransactionRowSurvivesMigrationToVersion41WithoutNonce() throws {
        let migrator = SubstrateStorageMigrator(
            storeURL: storeURL,
            modelDirectory: SubstrateStorageParams.modelDirectory,
            model: .version41,
            fileManager: .default
        )
        let oldContext = try makeContext(for: .version40, migrator: migrator)
        let row = NSEntityDescription.insertNewObject(forEntityName: "CDTransactionItem", into: oldContext)
        row.setValuesForKeys(["identifier": "0x01 - 2", "txHash": "0x01", "chainId": "eip155:1", "status": 0])
        try oldContext.save()
        let oldCoordinator = try XCTUnwrap(oldContext.persistentStoreCoordinator)
        try oldCoordinator.persistentStores.forEach { try oldCoordinator.remove($0) }

        XCTAssertTrue(migrator.requiresMigration())
        migrator.performMigration()

        let rows = try makeContext(for: .version41, migrator: migrator)
            .fetch(NSFetchRequest<NSManagedObject>(entityName: "CDTransactionItem"))
        XCTAssertEqual(rows.compactMap { $0.value(forKey: "identifier") as? String }, ["0x01 - 2"])
        XCTAssertNil(rows.first?.value(forKey: "nonce"))
    }

    private func makeContext(
        for version: SubstrateStorageVersion,
        migrator: SubstrateStorageMigrator
    ) throws -> NSManagedObjectContext {
        let model = migrator.createManagedObjectModel(forResource: version.rawValue, modelDirectory: migrator.modelDirectory)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }
}
