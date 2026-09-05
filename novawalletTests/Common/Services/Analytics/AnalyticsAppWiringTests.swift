import XCTest
@testable import novawallet

/// The two analytics assertions that stay behind when the mechanism moves into
/// `NovaAnalytics`, because their subjects are app types the package cannot see:
/// `OperationManagerFacade.analyticsQueue`, which the app hands the service, and
/// `GlobalConfig`, which carries the remote kill switch.
///
/// Split out of `AnalyticsPendingEventMapperTests` and `AnalyticsKillSwitchTests` when
/// those moved into the package.
final class AnalyticsAppWiringTests: XCTestCase {
    func testAnalyticsQueueIsSerial() {
        XCTAssertEqual(OperationManagerFacade.analyticsQueue.maxConcurrentOperationCount, 1)
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
