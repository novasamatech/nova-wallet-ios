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

        // Reproduces the three-way collision in the test module: these concrete call sites
        // compile only while `Logger` shadows the convenience forms itself.
        //
        // All five, because that is what the shadow declares. `verbose` and `warning` have
        // no app call sites at all, so with only `info` here their shadows could be deleted
        // and the whole suite would still pass.
        Logger.shared.verbose("concrete call site stays unambiguous")
        Logger.shared.debug("concrete call site stays unambiguous")
        Logger.shared.info("concrete call site stays unambiguous")
        Logger.shared.warning("concrete call site stays unambiguous")
        Logger.shared.error("concrete call site stays unambiguous")
    }
}
