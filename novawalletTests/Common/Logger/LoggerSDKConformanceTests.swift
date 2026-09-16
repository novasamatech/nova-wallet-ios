import XCTest
import SDKLogger
@testable import novawallet

final class LoggerSDKConformanceTests: XCTestCase {
    func testLoggerSatisfiesSDKLoggerProtocol() {
        let logger: SDKLogger.SDKLoggerProtocol = Logger.shared
        logger.info("conformance probe")
        XCTAssertTrue(logger is Logger)
        Logger.shared.verbose("concrete call site stays unambiguous")
        Logger.shared.debug("concrete call site stays unambiguous")
        Logger.shared.info("concrete call site stays unambiguous")
        Logger.shared.warning("concrete call site stays unambiguous")
        Logger.shared.error("concrete call site stays unambiguous")
    }
}
