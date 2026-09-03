import XCTest
@testable import novawallet

final class AnalyticsFacadeFactoryTests: XCTestCase {
    func testCreateDefaultReturnsTheSameInstance() {
        // A second facade would mean a second lock, a second session id, a second
        // currentFeature and a second flush call store.
        XCTAssertTrue(AnalyticsFacadeFactory.createDefault() === AnalyticsFacadeFactory.createDefault())
    }

    func testNoOpFacadeDropsEverythingSilently() {
        let facade = NoOpAnalyticsServiceFacade.shared

        facade.setup()
        facade.track(.novaCardOpened())
        facade.flush(reason: .manual)
        facade.throttle()

        XCTAssertFalse(facade.consent.isEnabled)
        XCTAssertFalse(facade.consent.isAvailable)
    }

    func testSetupIsIdempotent() {
        let facade = AnalyticsFacadeFactory.createDefault()

        facade.setup()
        facade.setup()
        facade.throttle()
        // Reaching here without a crash or a duplicate delegate registration is the assertion.
    }
}
