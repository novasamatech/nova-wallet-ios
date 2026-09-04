import XCTest
import SDKLogger
@testable import novawallet

final class LoggerSDKConformanceTests: XCTestCase {
    func testLoggerSatisfiesSDKLoggerProtocol() {
        let logger: SDKLogger.SDKLoggerProtocol = Logger.shared

        // The one-argument convenience form is `public` in logger-ios and `internal` in
        // SubstrateSdk. If this compiles, the conformance resolved against logger-ios.
        logger.info("conformance probe")

        XCTAssertTrue(logger is Logger)

        // Reproduces the three-way collision in the test module: this concrete call site
        // compiles only while `Logger` shadows the convenience forms itself.
        Logger.shared.info("concrete call site stays unambiguous")
    }
}
