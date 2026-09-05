import XCTest
@testable import NovaAnalytics
import Operation_iOS

final class AnalyticsPendingEventMapperTests: XCTestCase {
    func testRowRoundTrips() throws {
        let facade = AnalyticsStorageTestFacade()
        let repository = facade.createEventRepository()

        let event = AnalyticsPendingEvent(
            identifier: AnalyticsPendingEvent.identifier(for: 7),
            sequence: 7,
            name: "app_opened",
            timestamp: Date(timeIntervalSince1970: 1_770_000_000),
            payload: Data(#"{"is_first_launch":false}"#.utf8)
        )

        let saveOperation = repository.saveOperation({ [event] }, { [] })
        let fetchOperation = repository.fetchOperation(by: { event.identifier }, options: .init())
        fetchOperation.addDependency(saveOperation)

        OperationQueue().addOperations([saveOperation, fetchOperation], waitUntilFinished: true)

        XCTAssertEqual(try fetchOperation.extractNoCancellableResultData(), event)
    }

    func testIdentifiersSortLexicographicallyBySequence() {
        let ids = [1, 2, 10, 100, 1000].map { AnalyticsPendingEvent.identifier(for: Int64($0)) }
        XCTAssertEqual(ids, ids.sorted())
    }

    func testUnknownEventNameSurvivesTheRow() throws {
        let facade = AnalyticsStorageTestFacade()
        let repository = facade.createEventRepository()

        let event = AnalyticsPendingEvent(
            identifier: AnalyticsPendingEvent.identifier(for: 1),
            sequence: 1,
            name: "an_event_this_build_does_not_know",
            timestamp: Date(timeIntervalSince1970: 1),
            payload: Data("{}".utf8)
        )

        let saveOperation = repository.saveOperation({ [event] }, { [] })
        let fetchOperation = repository.fetchOperation(by: { event.identifier }, options: .init())
        fetchOperation.addDependency(saveOperation)

        OperationQueue().addOperations([saveOperation, fetchOperation], waitUntilFinished: true)

        XCTAssertEqual(
            try fetchOperation.extractNoCancellableResultData()?.name,
            "an_event_this_build_does_not_know"
        )
    }
}
