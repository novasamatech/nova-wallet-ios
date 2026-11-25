import XCTest
import Operation_iOS
@testable import novawallet

final class ConfigMirrorAvailabilityTests: XCTestCase {
    private let cooldown: TimeInterval = 60
    private let clock = ConfigMirrorTestClock()

    private func makeAvailability() -> ConfigMirrorAvailability {
        ConfigMirrorAvailability(cooldown: cooldown) { [clock] in clock.uptime }
    }

    func testConnectionFailureStartsCooldownThatEndsAfterItsPeriod() {
        let availability = makeAvailability()

        XCTAssertTrue(availability.isAvailable)
        XCTAssertTrue(availability.registerFailure(URLError(.timedOut)))

        clock.uptime += cooldown - 1

        // a failure during the cool-down neither starts a new one nor prolongs it
        XCTAssertFalse(availability.registerFailure(URLError(.cannotConnectToHost)))
        XCTAssertFalse(availability.isAvailable)

        clock.uptime += 1

        XCTAssertTrue(availability.isAvailable)
        XCTAssertTrue(availability.registerFailure(URLError(.networkConnectionLost)))
        XCTAssertFalse(availability.isAvailable)
    }

    func testServerErrorStartsCooldown() {
        for statusCode in [500, 502, 503, 504] {
            let availability = makeAvailability()

            XCTAssertTrue(availability.registerFailure(ConfigMirrorFailure.unexpectedStatus(statusCode)), "\(statusCode)")
            XCTAssertFalse(availability.isAvailable, "\(statusCode)")
        }
    }

    func testFailuresOfOneFileOrOfDeviceItselfDoNotStartCooldown() {
        let availability = makeAvailability()

        let errors: [Error] = [
            URLError(.cancelled),
            URLError(.notConnectedToInternet),
            URLError(.dataNotAllowed),
            URLError(.internationalRoamingOff),
            URLError(.callIsActive),
            ConfigMirrorFailure.unexpectedStatus(404),
            ConfigMirrorFailure.unexpectedStatus(204),
            ConfigMirrorFailure.unexpectedStatus(nil),
            ConfigMirrorFailure.emptyBody,
            ConfigMirrorFailure.malformedJson,
            NetworkResponseError.resourceNotFound,
            NetworkBaseError.unexpectedEmptyData,
            DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))
        ]

        for error in errors {
            XCTAssertFalse(availability.registerFailure(error), "\(error)")
        }

        XCTAssertTrue(availability.isAvailable)
    }

    func testOnlyOneOfConcurrentFailuresStartsCooldown() {
        let availability = makeAvailability()
        let mutex = NSLock()
        var startedCount = 0

        DispatchQueue.concurrentPerform(iterations: 200) { _ in
            let hasStarted = availability.registerFailure(URLError(.timedOut))
            _ = availability.isAvailable

            mutex.lock()
            startedCount += hasStarted ? 1 : 0
            mutex.unlock()
        }

        XCTAssertEqual(startedCount, 1)
        XCTAssertFalse(availability.isAvailable)
    }
}
