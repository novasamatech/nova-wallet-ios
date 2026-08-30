import XCTest
@testable import novawallet
import Operation_iOS

final class AssetExchangeTradeLimitedEdgeTests: XCTestCase {
    func testErasureForwardsTheVerdictForATradeLimitedEdge() {
        let edge = AnyAssetExchangeEdge(
            StubTradeLimitedExchangeEdge(
                origin: CommissionTestFixtures.asset(0),
                destination: CommissionTestFixtures.asset(1),
                type: .hydraSwap,
                chain: CommissionTestFixtures.chain
            )
        )

        XCTAssertNotNil(edge.tradeLimitVerdict(amount: 1, direction: .sell))
    }

    func testErasureReportsNoVerdictForAnUnlimitedEdge() {
        let edge = AnyAssetExchangeEdge(
            StubAssetExchangeEdge(
                origin: CommissionTestFixtures.asset(0),
                destination: CommissionTestFixtures.asset(1),
                type: .hydraSwap,
                chain: CommissionTestFixtures.chain
            )
        )

        XCTAssertNil(edge.tradeLimitVerdict(amount: 1, direction: .sell))
    }
}
