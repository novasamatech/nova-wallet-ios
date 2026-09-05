import XCTest
import Operation_iOS
@testable import NovaAnalytics

final class AnalyticsStorageFacadeTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Proves the .xcdatamodeld actually compiled into the package bundle. SwiftPM runs
    /// `momc` on it, but only if it is declared as a resource — and if it is not, this is
    /// the only place that surfaces before a device crash.
    func testModelLoadsFromThePackageBundle() throws {
        let facade = AnalyticsStorageFacade(storeDirectory: directory)

        let repository = facade.createEventRepository()
        let operation = repository.fetchCountOperation()

        let queue = OperationQueue()
        queue.addOperations([operation], waitUntilFinished: true)

        XCTAssertEqual(try operation.extractNoCancellableResultData(), 0)
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
            payload: Data("{}".utf8)
        )

        let save = repository.saveOperation({ [event] }, { [] })
        queue.addOperations([save], waitUntilFinished: true)
        _ = try save.extractNoCancellableResultData()

        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        queue.addOperations([fetch], waitUntilFinished: true)

        XCTAssertEqual(try fetch.extractNoCancellableResultData(), [event])
    }
}
