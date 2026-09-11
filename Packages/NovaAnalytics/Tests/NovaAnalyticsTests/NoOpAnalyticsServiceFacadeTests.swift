import XCTest
@testable import NovaAnalytics

final class NoOpAnalyticsServiceFacadeTests: XCTestCase {
    func testNoOpFacadeDropsEverythingSilently() {
        let facade = NoOpAnalyticsServiceFacade.shared

        facade.setup()
        facade.track(.novaCardOpened())
        facade.flush(reason: .manual)
        facade.throttle()

        XCTAssertFalse(facade.consent.isEnabled)
        XCTAssertFalse(facade.consent.isAvailable)
    }
}
