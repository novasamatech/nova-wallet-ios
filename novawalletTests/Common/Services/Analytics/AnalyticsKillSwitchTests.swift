import XCTest
@testable import novawallet
import Operation_iOS
import Cuckoo

final class AnalyticsKillSwitchTests: XCTestCase {
    func testRemoteDisabledMakesTheSubsystemUnavailable() {
        let availability = AnalyticsAvailabilityProvider(attestationMode: .appAttest, remoteEnabled: true)
        XCTAssertTrue(availability.isAvailable)

        availability.setRemoteEnabled(false)
        XCTAssertFalse(availability.isAvailable)
    }

    func testUnavailableAttestationBeatsAnEnabledRemoteConfig() {
        let availability = AnalyticsAvailabilityProvider(attestationMode: .unavailable, remoteEnabled: true)
        XCTAssertFalse(availability.isAvailable)
    }

    func testKillSwitchWipesOnceOnTheEnabledToDisabledEdge() throws {
        let fixture = AnalyticsTestFixture.makeConsented()

        fixture.service.track(.novaCardOpened())
        XCTAssertGreaterThan(try fixture.queueCount(), 0)

        // Still available: the edge has not been crossed, so nothing is wiped.
        fixture.service.handleAvailabilityChanged()
        XCTAssertGreaterThan(try fixture.queueCount(), 0)

        // Rows left by a previous, still-enabled process are cleared once.
        fixture.availability.setRemoteEnabled(false)
        fixture.service.handleAvailabilityChanged()
        XCTAssertEqual(try fixture.queueCount(), 0)

        // A second disabled launch has nothing to clear and must not re-run the wipe: a
        // row staged by hand survives, which a wipe-on-every-call would delete.
        try fixture.enqueueBypassingTheGuard(name: "leftover")
        fixture.service.handleAvailabilityChanged()
        XCTAssertEqual(try fixture.queueCount(), 1)
    }

    func testKillSwitchAbandonsAnInFlightFlush() throws {
        // A POST already in the air must be abandoned so its batch is never dropped from
        // a queue that is about to be wiped.
        let fixture = AnalyticsTestFixture.makeConsented()
        let started = XCTestExpectation(description: "flush started")
        let neverFinishes = CompoundOperationWrapper(
            targetOperation: AsyncClosureOperation<Void> { _ in started.fulfill() }
        )

        stub(fixture.uploader) { stub in
            when(stub.flushWrapper(maxBatches: any())).thenReturn(neverFinishes)
        }

        fixture.service.track(.novaCardOpened())
        wait(for: [started], timeout: 5)
        XCTAssertGreaterThan(try fixture.queueCount(), 0)

        fixture.availability.setRemoteEnabled(false)
        fixture.service.handleAvailabilityChanged()

        XCTAssertTrue(neverFinishes.targetOperation.isCancelled)
        XCTAssertEqual(try fixture.queueCount(), 0)
    }

    func testGlobalConfigDecodesWithoutAnAnalyticsSection() throws {
        // The payload shipped at nova-utils/global/config.json today, verbatim.
        let json = Data(#"""
        {
          "multisigsApiUrl": "https://subquery-accounts-prod.novasama-tech.org/",
          "proxyApiUrl": "https://subquery-accounts-prod.novasama-tech.org",
          "multiStakingApiUrl": "https://subquery-multi-staking-prod.novasama-tech.org"
        }
        """#.utf8)

        let config = try JSONDecoder().decode(GlobalConfig.self, from: json)

        XCTAssertNil(config.analytics)
        XCTAssertEqual(config.proxyApiUrl.absoluteString, "https://subquery-accounts-prod.novasama-tech.org")
    }

    func testGlobalConfigDecodesTheAnalyticsSection() throws {
        let json = Data(#"""
        {"multiStakingApiUrl":"https://a.example","multisigsApiUrl":"https://b.example","proxyApiUrl":"https://c.example","analytics":{"enabled":false,"minVersion":"10.9.0"}}
        """#.utf8)

        let config = try JSONDecoder().decode(GlobalConfig.self, from: json)

        XCTAssertEqual(config.analytics?.enabled, false)
        XCTAssertEqual(config.analytics?.minVersion, "10.9.0")
    }

    func testGlobalConfigDecodesTheAnalyticsSectionWithoutAMinVersion() throws {
        let json = Data(#"""
        {"multiStakingApiUrl":"https://a.example","multisigsApiUrl":"https://b.example","proxyApiUrl":"https://c.example","analytics":{"enabled":true}}
        """#.utf8)

        let config = try JSONDecoder().decode(GlobalConfig.self, from: json)

        XCTAssertEqual(config.analytics?.enabled, true)
        XCTAssertNil(config.analytics?.minVersion)
    }
}
