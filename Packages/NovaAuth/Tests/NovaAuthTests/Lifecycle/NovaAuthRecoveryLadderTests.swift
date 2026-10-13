import XCTest
@testable import NovaAuth

final class NovaAuthRecoveryLadderTests: XCTestCase {
    func testRecreationLadderUsesPreIncrementTierAndSaturates() throws {
        var cooldown = NovaAuthCooldown()
        var seconds = 100.0
        for (index, delay) in [60.0, 600, 3600, 86400, 86400, 86400].enumerated() {
            cooldown.failLadder(now: NovaAuthTime(bootID: "boot-a", continuousSeconds: seconds), random: 0, caps: 86400)
            XCTAssertEqual(cooldown.deadline?.continuousSeconds, seconds + delay)
            XCTAssertEqual(cooldown.failures, min(index + 1, 4))
            seconds += delay
        }
    }

    func testRecreationCapAppliesBeforeMaximumJitter() throws {
        var cooldown = NovaAuthCooldown()
        var seconds = 100.0
        for _ in 0 ..< 5 {
            cooldown.failLadder(now: NovaAuthTime(bootID: "boot-a", continuousSeconds: seconds), random: 1, caps: 86400)
            seconds = try XCTUnwrap(cooldown.deadline).continuousSeconds
        }
        cooldown.failLadder(now: NovaAuthTime(bootID: "boot-a", continuousSeconds: seconds), random: 1, caps: 86400)
        XCTAssertEqual(try XCTUnwrap(cooldown.deadline).continuousSeconds - seconds, 95040, accuracy: 0.000001)
        XCTAssertEqual(cooldown.failures, 4)
    }

    func testPolicyLadderCapsBaseAtSixHundredSeconds() throws {
        var cooldown = NovaAuthCooldown()
        var seconds = 100.0
        for delay in [66.0, 660, 660, 660, 660] {
            cooldown.failLadder(now: NovaAuthTime(bootID: "boot-a", continuousSeconds: seconds), random: 1, caps: 600)
            XCTAssertEqual(try XCTUnwrap(cooldown.deadline).continuousSeconds - seconds, delay, accuracy: 0.000001)
            seconds = try XCTUnwrap(cooldown.deadline).continuousSeconds
        }
        XCTAssertEqual(cooldown.failures, 4)
    }

    func testProofLadderCapsBaseAtThirtySixHundredSeconds() throws {
        var cooldown = NovaAuthCooldown()
        var seconds = 100.0
        for delay in [66.0, 660, 3960, 3960, 3960] {
            cooldown.failLadder(now: NovaAuthTime(bootID: "boot-a", continuousSeconds: seconds), random: 1, caps: 3600)
            XCTAssertEqual(try XCTUnwrap(cooldown.deadline).continuousSeconds - seconds, delay, accuracy: 0.000001)
            seconds = try XCTUnwrap(cooldown.deadline).continuousSeconds
        }
        XCTAssertEqual(cooldown.failures, 4)
    }

    func testRebootEndsWaitWithoutResettingLadderTier() throws {
        var cooldown = NovaAuthCooldown()
        cooldown.failLadder(now: NovaAuthTime(bootID: "boot-a", continuousSeconds: 100), random: 0, caps: 86400)
        let rebooted = NovaAuthTime(bootID: "boot-b", continuousSeconds: 1)
        XCTAssertNoThrow(try cooldown.check(now: rebooted))
        cooldown.failLadder(now: rebooted, random: 0, caps: 86400)
        XCTAssertEqual(cooldown.deadline, NovaAuthTime(bootID: "boot-b", continuousSeconds: 601))
        XCTAssertEqual(cooldown.failures, 2)
    }
}
