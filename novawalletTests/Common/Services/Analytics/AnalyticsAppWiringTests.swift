import XCTest
@testable import novawallet

final class AnalyticsAppWiringTests: XCTestCase {
    func testAnalyticsQueueIsSerial() {
        XCTAssertEqual(OperationManagerFacade.analyticsQueue.maxConcurrentOperationCount, 1)
    }

    func testGlobalConfigDecodesTheAnalyticsSection() throws {
        let json = Data(#"{"multiStakingApiUrl":"https://a.example","multisigsApiUrl":"https://b.example","proxyApiUrl":"https://c.example","analytics":{"enabled":false,"minVersion":"10.9.0"}}"#.utf8)

        let config = try JSONDecoder().decode(GlobalConfig.self, from: json)

        XCTAssertEqual(config.analytics?.enabled, false)
        XCTAssertEqual(config.analytics?.minVersion, "10.9.0")
    }
}
