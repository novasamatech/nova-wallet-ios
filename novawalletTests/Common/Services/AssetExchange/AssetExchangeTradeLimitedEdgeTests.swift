import XCTest
@testable import novawallet
import Operation_iOS

final class AssetExchangeTradeLimitedEdgeTests: XCTestCase {
    func testErasureForwardsTheVerdictForATradeLimitedEdge() {
        let edge = AnyAssetExchangeEdge(makeTradeLimitedEdge())

        XCTAssertNotNil(edge.tradeLimitVerdict(amount: 1, direction: .sell))
    }

    func testErasureReportsNoVerdictForAnUnlimitedEdge() {
        let edge = AnyAssetExchangeEdge(makeUnlimitedEdge())

        XCTAssertNil(edge.tradeLimitVerdict(amount: 1, direction: .sell))
    }

    func testErasureForwardsTheEdgesOwnVerdict() throws {
        let edge = AnyAssetExchangeEdge(makeTradeLimitedEdge(verdict: Self.breachingVerdict))

        let wrapper = try XCTUnwrap(edge.tradeLimitVerdict(amount: 1, direction: .sell))

        XCTAssertEqual(try fetchVerdict(from: wrapper), Self.breachingVerdict)
    }

    func testDoubleErasureForwardsTheVerdictForATradeLimitedEdge() {
        let edge = AnyAssetExchangeEdge(AnyAssetExchangeEdge(makeTradeLimitedEdge()))

        XCTAssertNotNil(edge.tradeLimitVerdict(amount: 1, direction: .sell))
    }

    func testDoubleErasureForwardsTheEdgesOwnVerdict() throws {
        let edge = AnyAssetExchangeEdge(
            AnyAssetExchangeEdge(makeTradeLimitedEdge(verdict: Self.breachingVerdict))
        )

        let wrapper = try XCTUnwrap(edge.tradeLimitVerdict(amount: 1, direction: .sell))

        XCTAssertEqual(try fetchVerdict(from: wrapper), Self.breachingVerdict)
    }

    func testDoubleErasureReportsNoVerdictForAnUnlimitedEdge() {
        let edge = AnyAssetExchangeEdge(AnyAssetExchangeEdge(makeUnlimitedEdge()))

        XCTAssertNil(edge.tradeLimitVerdict(amount: 1, direction: .sell))
    }
}

private extension AssetExchangeTradeLimitedEdgeTests {
    static let breachingVerdict = AssetExchangeTradeLimitVerdict.exceeds(
        .init(maxGivenAmount: 4_242_000_000, minTradingLimit: 1_000)
    )

    func makeTradeLimitedEdge(
        verdict: AssetExchangeTradeLimitVerdict = .withinLimit
    ) -> StubTradeLimitedExchangeEdge {
        StubTradeLimitedExchangeEdge(
            origin: CommissionTestFixtures.asset(0),
            destination: CommissionTestFixtures.asset(1),
            type: .hydraSwap,
            chain: CommissionTestFixtures.chain,
            verdict: verdict
        )
    }

    func makeUnlimitedEdge() -> StubAssetExchangeEdge {
        StubAssetExchangeEdge(
            origin: CommissionTestFixtures.asset(0),
            destination: CommissionTestFixtures.asset(1),
            type: .hydraSwap,
            chain: CommissionTestFixtures.chain
        )
    }

    func fetchVerdict(
        from wrapper: CompoundOperationWrapper<AssetExchangeTradeLimitVerdict>
    ) throws -> AssetExchangeTradeLimitVerdict {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
