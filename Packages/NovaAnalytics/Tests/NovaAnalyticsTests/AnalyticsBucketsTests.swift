import XCTest
@testable import NovaAnalytics

final class AnalyticsBucketsTests: XCTestCase {
    func testAmountBoundaries() {
        XCTAssertEqual(AmountBucket(usd: 0.99), .under1)
        XCTAssertEqual(AmountBucket(usd: 1), .from1To10)
        XCTAssertEqual(AmountBucket(usd: 100_000), .over100k)
    }

    func testDurationBoundaries() {
        XCTAssertEqual(DurationBucket(duration: 4.999), .under5s)
        XCTAssertEqual(DurationBucket(duration: 5), .from5sTo15s)
        XCTAssertEqual(DurationBucket(duration: 300), .over5m)
    }

    func testSlippageBoundaries() {
        XCTAssertEqual(SlippageBucket(percent: 0.5), .low)
        XCTAssertEqual(SlippageBucket(percent: 0.51), .medium)
        XCTAssertEqual(SlippageBucket(percent: 3.01), .custom)
    }

    func testNftCountBoundaries() {
        XCTAssertEqual(NftCountBucket(count: 0).rawValue, "0")
        XCTAssertEqual(NftCountBucket(count: 1).rawValue, "1_to_10")
        XCTAssertEqual(NftCountBucket(count: 10).rawValue, "10_to_100")
        XCTAssertEqual(NftCountBucket(count: 100).rawValue, "over_100")
    }
}
