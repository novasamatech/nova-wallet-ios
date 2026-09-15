import XCTest
@testable import novawallet

final class AnalyticsAppWiringTests: XCTestCase {
    func testAnalyticsQueueIsSerial() {
        XCTAssertEqual(OperationManagerFacade.analyticsQueue.maxConcurrentOperationCount, 1)
    }

    func testGlobalConfigDecodesTheInfraUrl() throws {
        let json = Data(#"{"multiStakingApiUrl":"https://a.example","multisigsApiUrl":"https://b.example","proxyApiUrl":"https://c.example","infraUrl":"https://infra.example/"}"#.utf8)

        let config = try JSONDecoder().decode(GlobalConfig.self, from: json)

        XCTAssertEqual(config.infraUrl.absoluteString, "https://infra.example/")
    }
}
