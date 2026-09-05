import XCTest
@testable import novawallet
import NovaAnalytics

final class AnalyticsFacadeFactoryTests: XCTestCase {
    func testCreateDefaultReturnsTheSameInstance() {
        // Under `-UNITTEST` both sides resolve to `NoOpAnalyticsServiceFacade.shared`, so
        // what this pins is the no-op arm's own singleton — not `sharedFacade`, which a test
        // process never builds. That the real facade is a singleton too rests on Swift's
        // `static let` semantics, which no test can reach from here.
        XCTAssertTrue(AnalyticsFacadeFactory.createDefault() === AnalyticsFacadeFactory.createDefault())
    }

    func testUnitTestProcessNeverBuildsTheRealFacade() {
        // With F_ANALYTICS on for Debug, an unguarded factory would hand tests the real
        // singleton, which opens the developer's actual CoreData store, records a session
        // and POSTs to the live gateway on every `xcodebuild test`.
        XCTAssertTrue(AnalyticsFacadeFactory.createDefault() is NoOpAnalyticsServiceFacade)
    }
}
