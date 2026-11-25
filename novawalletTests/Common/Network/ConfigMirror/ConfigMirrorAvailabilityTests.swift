import XCTest
import Operation_iOS
@testable import novawallet

final class ConfigMirrorAvailabilityTests: XCTestCase {
    private enum Constants {
        static let cooldown: TimeInterval = 60
    }

    private var clock: ConfigMirrorTestClock!
    private var availability: ConfigMirrorAvailability!

    override func setUp() {
        super.setUp()

        let clock = ConfigMirrorTestClock()

        self.clock = clock
        availability = ConfigMirrorAvailability(cooldown: Constants.cooldown) { clock.uptime }
    }

    func testIsAvailableBeforeAnyFailure() {
        XCTAssertTrue(availability.isAvailable)
    }

    func testConnectionFailureStartsCooldown() {
        for code in [URLError.Code.timedOut, .cannotConnectToHost, .cannotFindHost, .secureConnectionFailed] {
            let clock = ConfigMirrorTestClock()
            let availability = ConfigMirrorAvailability(cooldown: Constants.cooldown) { clock.uptime }

            XCTAssertTrue(availability.registerFailure(URLError(code)), "\(code)")
            XCTAssertFalse(availability.isAvailable, "\(code)")
        }
    }

    func testCooldownEndsAfterItsPeriod() {
        // given
        XCTAssertTrue(availability.registerFailure(URLError(.timedOut)))

        // when
        clock.advance(by: Constants.cooldown - 1)

        // then
        XCTAssertFalse(availability.isAvailable)

        // when
        clock.advance(by: 1)

        // then
        XCTAssertTrue(availability.isAvailable)
    }

    func testFailureDuringCooldownDoesNotProlongIt() {
        // given
        XCTAssertTrue(availability.registerFailure(URLError(.timedOut)))

        // when
        clock.advance(by: Constants.cooldown - 1)

        // then
        XCTAssertFalse(availability.registerFailure(URLError(.timedOut)))

        // when
        clock.advance(by: 1)

        // then
        XCTAssertTrue(availability.isAvailable)
    }

    func testFailureAfterCooldownStartsNewOne() {
        // given
        XCTAssertTrue(availability.registerFailure(URLError(.timedOut)))

        clock.advance(by: Constants.cooldown)

        // when
        XCTAssertTrue(availability.registerFailure(URLError(.networkConnectionLost)))

        // then
        XCTAssertFalse(availability.isAvailable)
    }

    func testStatusAndBodyFailuresDoNotStartCooldown() {
        let errors: [Error] = [
            NetworkResponseError.resourceNotFound,
            NetworkResponseError.unexpectedStatusCode,
            NetworkResponseError.internalServerError,
            NetworkBaseError.unexpectedResponseObject,
            ConfigMirrorFetchError.emptyBody,
            ConfigMirrorFetchError.malformedJson(CocoaError(.propertyListReadCorrupt)),
            DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))
        ]

        for error in errors {
            XCTAssertFalse(availability.registerFailure(error), "\(error)")
        }

        XCTAssertTrue(availability.isAvailable)
    }

    func testCancellationDoesNotStartCooldown() {
        XCTAssertFalse(availability.registerFailure(URLError(.cancelled)))
        XCTAssertTrue(availability.isAvailable)
    }

    func testOnlyOneOfConcurrentFailuresStartsCooldown() {
        // given
        let iterations = 200
        let mutex = NSLock()
        var startedCount = 0

        // when
        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            let started = availability.registerFailure(URLError(.timedOut))
            _ = availability.isAvailable

            if started {
                mutex.lock()
                startedCount += 1
                mutex.unlock()
            }
        }

        // then
        XCTAssertEqual(startedCount, 1)
        XCTAssertFalse(availability.isAvailable)
    }

    func testReportLogsFailureAndCooldownStartOnce() throws {
        // given
        let logger = ConfigMirrorLoggerSpy()
        let mirrorUrl = try XCTUnwrap(URL(string: "https://mirror.novatest/v1/config/chains/v23/chains.json"))

        // when
        availability.reportFailure(URLError(.timedOut), for: mirrorUrl, logger: logger)
        availability.reportFailure(NetworkResponseError.resourceNotFound, for: mirrorUrl, logger: logger)

        // then
        let warnings = logger.warnings

        XCTAssertEqual(warnings.count, 3)
        XCTAssertTrue(logger.warning(at: 0).contains("/v1/config/chains/v23/chains.json"))
        XCTAssertTrue(logger.warning(at: 1).contains("cool-down"))
        XCTAssertTrue(logger.warning(at: 2).contains("/v1/config/chains/v23/chains.json"))
        XCTAssertTrue(logger.otherMessages.isEmpty)
    }
}
