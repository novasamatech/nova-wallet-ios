import XCTest
@testable import novawallet
import NovaAnalytics

final class AnalyticsFacadeFactoryTests: XCTestCase {
    func testCreateDefaultReturnsTheSameInstance() {
        XCTAssertTrue(AnalyticsFacadeFactory.createDefault() === AnalyticsFacadeFactory.createDefault())
    }

    func testUnitTestProcessNeverBuildsTheRealFacade() {
        XCTAssertTrue(AnalyticsFacadeFactory.createDefault() is NoOpAnalyticsServiceFacade)
    }
}
