import XCTest
@testable import novawallet
import Keystore_iOS
import Operation_iOS
import CoreData

final class AppAttestBrowserSettingsRemovalMigrationTests: XCTestCase {
    private let databaseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("CoreDataAppAttestRemoval")
    private let databaseName = UUID().uuidString + ".sqlite"
    private let modelDirectory = "UserDataModel.momd"
    private let attestEntityName = "CDAppAttestBrowserSettings"

    private var storeURL: URL {
        databaseDirectory.appendingPathComponent(databaseName)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: databaseDirectory)
        super.tearDown()
    }

    func testAttestBrowserSettingsEntityIsGoneFromMigratedStore() throws {
        try migrateLegacyStore()

        XCTAssertFalse(try storeEntityNames().contains(attestEntityName))
    }

    func testMetaAccountSurvivesAttestBrowserSettingsRemoval() throws {
        let metaId = try migrateLegacyStore()

        XCTAssertEqual(try fetchMetaAccountIds(), [metaId])
    }

    @discardableResult
    private func migrateLegacyStore() throws -> MetaAccountModel.Id {
        let metaId = UUID().uuidString

        try perform(on: .version21) { context in
            let metaAccount = NSEntityDescription.insertNewObject(forEntityName: "CDMetaAccount", into: context)
            metaAccount.setValue(metaId, forKey: "metaId")
            metaAccount.setValue("Test name", forKey: "name")
            metaAccount.setValue(false, forKey: "isSelected")

            let attestSettings = NSEntityDescription.insertNewObject(forEntityName: "CDAppAttestBrowserSettings", into: context)
            attestSettings.setValue("https://dapp.example.com", forKey: "baseURL")
            attestSettings.setValue(UUID().uuidString, forKey: "keyId")
            attestSettings.setValue(true, forKey: "isAttested")

            try! context.save()
        }

        XCTAssertTrue(try storeEntityNames().contains(attestEntityName))

        let migrator = UserStorageMigrator(targetVersion: UserStorageParams.modelVersion, storeURL: storeURL, modelDirectory: modelDirectory, keystore: InMemoryKeychain(), settings: InMemorySettingsManager(), fileManager: FileManager.default)

        XCTAssertTrue(migrator.requiresMigration())

        migrator.performMigration()

        return metaId
    }

    private func fetchMetaAccountIds() throws -> Set<MetaAccountModel.Id> {
        var metaIds = Set<MetaAccountModel.Id>()

        try perform(on: UserStorageParams.modelVersion) { context in
            let entities = try! context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDMetaAccount"))
            metaIds = Set(entities.compactMap { $0.value(forKey: "metaId") as? MetaAccountModel.Id })
        }

        return metaIds
    }

    private func perform(on version: UserStorageVersion, _ body: @escaping (NSManagedObjectContext) -> Void) throws {
        let modelURL = Bundle.main.url(forResource: version.rawValue, withExtension: "mom", subdirectory: modelDirectory)!
        let persistentSettings = CoreDataPersistentSettings(databaseDirectory: databaseDirectory, databaseName: databaseName, incompatibleModelStrategy: .ignore)
        let configuration = CoreDataServiceConfiguration(modelURL: modelURL, storageType: .persistent(settings: persistentSettings))
        let dbService = CoreDataService(configuration: configuration)
        let semaphore = DispatchSemaphore(value: 0)

        dbService.performAsync { context, _ in
            defer { semaphore.signal() }

            if let context {
                body(context)
            }
        }

        semaphore.wait()

        try dbService.close()
    }

    private func storeEntityNames() throws -> Set<String> {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL, options: nil)

        return Set(try XCTUnwrap(metadata[NSStoreModelVersionHashesKey] as? [String: Any]).keys)
    }
}
