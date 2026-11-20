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

    /// The SDK builds a debug line for every WebSocket frame: a level the logger drops must cost nothing.
    func testMessageOfSDKIsBuiltOnlyForAcceptedLevel() {
        let logger: SDKLogger.SDKLoggerProtocol = Logger.shared
        let initialLevel = Logger.shared.minLevel

        defer { Logger.shared.minLevel = initialLevel }

        Logger.shared.minLevel = .info

        var builtMessages: [String] = []

        func send(_ level: String, with log: (() -> String, String, String, Int) -> Void) {
            log({
                builtMessages.append(level)
                return "lazy message probe"
            }, #file, #function, #line)
        }

        send("verbose") { logger.verbose(message: $0, file: $1, function: $2, line: $3) }
        send("debug") { logger.debug(message: $0, file: $1, function: $2, line: $3) }

        XCTAssertEqual(builtMessages, [])

        send("info") { logger.info(message: $0, file: $1, function: $2, line: $3) }
        send("warning") { logger.warning(message: $0, file: $1, function: $2, line: $3) }
        send("error") { logger.error(message: $0, file: $1, function: $2, line: $3) }

        XCTAssertEqual(builtMessages, ["info", "warning", "error"])

        Logger.shared.minLevel = .verbose

        send("verbose") { logger.verbose(message: $0, file: $1, function: $2, line: $3) }
        send("debug") { logger.debug(message: $0, file: $1, function: $2, line: $3) }

        XCTAssertEqual(builtMessages, ["info", "warning", "error", "verbose", "debug"])
    }
}
