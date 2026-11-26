import XCTest
@testable import novawallet

final class ConfigMirrorAvailabilityTests: XCTestCase {
    private let initialPause: TimeInterval = 60
    private let maxPause: TimeInterval = 1800
    private let clock = ConfigMirrorTestClock()

    private func makeAvailability() -> ConfigMirrorAvailability {
        ConfigMirrorAvailability(initialPause: initialPause, pauseMultiplier: 2, maxPause: maxPause) { [clock] in
            clock.time
        }
    }

    func testEveryRequestUsesMirrorUntilItFails() {
        let availability = makeAvailability()

        XCTAssertEqual(availability.beginAttempt(), .regular)
        XCTAssertEqual(availability.beginAttempt(), .regular)

        // nothing but an unavailable mirror starts a pause
        XCTAssertNil(availability.endAttempt(.regular, verdict: .reachable))
        XCTAssertNil(availability.endAttempt(.regular, verdict: .unknown))
        XCTAssertEqual(availability.beginAttempt(), .regular)

        XCTAssertEqual(availability.endAttempt(.regular, verdict: .unavailable), initialPause)
        XCTAssertNil(availability.beginAttempt())
    }

    func testOnlyOneRequestProbesMirrorAfterPause() {
        let availability = makeAvailability()

        XCTAssertEqual(availability.endAttempt(.regular, verdict: .unavailable), initialPause)

        clock.time += initialPause - 1

        XCTAssertNil(availability.beginAttempt())

        clock.time += 1

        XCTAssertEqual(availability.beginAttempt(), .probe)

        // the others keep reading the original urls until the probe reports
        XCTAssertNil(availability.beginAttempt())
        XCTAssertNil(availability.beginAttempt())

        XCTAssertNil(availability.endAttempt(.probe, verdict: .reachable))

        XCTAssertEqual(availability.beginAttempt(), .regular)
        XCTAssertEqual(availability.beginAttempt(), .regular)
    }

    func testPauseDoublesWithEveryFailedProbeUpToLimitAndStartsOverAfterAnswer() {
        let availability = makeAvailability()

        var pauses = [availability.endAttempt(.regular, verdict: .unavailable)]

        for _ in 0 ..< 6 {
            clock.time += pauses.last.flatMap { $0 } ?? 0

            XCTAssertEqual(availability.beginAttempt(), .probe)

            pauses.append(availability.endAttempt(.probe, verdict: .unavailable))

            XCTAssertNil(availability.beginAttempt())
        }

        XCTAssertEqual(pauses, [60, 120, 240, 480, 960, 1800, 1800])

        // an answer of the mirror ends the pause and the next failure starts from the shortest one
        clock.time += maxPause

        XCTAssertEqual(availability.beginAttempt(), .probe)
        XCTAssertNil(availability.endAttempt(.probe, verdict: .reachable))
        XCTAssertEqual(availability.endAttempt(.regular, verdict: .unavailable), initialPause)
    }

    func testProbeWithoutVerdictGivesItsSlotToNextRequest() {
        let availability = makeAvailability()

        XCTAssertEqual(availability.endAttempt(.regular, verdict: .unavailable), initialPause)

        clock.time += initialPause

        XCTAssertEqual(availability.beginAttempt(), .probe)
        XCTAssertNil(availability.endAttempt(.probe, verdict: .unknown))

        // the mirror is still not in use, the next request asks it again
        XCTAssertEqual(availability.beginAttempt(), .probe)
        XCTAssertNil(availability.beginAttempt())

        // and the pause it starts is the next one in the row
        XCTAssertEqual(availability.endAttempt(.probe, verdict: .unavailable), initialPause * 2)
    }

    func testAttemptsThatWereLetInBeforePauseDoNotChangeIt() {
        let availability = makeAvailability()

        XCTAssertEqual(availability.endAttempt(.regular, verdict: .unavailable), initialPause)

        // the requests that were in flight together with the failed one
        XCTAssertNil(availability.endAttempt(.regular, verdict: .unavailable))
        XCTAssertNil(availability.endAttempt(.regular, verdict: .reachable))
        XCTAssertNil(availability.beginAttempt())

        clock.time += initialPause

        XCTAssertEqual(availability.beginAttempt(), .probe)

        // nor do they speak for the probe
        XCTAssertNil(availability.endAttempt(.regular, verdict: .reachable))
        XCTAssertNil(availability.endAttempt(.regular, verdict: .unavailable))
        XCTAssertNil(availability.beginAttempt())

        XCTAssertEqual(availability.endAttempt(.probe, verdict: .unavailable), initialPause * 2)
    }

    func testOnlyOneOfConcurrentFailuresStartsPauseAndOnlyOneRequestProbesAfterIt() {
        let availability = makeAvailability()
        let mutex = NSLock()
        var startedCount = 0
        var probeCount = 0

        DispatchQueue.concurrentPerform(iterations: 200) { _ in
            let hasStarted = availability.endAttempt(.regular, verdict: .unavailable) != nil

            mutex.lock()
            startedCount += hasStarted ? 1 : 0
            mutex.unlock()
        }

        XCTAssertEqual(startedCount, 1)

        clock.time += initialPause

        DispatchQueue.concurrentPerform(iterations: 200) { _ in
            let isProbe = availability.beginAttempt() == .probe

            mutex.lock()
            probeCount += isProbe ? 1 : 0
            mutex.unlock()
        }

        XCTAssertEqual(probeCount, 1)
    }
}
