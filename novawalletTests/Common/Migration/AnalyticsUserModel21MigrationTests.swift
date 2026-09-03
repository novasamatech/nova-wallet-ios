import XCTest
@testable import novawallet
import Operation_iOS
import CoreData
import Keystore_iOS

final class AnalyticsUserModel21MigrationTests: XCTestCase {
    private let databaseDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("AnalyticsUserModel21MigrationTests")
    private let databaseName = UUID().uuidString + ".sqlite"
    private let modelDirectory = UserStorageParams.modelDirectory

    private var storeURL: URL {
        databaseDirectory.appendingPathComponent(databaseName)
    }

    override func setUp() {
        super.setUp()

        try? FileManager.default.removeItem(at: databaseDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: databaseDirectory)

        super.tearDown()
    }

    func testModelVersionIsTwentyTwo() {
        XCTAssertEqual(UserStorageParams.modelVersion, .version22)
        XCTAssertEqual(UserStorageVersion.version22.rawValue, "MultiassetUserDataModel21")
        XCTAssertEqual(UserStorageVersion.version21.nextVersion, .version22)
        XCTAssertNil(UserStorageVersion.version22.nextVersion)
    }

    func testNewEntitiesExistAndOldOneIsGone() throws {
        let names = Set(try currentUserDataModel().entities.compactMap(\.name))

        XCTAssertTrue(names.contains("CDAnalyticsEvent"))
        XCTAssertTrue(names.contains("CDAppAttestKey"))
        XCTAssertFalse(names.contains("CDAppAttestBrowserSettings"))
    }

    func testAnalyticsEventEntityShape() throws {
        let entity = try XCTUnwrap(currentUserDataModel().entitiesByName["CDAnalyticsEvent"])

        XCTAssertEqual(entity.attributesByName["identifier"]?.attributeType, .stringAttributeType)
        XCTAssertEqual(entity.attributesByName["sequence"]?.attributeType, .integer64AttributeType)
        XCTAssertEqual(entity.attributesByName["name"]?.attributeType, .stringAttributeType)
        XCTAssertEqual(entity.attributesByName["timestamp"]?.attributeType, .dateAttributeType)
        XCTAssertEqual(entity.attributesByName["payload"]?.attributeType, .binaryDataAttributeType)
        XCTAssertTrue(entity.relationshipsByName.isEmpty)
    }

    func testAppAttestKeyEntityShape() throws {
        let entity = try XCTUnwrap(currentUserDataModel().entitiesByName["CDAppAttestKey"])

        XCTAssertEqual(entity.attributesByName["identifier"]?.attributeType, .stringAttributeType)
        XCTAssertEqual(entity.attributesByName["keyId"]?.attributeType, .stringAttributeType)
        XCTAssertEqual(entity.attributesByName["isAttested"]?.attributeType, .booleanAttributeType)
        XCTAssertTrue(entity.relationshipsByName.isEmpty)
    }

    func testAppAttestKeyRoundTrips() throws {
        let facade = UserDataStorageTestFacade()
        let repository: CoreDataRepository<AppAttestKeySettings, CDAppAttestKey> =
            facade.createRepository(mapper: AnyCoreDataMapper(AppAttestKeyMapper()))

        let settings = AppAttestKeySettings(
            identifier: "https://gateway.example/",
            keyId: "key-1",
            isAttested: true
        )

        let saveOperation = repository.saveOperation({ [settings] }, { [] })
        let fetchOperation = repository.fetchOperation(by: { settings.identifier }, options: .init())
        fetchOperation.addDependency(saveOperation)

        OperationQueue().addOperations([saveOperation, fetchOperation], waitUntilFinished: true)

        let fetched = try fetchOperation.extractNoCancellableResultData()
        XCTAssertEqual(fetched, settings)
    }

    func testStoreCreatedByPreviousModelMigratesAndKeepsWallets() throws {
        let metaId = UUID().uuidString
        let walletName = "Migrated wallet"

        try seedPreviousModelStore(metaId: metaId, walletName: walletName)

        let migrator = UserStorageMigrator(
            targetVersion: .version22,
            storeURL: storeURL,
            modelDirectory: modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: FileManager.default
        )

        XCTAssertTrue(migrator.requiresMigration())

        migrator.performMigration()

        XCTAssertFalse(migrator.requiresMigration())

        let entityNames = try migratedStoreEntityNames()

        XCTAssertTrue(entityNames.contains("CDAnalyticsEvent"))
        XCTAssertTrue(entityNames.contains("CDAppAttestKey"))
        XCTAssertFalse(entityNames.contains("CDAppAttestBrowserSettings"))

        XCTAssertEqual(try migratedWalletNames(), [walletName])
    }
}

private extension AnalyticsUserModel21MigrationTests {
    func createCoreDataService(for version: UserStorageVersion) throws -> CoreDataServiceProtocol {
        let modelURL = try XCTUnwrap(
            Bundle.main.url(
                forResource: version.rawValue,
                withExtension: "mom",
                subdirectory: modelDirectory
            )
        )

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

    func seedPreviousModelStore(metaId: String, walletName: String) throws {
        let service = try createCoreDataService(for: .version21)
        let semaphore = DispatchSemaphore(value: 0)

        service.performAsync { context, _ in
            defer { semaphore.signal() }

            guard let context else { return }

            let wallet = NSEntityDescription.insertNewObject(forEntityName: "CDMetaAccount", into: context)
            wallet.setValue(metaId, forKey: "metaId")
            wallet.setValue(walletName, forKey: "name")
            wallet.setValue(true, forKey: "isSelected")
            wallet.setValue(0, forKey: "order")
            wallet.setValue(0, forKey: "type")

            let attest = NSEntityDescription.insertNewObject(
                forEntityName: "CDAppAttestBrowserSettings",
                into: context
            )
            attest.setValue("https://dapp.example/", forKey: "baseURL")
            attest.setValue("legacy-key", forKey: "keyId")
            attest.setValue(true, forKey: "isAttested")

            try? context.save()
        }

        semaphore.wait()

        try service.close()
    }

    func migratedStoreEntityNames() throws -> Set<String> {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )

        let entityNames = try XCTUnwrap(metadata[NSStoreModelVersionHashesKey] as? [String: Any]).keys

        return Set(entityNames)
    }

    func migratedWalletNames() throws -> [String] {
        let service = try createCoreDataService(for: .version22)
        let semaphore = DispatchSemaphore(value: 0)
        var names: [String] = []

        service.performAsync { context, _ in
            defer { semaphore.signal() }

            guard let context else { return }

            let request = NSFetchRequest<NSManagedObject>(entityName: "CDMetaAccount")
            let results = (try? context.fetch(request)) ?? []

            names = results.compactMap { $0.value(forKey: "name") as? String }
        }

        semaphore.wait()

        try service.close()

        return names
    }

    func currentUserDataModel() throws -> NSManagedObjectModel {
        let modelName = UserStorageParams.modelVersion.rawValue
        let subdirectory = UserStorageParams.modelDirectory
        let bundle = Bundle.main

        let modelURL = bundle.url(
            forResource: modelName,
            withExtension: "omo",
            subdirectory: subdirectory
        ) ?? bundle.url(
            forResource: modelName,
            withExtension: "mom",
            subdirectory: subdirectory
        )

        return try XCTUnwrap(NSManagedObjectModel(contentsOf: try XCTUnwrap(modelURL)))
    }
}
