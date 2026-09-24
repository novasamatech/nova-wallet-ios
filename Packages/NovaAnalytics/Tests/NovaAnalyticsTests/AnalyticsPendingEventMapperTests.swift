import XCTest
@testable import NovaAnalytics
import CoreData

final class AnalyticsPendingEventMapperTests: XCTestCase {
    func testRoundTrip() throws {
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: AnalyticsStorageFacade.modelURL))
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let entity = CDAnalyticsEvent(context: context)
        let mapper = AnalyticsPendingEventMapper()

        let event = AnalyticsPendingEvent(
            identifier: AnalyticsPendingEvent.identifier(for: 7),
            eventId: AnalyticsPendingEvent.eventId(),
            sequence: 7,
            name: "app_opened",
            timestamp: Date(timeIntervalSince1970: 1_770_000_000),
            payload: Data(#"{"is_first_launch":false}"#.utf8),
            consentEpoch: 3
        )

        try mapper.populate(entity: entity, from: event, using: context)

        XCTAssertEqual(try mapper.transform(entity: entity), event)
    }
}
