import XCTest
@testable import novawallet
import Operation_iOS
import CoreData

final class AnalyticsUserModel21MigrationTests: XCTestCase {
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
}

private extension AnalyticsUserModel21MigrationTests {
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
