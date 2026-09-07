import XCTest
@testable import novawallet
import Keystore_iOS
import Operation_iOS
import CoreData

final class AppAttestBrowserSettingsRemovalMigrationTests: XCTestCase {
    let databaseDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CoreDataAppAttestRemoval")

    let databaseName = UUID().uuidString + ".sqlite"
    let modelDirectory = "UserDataModel.momd"
    let attestEntityName = "CDAppAttestBrowserSettings"
    let metaAccountEntityName = "CDMetaAccount"

    var storeURL: URL {
        databaseDirectory.appendingPathComponent(databaseName)
    }

    override func setUp() {
        super.setUp()

        try? FileManager.default.removeItem(at: databaseDirectory)
    }

    override func tearDown() {
        super.tearDown()

        try? FileManager.default.removeItem(at: databaseDirectory)
    }

    func testStorageFacadeTargetsLatestDeclaredVersion() {
        XCTAssertEqual(UserStorageParams.modelVersion, UserStorageVersion.current)
    }

    func testAttestBrowserSettingsEntityIsGoneFromMigratedStore() throws {
        try createLegacyStore()

        migrateToTargetVersion()

        let entityNames = try storeEntityNames()

        XCTAssertFalse(entityNames.contains(attestEntityName))
    }

    func testMetaAccountSurvivesAttestBrowserSettingsRemoval() throws {
        let metaId = try createLegacyStore()

        migrateToTargetVersion()

        let migratedMetaIds = try fetchMetaAccountIds()

        XCTAssertEqual(migratedMetaIds, [metaId])
    }

    @discardableResult
    private func createLegacyStore() throws -> MetaAccountModel.Id {
        let dbService = createCoreDataService(for: .version21)

        let metaId = UUID().uuidString
        let metaAccountEntity = metaAccountEntityName
        let attestEntity = attestEntityName

        let semaphore = DispatchSemaphore(value: 0)

        dbService.performAsync { context, _ in
            defer {
                semaphore.signal()
            }

            guard let context else {
                return
            }

            let metaAccount = NSEntityDescription.insertNewObject(
                forEntityName: metaAccountEntity,
                into: context
            )

            metaAccount.setValue(metaId, forKey: "metaId")
            metaAccount.setValue("Test name", forKey: "name")
            metaAccount.setValue(false, forKey: "isSelected")

            let attestSettings = NSEntityDescription.insertNewObject(
                forEntityName: attestEntity,
                into: context
            )

            attestSettings.setValue("https://dapp.example.com", forKey: "baseURL")
            attestSettings.setValue(UUID().uuidString, forKey: "keyId")
            attestSettings.setValue(true, forKey: "isAttested")

            try! context.save()
        }

        semaphore.wait()

        try dbService.close()

        XCTAssertTrue(try storeEntityNames().contains(attestEntityName))

        return metaId
    }

    private func migrateToTargetVersion() {
        let migrator = UserStorageMigrator(
            targetVersion: UserStorageParams.modelVersion,
            storeURL: storeURL,
            modelDirectory: modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: FileManager.default
        )

        XCTAssertTrue(migrator.requiresMigration())

        migrator.performMigration()
    }

    private func storeEntityNames() throws -> Set<String> {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )

        let versionHashes = try XCTUnwrap(metadata[NSStoreModelVersionHashesKey] as? [String: Any])

        return Set(versionHashes.keys)
    }

    private func fetchMetaAccountIds() throws -> Set<MetaAccountModel.Id> {
        let dbService = createCoreDataService(for: UserStorageParams.modelVersion)

        let entityName = metaAccountEntityName
        let semaphore = DispatchSemaphore(value: 0)
        var metaIds = Set<MetaAccountModel.Id>()

        dbService.performAsync { context, _ in
            defer {
                semaphore.signal()
            }

            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            let results = try! context?.fetch(request)

            results?.forEach { entity in
                if let metaId = entity.value(forKey: "metaId") as? MetaAccountModel.Id {
                    metaIds.insert(metaId)
                }
            }
        }

        semaphore.wait()

        try dbService.close()

        return metaIds
    }

    private func createModelURL(for version: UserStorageVersion) -> URL {
        let bundle = Bundle.main

        return bundle.url(
            forResource: version.rawValue,
            withExtension: "mom",
            subdirectory: modelDirectory
        )!
    }

    private func createCoreDataService(for version: UserStorageVersion) -> CoreDataServiceProtocol {
        let modelURL = createModelURL(for: version)

        let persistentSettings = CoreDataPersistentSettings(
            databaseDirectory: databaseDirectory,
            databaseName: databaseName,
            incompatibleModelStrategy: .ignore
        )

        let configuration = CoreDataServiceConfiguration(
            modelURL: modelURL,
            storageType: .persistent(settings: persistentSettings)
        )

        return CoreDataService(configuration: configuration)
    }
}
