import XCTest
import Operation_iOS
@testable import NovaAnalytics

final class NoOpAnalyticsServiceFacadeTests: XCTestCase {
    func testNoOpFacadeDropsEverythingSilently() {
        let facade = NoOpAnalyticsServiceFacade.shared

        facade.setup()
        facade.track(.novaCardOpened())
        facade.flush(reason: .manual)
        facade.throttle()

        XCTAssertFalse(facade.consent.isEnabled)
        XCTAssertFalse(facade.consent.isAvailable)
    }

    func testNoOpFacadeAnswersTheDebugAccessorsWithoutAStore() throws {
        let facade = NoOpAnalyticsServiceFacade.shared
        let operationQueue = OperationQueue()

        let peekWrapper = facade.debugPendingEventsWrapper(count: 10)
        let clearOperation = facade.debugClearPendingEventsOperation()

        operationQueue.addOperations(peekWrapper.allOperations + [clearOperation], waitUntilFinished: true)

        XCTAssertEqual(try peekWrapper.targetOperation.extractNoCancellableResultData(), [])
        XCTAssertNoThrow(try clearOperation.extractNoCancellableResultData())
    }
}
