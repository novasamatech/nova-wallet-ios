import XCTest
@testable import novawallet
import Operation_iOS

final class AnyAssetExchangeEdgeTradeLimitTests: XCTestCase {
    func testErasureForwardsTheEdgesOwnVerdict() throws {
        let edge = AnyAssetExchangeEdge(makeEdge(verdict: Self.breachingVerdict))

        let verdict = try fetchVerdict(from: edge.tradeLimitVerdict(amount: 1, direction: .sell))

        XCTAssertEqual(verdict, Self.breachingVerdict)
    }

    func testDoubleErasureForwardsTheEdgesOwnVerdict() throws {
        let edge = AnyAssetExchangeEdge(AnyAssetExchangeEdge(makeEdge(verdict: Self.breachingVerdict)))

        let verdict = try fetchVerdict(from: edge.tradeLimitVerdict(amount: 1, direction: .sell))

        XCTAssertEqual(verdict, Self.breachingVerdict)
    }
}

private extension AnyAssetExchangeEdgeTradeLimitTests {
    static let breachingVerdict = AssetExchangeTradeLimitVerdict.exceeds(
        .init(maxGivenAmount: 4_242_000_000, minTradingLimit: 1_000)
    )

    func makeEdge(verdict: AssetExchangeTradeLimitVerdict) -> StubAssetExchangeEdge {
        StubAssetExchangeEdge(
            origin: CommissionTestFixtures.asset(0),
            destination: CommissionTestFixtures.asset(1),
            type: .hydraSwap,
            chain: CommissionTestFixtures.chain,
            verdict: verdict
        )
    }

    func fetchVerdict(
        from wrapper: CompoundOperationWrapper<AssetExchangeTradeLimitVerdict>
    ) throws -> AssetExchangeTradeLimitVerdict {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
