import XCTest
import CoreData
import Operation_iOS
@testable import NovaAnalytics

final class AnalyticsStorageFacadeTests: XCTestCase {
    private var directory: URL!

    private var storeURL: URL {
        directory.appendingPathComponent(AnalyticsStorageFacade.databaseName)
    }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testEventRoundTripsThroughTheStore() throws {
        let facade = AnalyticsStorageFacade(storeDirectory: directory)
        let repository = facade.createEventRepository()
        let queue = OperationQueue()

        let event = AnalyticsPendingEvent(
            identifier: AnalyticsPendingEvent.identifier(for: 0, unique: "u"),
            sequence: 0,
            name: "app_opened",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            payload: Data("{}".utf8),
            consentEpoch: 2
        )

        let save = repository.saveOperation({ [event] }, { [] })
        queue.addOperations([save], waitUntilFinished: true)
        _ = try save.extractNoCancellableResultData()

        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        queue.addOperations([fetch], waitUntilFinished: true)

        XCTAssertEqual(try fetch.extractNoCancellableResultData(), [event])
    }

    func testAStoreCreatedWithAnEarlierModelIsReplacedRatherThanOpened() throws {
        try seedStore(with: makeModelWithoutConsentEpoch())

        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )
        let currentModel = try XCTUnwrap(NSManagedObjectModel(contentsOf: AnalyticsStorageFacade.modelURL))

        XCTAssertFalse(
            currentModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata),
            "the seeded store is compatible, so this test no longer exercises the replacement"
        )

        let facade = AnalyticsStorageFacade(storeDirectory: directory)
        let operation = facade.createEventRepository().fetchCountOperation()
        OperationQueue().addOperations([operation], waitUntilFinished: true)

        XCTAssertEqual(try operation.extractNoCancellableResultData(), 0)
    }

    private func makeModelWithoutConsentEpoch() -> NSManagedObjectModel {
        let entity = NSEntityDescription()
        entity.name = "CDAnalyticsEvent"
        entity.properties = [
            makeAttribute("identifier", .stringAttributeType),
            makeAttribute("name", .stringAttributeType),
            makeAttribute("payload", .binaryDataAttributeType),
            makeAttribute("sequence", .integer64AttributeType),
            makeAttribute("timestamp", .dateAttributeType)
        ]

        let model = NSManagedObjectModel()
        model.entities = [entity]

        return model
    }

    private func makeAttribute(_ name: String, _ type: NSAttributeType) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = true

        return attribute
    }

    private func seedStore(with model: NSManagedObjectModel) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
        )

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        try context.performAndWait {
            let row = NSEntityDescription.insertNewObject(forEntityName: "CDAnalyticsEvent", into: context)
            row.setValue("legacy", forKey: "identifier")
            row.setValue(Int64(0), forKey: "sequence")

            try context.save()
        }

        try coordinator.remove(store)
    }
}
