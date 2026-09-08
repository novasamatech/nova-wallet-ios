import XCTest
@testable import NovaAnalytics

final class AnalyticsBucketsTests: XCTestCase {
    func testAmountBucketBoundariesAreExclusiveUpperBounds() {
        XCTAssertEqual(AmountBucket(usd: 0).rawValue, "under_1")
        XCTAssertEqual(AmountBucket(usd: 0.99).rawValue, "under_1")
        XCTAssertEqual(AmountBucket(usd: 1).rawValue, "1_to_10")
        XCTAssertEqual(AmountBucket(usd: 9.99).rawValue, "1_to_10")
        XCTAssertEqual(AmountBucket(usd: 10).rawValue, "10_to_100")
        XCTAssertEqual(AmountBucket(usd: 99.99).rawValue, "10_to_100")
        XCTAssertEqual(AmountBucket(usd: 100).rawValue, "100_to_1k")
        XCTAssertEqual(AmountBucket(usd: 1000).rawValue, "1k_to_10k")
        XCTAssertEqual(AmountBucket(usd: 10000).rawValue, "10k_to_100k")
        XCTAssertEqual(AmountBucket(usd: 100_000).rawValue, "over_100k")
        XCTAssertEqual(AmountBucket(usd: 999_999_999).rawValue, "over_100k")
    }

    func testDurationBucketsTruncateAndSlippageBucketBoundsAreInclusive() {
        XCTAssertEqual(DurationBucket(duration: 0).rawValue, "under_5s")
        XCTAssertEqual(DurationBucket(duration: 4.999).rawValue, "under_5s")
        XCTAssertEqual(DurationBucket(duration: 5).rawValue, "5s_to_15s")
        XCTAssertEqual(DurationBucket(duration: 14.999).rawValue, "5s_to_15s")
        XCTAssertEqual(DurationBucket(duration: 15).rawValue, "15s_to_30s")
        XCTAssertEqual(DurationBucket(duration: 30).rawValue, "30s_to_60s")
        XCTAssertEqual(DurationBucket(duration: 60).rawValue, "1m_to_5m")
        XCTAssertEqual(DurationBucket(duration: 299).rawValue, "1m_to_5m")
        XCTAssertEqual(DurationBucket(duration: 300).rawValue, "over_5m")

        XCTAssertEqual(SlippageBucket(percent: 0).rawValue, "low")
        XCTAssertEqual(SlippageBucket(percent: 0.5).rawValue, "low")
        XCTAssertEqual(SlippageBucket(percent: 0.51).rawValue, "medium")
        XCTAssertEqual(SlippageBucket(percent: 1).rawValue, "medium")
        XCTAssertEqual(SlippageBucket(percent: 1.01).rawValue, "high")
        XCTAssertEqual(SlippageBucket(percent: 3).rawValue, "high")
        XCTAssertEqual(SlippageBucket(percent: 3.01).rawValue, "custom")
    }

    func testNftCountBucketBoundariesAreExclusiveUpperBounds() {
        XCTAssertEqual(NftCountBucket(count: 0).rawValue, "0")
        XCTAssertEqual(NftCountBucket(count: 1).rawValue, "1_to_10")
        XCTAssertEqual(NftCountBucket(count: 9).rawValue, "1_to_10")
        XCTAssertEqual(NftCountBucket(count: 10).rawValue, "10_to_100")
        XCTAssertEqual(NftCountBucket(count: 99).rawValue, "10_to_100")
        XCTAssertEqual(NftCountBucket(count: 100).rawValue, "over_100")
        XCTAssertEqual(NftCountBucket(count: Int.max).rawValue, "over_100")
    }
}
