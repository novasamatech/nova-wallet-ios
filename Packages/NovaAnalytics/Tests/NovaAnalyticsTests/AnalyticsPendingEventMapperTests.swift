import XCTest
@testable import NovaAnalytics
import Operation_iOS

final class AnalyticsPendingEventMapperTests: XCTestCase {
    func testRowRoundTrips() throws {
        let repository = AnalyticsStorageTestFacade().createEventRepository()

        let event = AnalyticsPendingEvent(
            identifier: AnalyticsPendingEvent.identifier(for: 7),
            sequence: 7,
            name: "app_opened",
            timestamp: Date(timeIntervalSince1970: 1_770_000_000),
            payload: Data(#"{"is_first_launch":false}"#.utf8),
            consentEpoch: 3
        )

        let saveOperation = repository.saveOperation({ [event] }, { [] })
        let fetchOperation = repository.fetchOperation(by: { event.identifier }, options: .init())
        fetchOperation.addDependency(saveOperation)

        OperationQueue().addOperations([saveOperation, fetchOperation], waitUntilFinished: true)

        XCTAssertEqual(try fetchOperation.extractNoCancellableResultData(), event)
    }
}
