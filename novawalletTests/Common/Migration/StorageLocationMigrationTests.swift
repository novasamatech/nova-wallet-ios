import XCTest
@testable import novawallet
import Keystore_iOS
import Operation_iOS
import CoreData

final class StorageLocationMigrationTests: XCTestCase {
    let deprecatedDatabaseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("CoreDataLocation")
    
    let sharedDatabaseDirectory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedContainerGroup.name
        )!.appendingPathComponent("\(UUID().uuidString)-CoreData")
    
    let databaseName = UUID().uuidString + ".sqlite"
    let modelDirectory = "UserDataModel.momd"
    
    var deprecatedStorageURL: URL {
        deprecatedDatabaseDirectory.appendingPathComponent(databaseName)
    }

    var sharedStorageURL: URL {
        sharedDatabaseDirectory.appendingPathComponent(databaseName)
    }
    
    func testMigrationFromSingleAppToGroup() {
        do {
            let oldSettings = CoreDataPersistentSettings(
                databaseDirectory: deprecatedDatabaseDirectory,
                databaseName: databaseName,
                incompatibleModelStrategy: .ignore
            )
            
            let newSettings = CoreDataPersistentSettings(
                databaseDirectory: sharedDatabaseDirectory,
                databaseName: databaseName,
                incompatibleModelStrategy: .ignore
            )
            
            let walletsCount = 10
            let expectedMetaIds = try createOldEntities(
                for: walletsCount,
                version: .version11,
                persistentSettings: oldSettings
            )
            
            XCTAssertEqual(walletsCount, expectedMetaIds.count)
            
            let migrator = createMigrator()
            
            try migrator.migrate()
            
            let fetchedMetaIds = try fetchNewEntities(
                for: .version18,
                persistentSettings: newSettings
            )
            
            XCTAssertEqual(fetchedMetaIds, expectedMetaIds)
            
            let excludedFromBackup = try databaseDirectoryExistsAndExcludedFromBackup(sharedDatabaseDirectory)
            XCTAssertTrue(excludedFromBackup)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    private func databaseDirectoryExistsAndExcludedFromBackup(_ url: URL) throws -> Bool {
        var databaseStorageUrl = url
        databaseStorageUrl.removeAllCachedResourceValues()
        let resourceValues = try databaseStorageUrl.resourceValues(forKeys: [.isExcludedFromBackupKey])
        return resourceValues.isExcludedFromBackup == true
    }
    
    private func createStorePathMigrator() -> Migrating {
        StorePathMigrator(
            currentStoreLocation: deprecatedStorageURL,
            sharedStoreLocation: sharedStorageURL,
            sharedStoreDirectory: sharedDatabaseDirectory,
            fileManager: FileManager.default
        )
    }
    
    private func createMigrator() -> Migrating {
        let storePathMigrator = createStorePathMigrator()

        let storageMigrator = UserStorageMigrator(
            targetVersion: UserStorageParams.modelVersion,
            storeURL: sharedStorageURL,
            modelDirectory: modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: FileManager.default
        )

        return SerialMigrator(migrations: [storePathMigrator, storageMigrator])
    }
    
    private func fetchNewEntities(
        for version: UserStorageVersion,
        persistentSettings: CoreDataPersistentSettings
    ) throws -> Set<MetaAccountModel.Id> {
        let dbService = createCoreDataService(for: version, persistentSettings: persistentSettings)
        let semaphore = DispatchSemaphore(value: 0)
        var newEntities = Set<MetaAccountModel.Id>()

        dbService.performAsync { (context, error) in
            defer {
                semaphore.signal()
            }

            let request = NSFetchRequest<NSManagedObject>(entityName: "CDMetaAccount")
            let results = try! context?.fetch(request)

            results?.forEach { entity in
                let metaId = entity.value(forKey: "metaId") as? MetaAccountModel.Id
                newEntities.insert(metaId!)
            }
        }

        semaphore.wait()

        try dbService.close()

        return newEntities
    }
    
    private func createOldEntities(
        for count: Int,
        version: UserStorageVersion,
        persistentSettings: CoreDataPersistentSettings
    ) throws -> Set<MetaAccountModel.Id> {
        let dbService = createCoreDataService(for: version, persistentSettings: persistentSettings)

        let metaIds = (0..<count).map { _ in UUID().uuidString }

        let semaphore = DispatchSemaphore(value: 0)

        dbService.performAsync { (context, error) in
            defer {
                semaphore.signal()
            }

            guard let context = context else {
                return
            }

            metaIds.forEach { metaId in
                let entity = NSEntityDescription.insertNewObject(
                    forEntityName: "CDMetaAccount",
                    into: context
                )

                entity.setValue(metaId, forKey: "metaId")
                entity.setValue("Test name", forKey: "name")
                entity.setValue(false, forKey: "isSelected")
            }

            try! context.save()
        }

        semaphore.wait()
        
        return Set(metaIds)
    }
    
    private func createModelURL(for version: UserStorageVersion) -> URL {
        let bundle = Bundle.main

        return bundle.url(
            forResource: version.rawValue,
            withExtension: "mom",
            subdirectory: modelDirectory
        )!
    }

    private func createCoreDataService(
        for version: UserStorageVersion,
        persistentSettings: CoreDataPersistentSettings
    ) -> CoreDataServiceProtocol {
        let modelURL = createModelURL(for: version)

        let configuration = CoreDataServiceConfiguration(
            modelURL: modelURL,
            storageType: .persistent(settings: persistentSettings)
        )

        return CoreDataService(configuration: configuration)
    }
}
