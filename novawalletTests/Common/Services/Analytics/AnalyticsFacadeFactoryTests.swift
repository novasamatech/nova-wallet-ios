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

    func testUnitTestProcessNeverBuildsTheRealFacade() {
        // With F_ANALYTICS on for Debug, an unguarded factory would hand tests the real
        // singleton, which opens the developer's actual CoreData store, records a session
        // and POSTs to the live gateway on every `xcodebuild test`.
        XCTAssertTrue(AnalyticsFacadeFactory.createDefault() is NoOpAnalyticsServiceFacade)
    }

}
